require 'typesense'

module AlgoliaSearch
  module Configuration
    def initiliaze
      @client = nil
    end

    def configuration
      @@configuration || raise(NotConfigured,
                               "Please configure AlgoliaSearch. Set AlgoliaSearch.configuration = {application_id: 'YOUR_APPLICATION_ID', api_key: 'YOUR_API_KEY'}")
    end

    def configuration=(configuration)
      @pagination_backend = configuration.delete(:pagination_backend) if configuration.key?(:pagination_backend)
      @@configuration = configuration
    end

    def pagination_backend
      @pagination_backend
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
