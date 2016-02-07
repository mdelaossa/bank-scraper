require 'ostruct'

require_relative '../lib/bank'

class BacNicaragua < Bank

  ACCOUNT_TYPES = {
      banking: /^CUENTAS BANCARIAS/,
      credit: /^CUENTAS DE CRÉDITO/,
      loan: /^PRÉSTAMOS/
  }

  def initialize(data)
    super

    raise MissingSignInDataError, "A username and password are required" unless @data.login.username && @data.login.password

    sign_in
  end

  def sign_in
    logger.debug 'signing in'
    @scraper.goto "https://www1.sucursalelectronica.com/redir/showLogin.go?country=NI"

    @scraper.text_field(name: 'product').set @data.login.username
    @scraper.text_field(name: 'pass').set @data.login.password
    @scraper.button(name: 'confirm').click

    raise SignInError, "Wrong Username or Password" if @scraper.text_field(name: 'pass').exists?
    raise SignInError, "Throttled, too many sessions" if @scraper.url == "https://www1.sucursalelectronica.com/ebac/common/showSessionRestriction.go"
    logger.debug "signed in"
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

            accounts[account_type] << acc
          end
        end
        accounts
      end
  end

end
