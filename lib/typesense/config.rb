module Typesense
  module Config
    @@pagination_backend = nil unless defined?(@@pagination_backend)
    @@log_level = nil unless defined?(@@log_level)
    @@configuration = nil unless defined?(@@configuration)
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
    end

    def pagination_backend
      @@pagination_backend
    end

    def log_level
      defined?(@@log_level) ? @@log_level : nil
    end

    def log_level_to_const(level)
      # Be more forgiving in inputs.
      # Accepts Integer (e.g., Logger::WARN), Symbol/String (e.g., :warn, "warn", "WARN", "Logger::WARN")
      return level if level.is_a?(Integer)
      return Logger::WARN if level.nil?

      str = level.to_s

      # Handle fully-qualified constants like "Logger::WARN"
      if str.include?("::")
        const = str.split("::").last
        return Logger.const_get(const) if Logger.const_defined?(const)
      end

      # Normalize common misnomer
      upper = str.upcase
      upper = "WARN" if upper == "WARNING"
      return Logger.const_get(upper) if Logger.const_defined?(upper)

      # Fallback to explicit mapping
      case str.downcase.to_sym
      when :debug then Logger::DEBUG
      when :info then Logger::INFO
      when :warn, :warning then Logger::WARN
      when :error then Logger::ERROR
      when :fatal then Logger::FATAL
      when :unknown then Logger::UNKNOWN
      else
        Logger::WARN
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
