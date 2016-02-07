require 'optparse'
require 'json'

# Defaults
options = {
    login: {}
}

OptionParser.new do |opts|
  opts.banner = 'Usage: ruby bank_scraper.rb [options] bank'

  opts.on '-l', '--login_data', '=DATA', 'Your bank\'s required login data in JSON format' do |l|
    options[:login] = JSON.parse l
  end

  opts.separator ""

  opts.on_tail '-h', '--help', 'Show this message' do
    puts opts
    exit
  end
end.parse!

bank = ARGV[0]
require_relative "./banks/#{bank}.rb"

# Get our bank class object
bank = Object.const_get(bank.split('_').collect(&:capitalize).join).new(options)

bank.accounts.each do |account|
  puts account.number
end

# Finally, sign out of the bank if supported to avoid tying up sessions on banks that limit them
bank.sign_out if bank.respond_to? :sign_out
