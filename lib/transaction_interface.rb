require_relative 'abstract_interface'
require_relative 'logger'

class BankInterface
  class AccountInterface
    class TransactionInterface
      include Logging

      attr_accessor :value, :currency, :description
    end
  end
end
