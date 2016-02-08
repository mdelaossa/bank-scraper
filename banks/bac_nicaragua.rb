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

        raise NotSignedInError unless signed_in?

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
    @scraper.text_field(name: 'pass').exists?
  end

  def signed_in?
    !signed_out?
  end

  class Account < AccountInterface
    # BacNicaragua needs TWO URLs, one to set the selected account in the session, the other for grabbing the data we want
    URL1 = 'https://www1.sucursalelectronica.com/ebac/module/accountstate/accountState.go'
    URL2 = 'https://www1.sucursalelectronica.com/ebac/module/bankaccountstate/bankAccountState.go'

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

    def transactions_since(start_date = Account.last_month)
      transactions_between(start_date, Date.today)
    end

    def transactions_between(start_date, end_date)
      params = DEFAULT_PARAMS.merge({initDate: start_date.strftime("%d/%m/%Y"), endDate: end_date.strftime('%d/%m/%Y')})

      callback = 'function (form) { singleSubmit(form); }'

      @scraper.post(URL1, {productId: id}, callback)
      sleep 1 # Let's give it some time to catch up...
      @scraper.post(URL2, params, callback)
      sleep 1 # Let's give it some time to catch up...

      transactions_table = @scraper.tables(id: 'resultsTableOnTop')[1]

      transactions = []

      transactions_table.trs.each do |transaction_row|
        data = transaction_row.spans(class: 'tableData').map &:text
        next if data.size != 7

        data[4] = data[4].gsub(',', '').to_f
        data[5] = data[5].gsub(',', '').to_f

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
