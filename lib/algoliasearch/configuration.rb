require "typesense"

module AlgoliaSearch
  module Configuration
    def initiliaze
      @client = nil
    end

    def configuration
      @@configuration || raise(NotConfigured, "Please configure AlgoliaSearch. Set AlgoliaSearch.configuration = {application_id: 'YOUR_APPLICATION_ID', api_key: 'YOUR_API_KEY'}")
    end

    def configuration=(configuration)
      if configuration.key?(:pagination_backend)
        @pagination_backend = configuration.delete(:pagination_backend)
      end
      @@configuration = configuration
    end

    def pagination_backend
      @pagination_backend
    end

    def client
      if @client.nil?
        setup_client
      end

      @client
    end

    def setup_client
      #@client = Algolia::Search::Client.create_with_config(Algolia::Search::Config.new(@@configuration))
      @client = Typesense::Client.new(@@configuration)
    end
  end
end
