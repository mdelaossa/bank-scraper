require 'watir-webdriver'

require_relative 'abstract_interface'
require_relative 'account_interface'
require_relative 'hash_to_openstruct'

class BankInterface
  include AbstractInterface
  include Logging

  def initialize(data)
    raise MissingSignInDataError if data[:login].empty?

    @data = data.to_ostruct
    @scraper = Watir::Browser.new :phantomjs
  end

  ##
  # Gets all accounts we have access to
  # @return [Hash] A hash of all accounts in {type: [Account, Account, ...]} format
  def accounts
    Bank.api_not_implemented(self)
  end

  class MissingSignInDataError < RuntimeError
    def initialize(msg = 'Please provide the bank\'s login details')
      super
    end
  end

  class SignInError < RuntimeError
    def initialize(msg = 'Error signing in')
      super
    end
  end

end
