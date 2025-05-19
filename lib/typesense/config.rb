module Typesense
  module Config
    def initiliaze
      @client = nil
    end

    def configuration
      @@configuration || raise(NotConfigured,
                               "Please configure Typesense. Set Typesense.configuration = {nodes: [{host: 'localhost', port: 8108, protocol: 'http'}], api_key: 'xyz'}")
    end

    def configuration=(configuration)
      @@pagination_backend = configuration[:pagination_backend] if configuration.key?(:pagination_backend)
      @@configuration = configuration
    end

    def pagination_backend
      @@pagination_backend
    end

    def client
      setup_client if @client.nil?
      @client
    end

    def setup_client
      @client = Typesense::Client.new(@@configuration)
    end
  end
end
