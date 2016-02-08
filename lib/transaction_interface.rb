require_relative 'abstract_interface'
require_relative 'logger'

class BankInterface
  class AccountInterface
    class TransactionInterface
      include Logging

      attr_accessor :date, :amount, :payee, :number, :category
    end
  end
end
