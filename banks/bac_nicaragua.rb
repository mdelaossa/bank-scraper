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

        accounts = {}
        types = @scraper.tables(id: 'resultsTableOnTop')
        types.each do |type|
          account_type = ACCOUNT_TYPES.select {|k,v| v =~ type.trs.first.text}.keys.first # We just want the key...
          accounts[account_type] = []
          logger.debug "Found account type: #{account_type}"

          type.trs.each do |account|
            next if account.spans.size == 0 # Skip rows without account data
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

    def transactions_after(start_date = Account.last_month)
      params = DEFAULT_PARAMS.merge({initDate: start_date.strftime("%d/%m/%Y")})

      callback = 'function (form) { singleSubmit(form); }'

      @scraper.post(URL1, {productId: id}, callback)
      sleep 1 # Let's give it some time to catch up...
      @scraper.post(URL2, params, callback)


    end

  end

end
