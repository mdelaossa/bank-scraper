require_relative 'abstract_interface'
require_relative 'logger'

class Bank
  class Account
    class Transaction
      include Logging

      attr_accessor :value, :currency, :description
    end
  end
end
