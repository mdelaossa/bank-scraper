require 'ostruct'

require_relative '../lib/bank'

class BacNicaragua < Bank

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
  end

end
