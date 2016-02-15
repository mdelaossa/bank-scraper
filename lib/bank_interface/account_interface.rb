require_relative 'transaction_interface'

class BankInterface
  class AccountInterface
    include AbstractInterface
    include Logging

    attr_accessor :bank, :id, :number, :currency, :name, :balance, :type

    ##
    # @param [Hash, nil] options. Options that MUST be accepted are start_date, end_date.
    # @return [Array<Transaction>] All Transactions that match options in chronological order. Recommended to return
    # the last month in case of empty options
    def transactions(options = nil)
      Account.api_not_implemented(self)
    end

    protected
    def self.one_month_ago
      d = Date.today
      d - (d - d.day).day
    end

    def self.last_month
      d = Date.today
      d - d.day
    end

  end
end
