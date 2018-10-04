$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'dalek'

require 'active_record'
require 'database_cleaner'

require 'pry'

DatabaseCleaner.strategy = :transaction

RSpec.configure do |config|
  config.before :suite do
    ActiveRecord::Base.establish_connection(
      adapter: 'postgresql',
      database: 'dalek_test',
      username: 'root',
      host: 'localhost',
    )
    # ActiveRecord::Base.logger = Logger.new(STDOUT)
  end

  config.before :each do
    DatabaseCleaner.start
  end

  config.after :each do
    DatabaseCleaner.clean
  end

  config.warnings = true

  if config.files_to_run.one?
    config.default_formatter = 'doc'
  end

  config.order = :random
end
