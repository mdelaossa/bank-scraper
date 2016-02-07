require_relative 'abstract_interface'
require_relative 'transaction_interface'

class BankInterface
  class AccountInterface
    include AbstractInterface
    include Logging

    attr_accessor :id, :number, :currency, :name, :balance
    attr_writer :scraper

    ##
    # @param [DateTime] start_date Initial transcation date, inclusive
    # @param [DateTime] end_date Final transaction date, inclusive
    # @return [Array<Transaction>] All Transactions between start_time and end_time in chronological order
    def transactions_between(start_date, end_date)
      Account.api_not_implemented(self)
    end

    ##
    # @param [DateTime] start_date Initial transcation date, inclusive
    # @return [Array<Transaction>] All Transactions after start_time in chronological order
    def transactions_after(start_date = last_month)
      Account.api_not_implemented(self)
    end

    ##
    # @param [String] reference
    # @return [Array<Transaction>] All Transactions after reference in chronological order
    def transactions_after_ref(reference)
      Account.api_not_implemented(self)
    end

    protected
    def one_month_ago
      d = Date.today
      d - (d - d.day).day
    end

    def last_month
      d = Date.today
      d - d.day
    end

  end
end
