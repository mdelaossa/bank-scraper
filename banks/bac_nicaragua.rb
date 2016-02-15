require 'net/https'
require 'uri'
require 'open-uri'
require 'json'
require 'base64'
require 'openssl'
require 'savon'

require_relative '../lib/bank_interface'



### Net::ReadTimeout is a BIG possibility

class BacNicaragua < BankInterface

  ACCOUNT_TYPES = {
      banking: 'CBK',
      credit: 'TAR',
      loan: 'LNS'
  }

  def initialize(data)
    super

    raise MissingSignInDataError, "A username and password are required" unless @data.login.username && @data.login.password

  end

  def sign_in
    logger.debug 'signing in'

    uri = URI.parse "https://www.e-bac.net/sbefx/resources/jsonbac"
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri.request_uri)

    data = prepare_payload("CANALESMOVILES_Usuario_Login", false)

    # All '%2B's except the last if encrypted_password has a +
    pattern = encrypted_password.include?('+') ? /%2B(?=.*%2B)/ : '%2B'
    request.body = URI.encode_www_form(message: data).gsub(pattern, '+') # More dumb API requirements...
    request.content_type = 'application/json'

    response = http.request(request)

    logger.debug response

    if response.code == '200'
      response = JSON.parse(response.body).to_ostruct
      if response.message.header.errors
        raise SignInError, response.message.header.errors.error.description
      end
    else
      raise SignInError, "Unknown response: #{response.inspect}"
    end

    @token = response.message.header.origin.token
    @country = response.message.body.authenticationView.country

    raise SignInError, "Wrong Username or Password" if signed_out? || response.message.body.authenticationView.valid != '0'
    logger.debug "signed in"

    @accounts = nil # Product IDs change on every session so let's make sure we don't cache in between sessions
  end

  def accounts
    @accounts ||=
      begin

        raise NotSignedInError unless signed_in?

        uri = URI.parse "https://www.e-bac.net/sbefx/resources/jsonbac"
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true

        request = Net::HTTP::Post.new(uri.request_uri)

        data = prepare_payload("CANALESMOVILES_Usuario_Carga_Datos_Consolidado")
        logger.debug "Getting accounts"

        logger.debug data

        request.body = URI.encode_www_form(message: data).gsub('%2B', '+') # More dumb API requirements...
        request.content_type = 'application/json'

        response = http.request(request)

        logger.debug response

        raise "Error getting Accounts: Request returned code #{response.code}" if response.code != '200'

        response = JSON.parse(response.body).to_ostruct

        if response.message.header.errors
          raise BankingError, "Error getting accounts: BAC error #{response.message.header.errors.error.description}"
        end

        @token = response.message.header.origin.token

        accounts = []

        response.message.body.userInfoView.userProductsView.internetAccounts.each do |internetAccount|
          internetAccount['customers'].each do |customer|
            customer['productViews'].each do |product|
              logger.debug "Processing account data: #{product}"

              product = product.to_ostruct

              properties = {
                  id: product.identifier,
                  currency: product.productCurrency == 'COR' ? 'NIO' : product.productCurrency,
                  name: product.shortName.empty? ? product.prdtTypeDescription : product.shortName,
                  number: product.product,
                  country: response.message.body.userInfoView.country,
                  balance: product.available,
                  type: ACCOUNT_TYPES.key(product.productType),
                  bank: self
              }
              logger.debug "Adding new account: #{properties}"

              accounts << Account.new(@data, properties)
            end
          end
        end

        accounts
      end
  end

  def sign_out
    raise "NOT IMPLEMENTED" #TODO: IMPLEMENT
    # raise "Error signing out" if signed_in?
  end

  private
  def public_ip
    @public_ip ||= open('http://whatismyip.akamai.com').read
  end

  def encrypted_password
    c = OpenSSL::Cipher::Cipher.new 'des-ede3'
    c.encrypt
    c.key = "tmzr1oaua9cdfg+25-xpmn==" # Extracted from Android APK

    Base64.strict_encode64(c.update(@data.login.password) + c.final)
  end

  ##
  # This is a CRAZY method because of some really, really dumb 'requirements' by BAC's API (which I'm sure evolved
  # from dumb events). Some keys need a + in certain places to be accepted server-side
  def prepare_payload(operation_code, use_token = true)
  key = {
      identifier: @data.login.username,
      country: @country || "CR",
  }

  if use_token
    key[:company] = ""
  else
    key[:token] = ""
    key[:password] = encrypted_password
  end

  key = key.to_json

  target = {country: "CR"}.to_json.gsub('{','{+').gsub('}', '+}').gsub(':',':+')

  { message: {
      header: {
          operationCode: operation_code,
          origin: {
              country: @country || "CR",
              channel: "SECAN",
              token: use_token ? @token : "",
              user: @data.login.username,
              server: public_ip
          },
          target: '%TARGET%'
      },
      key: '%KEY%'
  } }.to_json.gsub(':', ':+').gsub('"%TARGET%"', target).gsub('"%KEY%"', key)

  end

  def signed_out?
    !signed_in?
  end

  def signed_in?
    @token && !@token.empty?
  end

  class Account < AccountInterface

    attr_accessor :country

    attr_writer :data

    OPERATION_CODE = {
        banking: 'CANALESMOVILES_Cuenta_Consulta_Estado_Cuenta',
        credit: 'CANALESMOVILES_Consulta_Estado_Cuenta_Tarjeta_Credito',
        loan: '' # is there one? haven't found it
    }

    DEFAULT_HEADER = {
        origin: {
            country: 'CR',
            channel: 'SECAN',
            server: '31.183.60.185'
        },
        target: { country: 'CR'}
    }

    DEFAULT_MESSAGE = {
        banking: {
          initialDate: last_month.strftime('%d/%m/%Y'),
          finalDate: Date.today.strftime('%d/%m/%Y'),
          referenceFrom: nil,
          referenceTo: nil,
          amountFrom: nil,
          amountTo: nil
        },
        credit: {
            statementSelected: nil,
            productEntity: nil
        },
        loan: {}
    }

    def initialize(data = nil, properties = {})
      options = {
          wsdl: 'https://www.e-bac.net/sbefx/services/WebServicePublisherMessageSessionService/wsdl/WebServicePublisherMessageSessionService.wsdl',
          env_namespace: :soap,
          namespace_identifier: :frm
      }
      @client = ::Savon.client(options)
      @data = data

      properties.each do |name, value|
        self.send("#{name}=", value)
      end

      set_defaults if @data
    end

    def transactions(options)
      start_date = options[:start_date] || Account.last_month
      end_date = options[:end_date] || Date.today

      logger.debug "Getting transactions between #{start_date} and #{end_date}"

      transactions = []

      message = case @type
                  when :banking
                    DEFAULT_MESSAGE.deep_merge({initialDate: start_date, finalDate: end_date})
                  when :credit, :loan
                    DEFAULT_MESSAGE
      end

      response = @client.call(:soap_domain_msg, message: {header: @header, key: message})

      doc = response.body.to_ostruct

      logger.debug "Got transactions from #{doc.key.initialDate} to #{doc.key.finalDate}"

      doc.body.creditCardAccountStateView.movementsViews.each do |movement|
        ## If `local` and `reference` are both 0, skip
        #<movementsView>
        #<local>102.650000000000005684341886080801486968994140625</local> #<- NIO
				#			<notes>LA UNION ESQUIPULAS                   NI</notes>
        #<number>ENE/06</number>
				#			<reference>0</reference> #<- DOLLARS
        #<time>ENE/06</time>
				#		</movementsView>
      end
      doc.body.bankAccountStateView.bankAccountStateMovementViews.each do |movement|
        ##
        #<BankAccountStateMovementView>
        #<amount>17.93</amount>
				#			<balance>10262.56</balance>
        #<code>AT</code>
				#			<date>20160123</date>
        #<dateLast>20160123</dateLast>
				#			<details>RETIRO ATM 215507</details>
        #<isDebit>1</isDebit>
				#			<reference>75908905</reference>
        #<stmacc>356513184</stmacc>
				#			<stmccy>USD</stmccy>
        #</BankAccountStateMovementView>
      end

      raise "Not done yet"
    end

    private
    def set_defaults
      raise Bankingerror, "Account: Missing login data" unless @data.login
      @header = DEFAULT_HEADER.deep_merge({
                                              operationCode: OPERATION_CODE[@type],
                                              origin: {user: @data.login.username}
                                          })

      message = case @type
                  when :banking
                    {
                        accountNumber: @number,
                        country: @country
                    }
                  when :credit
                    {
                        productId: @number,
                        productCountry: @country
                    }
                end

      @message = DEFAULT_MESSAGE[@type].deep_merge(message)
    end

    class Transaction < TransactionInterface

    end
  end

end
