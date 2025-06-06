require "rubygems"
require "bundler"
require "timeout"

Bundler.setup :test

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))

require "typesense-rails"
require "rspec"
require "rails/all"

Thread.current[:typesense_hosts] = nil

GlobalID.app = "typesense-rails"

RSpec.configure do |c|
  c.mock_with :rspec
  c.filter_run :focus => true
  c.run_all_when_everything_filtered = true
  c.formatter = "documentation"

  c.around(:each) do |example|
    Timeout::timeout(120) {
      example.run
    }
  end

  # Remove all indexes setup in this run in local or CI
  c.after(:suite) do
    safe_index_list.each do |i|
      begin
        Typesense.client.collections(i.name).delete()
      rescue
        # fail gracefully
      end
    end
  end
end

# A unique prefix for your test run in local or CI
SAFE_INDEX_PREFIX = "rails_#{SecureRandom.hex(8)}".freeze

# avoid concurrent access to the same index in local or CI
def safe_index_name(name)
  "#{SAFE_INDEX_PREFIX}_#{name}"
end

# get a list of safe indexes in local or CI
def safe_index_list
  list = Typesense.client.collections.retrieve()
  list = list.select { |index| index["name"].include?(SAFE_INDEX_PREFIX) }
end
