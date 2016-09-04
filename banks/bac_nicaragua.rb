require 'ostruct'

require_relative '../lib/bank_interface'

class BacNicaragua < BankInterface

  ACCOUNT_TYPES = {
      banking: /^CUENTAS BANCARIAS/,
      credit: /^CUENTAS DE CRÉDITO/,
      loan: /^PRÉSTAMOS/
  }

  def initialize(data)
    super

    raise MissingSignInDataError, "A username and password are required" unless @data.login.username && @data.login.password

  end

  def sign_in
    logger.debug 'signing in'
    @scraper.goto "https://www1.sucursalelectronica.com/redir/showLogin.go?country=NI"

    @scraper.text_field(name: 'product').set @data.login.username
    @scraper.text_field(name: 'pass').set @data.login.password
    @scraper.button(name: 'confirm').click

    raise SignInError, "Wrong Username or Password" if signed_out?
    raise SignInError, "Throttled, too many sessions" if @scraper.url == "https://www1.sucursalelectronica.com/ebac/common/showSessionRestriction.go"
    logger.debug "signed in"

    @accounts = nil # Product IDs change on every session so let's make sure we don't cache in between sessions
  end

  def accounts
    @accounts ||=
      begin

        raise SignInError, "Not signed in" unless signed_in?

        @scraper.goto "https://www1.sucursalelectronica.com/ebac/module/consolidatedQuery/consolidatedQuery.go#modal1"

        accounts = {}
        types = @scraper.tables(id: 'resultsTableOnTop')
        types.each do |type|
          account_type = ACCOUNT_TYPES.select {|k,v| v =~ type.trs.first.text}.keys.first # We just want the key...
          accounts[account_type] = []
          logger.debug "Found account type: #{account_type}"

          type.trs.each do |account|
            next unless account.spans.size == 5 # Skip rows without account data
            next if account.spans.first.class_name == 'tableTitle' # Skip title rows

            data = account.spans

            logger.debug "Adding new account: #{data.map &:text}"

            acc = Account.new
            acc.currency = data[4].text == 'COR' ? 'NIO' : data[4].text
            acc.number = data[2].text
            acc.name = data[1].text
            acc.balance = data[3].text.gsub(',', '').to_f
            acc.id = account.forms[1].input(name: 'productId').value
            acc.scraper = @scraper

            accounts[account_type] << acc
          end
        end
        accounts
      end
  end

  def sign_out
    @scraper.a(href: /logout.go$/).click
    raise "Error signing out" if signed_in?
  end

  private
  def signed_out?
    !signed_in?
  end

  def signed_in?
    @scraper.a(href: /logout.go$/).exists?
  end

  class Account < AccountInterface
    # BacNicaragua needs TWO URLs, one to set the selected account in the session, the other for grabbing the data we want
    URL = 'https://www1.sucursalelectronica.com/ebac/module/accountbalance/accountBalance.go'

    DEFAULT_PARAMS = {
        serverDate:	Date.today.strftime("%d/%m/%Y"),
        lastMonthDate: last_month.strftime("%d/%m/%Y"),
        initDate: one_month_ago.strftime("%d/%m/%Y"),
        endDate: Date.today.strftime("%d/%m/%Y")
#    initAmount
#    limitAmount
#    initReference
#    endReference
    }

# TODO: This stuff only works for :banking, need to add a switch for :credit and :loan types

    def transactions_since(start_date = Account.last_month)
      transactions_between(start_date, Date.today)
    end

    def transactions_between(start_date, end_date)
      params = DEFAULT_PARAMS.merge({initDate: start_date.strftime("%d/%m/%Y"), endDate: end_date.strftime('%d/%m/%Y')})

      logger.debug "Getting transactions between #{start_date} and #{end_date}"

      callback = 'function (form) { singleSubmit(form); }'

      @scraper.post(URL, {productId: id}, callback)
      @scraper.input(name: 'initDate').wait_until_present
      @scraper.wait_until { @scraper.input(name: 'initDate').value == (Date.today - Date.today.day + 1).strftime("%d/%m/%Y") }
      @scraper.post(URL, params, callback)
      @scraper.wait_until { @scraper.input(name: 'initDate').value == start_date.strftime("%d/%m/%Y") }

      logger.debug "Actual dates from #{@scraper.input(name: 'initDate').value} to #{@scraper.input(name: 'endDate').value}"

      transactions_table = @scraper.tables(id: 'transactions')[0]

      transactions = []

      transactions_table.tbody.trs.each do |transaction_row|
        data = transaction_row.tds.map &:text
        next if data.size != 7

        data[4] = data[4].gsub(',', '').to_f
        data[5] = data[5].gsub(',', '').to_f

        logger.debug "Adding new transaction: #{data}"

        transaction = Transaction.new
        transaction.amount = data[4] == 0 ? data[5] : - data[4]
        transaction.payee = data[3]
        transaction.category = data[2]
        transaction.number = data[1]
        transaction.date = Date.strptime(data[0], '%d/%m/%Y')

        transactions << transaction
      end

      transactions
    end

    class Transaction < TransactionInterface

    end
  end

end
