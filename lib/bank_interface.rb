require_relative 'bank_interface/account_interface'
require_relative 'bank_interface/exceptions.rb'
require_relative 'hash_to_openstruct'
require_relative 'deep_merge'

class BankInterface
  include AbstractInterface
  include Logging

  def initialize(data)
    raise MissingSignInDataError if data[:login].empty?

    @data = data.to_ostruct
  end

  ##
  # Gets all accounts we have access to
  # @return [Hash] A hash of all accounts in {type: [Account, Account, ...]} format
  def accounts
    Bank.api_not_implemented(self)
  end
end
