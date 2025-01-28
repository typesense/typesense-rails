require "typesense"

module Typesense
  module Configuration
    def initialize
      @client = nil
    end

    def configuration
      @@configuration || raise(NotConfigured, "Please configure Typesense. Set Typesense.configuration = {api_key: 'YOUR_API_KEY', nodes: [{protocol: 'PROTOCOL', host: 'HOST', port: 'PORT'}]}")
    end

    def configuration=(configuration)
      @@configuration = default_configuration
                          .merge(configuration)
    end

    def client
      if @client.nil?
        setup_client
      end

      @client
    end

    def setup_client
      @client = Typesense::Client.new()
    end

    def default_configuration
      {
        queue_name: 'typesense'
      }
    end
  end
end
