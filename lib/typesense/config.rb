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
      @@log_level = configuration[:log_level] if configuration.key?(:log_level)
      @@configuration = configuration
      
      Rails.logger.level = log_level_to_const(configuration[:log_level])
    end

    def pagination_backend
      @@pagination_backend
    end

    def log_level
      @@log_level
    end

    def log_level_to_const(level)
      case level
      when :debug
        Logger::DEBUG
      when :info
        Logger::INFO
      when :warn
        Logger::WARN
      when :error
        Logger::ERROR
      when :fatal
        Logger::FATAL
      when :unknown
        Logger::UNKNOWN
      else
        Logger::WARN # default fallback
      end
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
