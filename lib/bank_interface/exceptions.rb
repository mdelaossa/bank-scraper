class BankInterface

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

  class NotSignedInerror < RuntimeError
    def initialize(msg = 'Not signed in!')
      super
    end
  end

  class BankingError < RuntimeError
    def initialize(msg = 'An error occurred')
      super
    end
  end

end
