require_relative 'abstract_interface'
require_relative 'transaction'

class Bank
  class Account
    include AbstractInterface
    include Logging

    attr_accessor :id, :number, :currency

    ##
    # @param [DateTime] start_date Initial transcation date, inclusive
    # @param [DateTime] end_date Final transaction date, inclusive
    # @return [Array<Transaction>] All Transactions between start_time and end_time in chronological order
    def transactions_between(start_date, end_date)
      Account.api_not_implemented(self)
    end
  end
end
