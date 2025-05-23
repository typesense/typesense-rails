unless defined? Pagy
  raise(Typesense::BadConfiguration, "Typesense: Please add 'pagy' to your Gemfile to use Pagy pagination backend")
end

module Typesense
  module Pagination
    class Pagy

      def self.create(results, total_hits, options = {})
        vars = {
          count: total_hits,
          page: options[:page],
          items: options[:per_page]
        }

        pagy_version = Gem::Version.new(::Pagy::VERSION)
        pagy = if pagy_version >= Gem::Version.new('9.0')
                 ::Pagy.new(**vars)
               else
                 ::Pagy.new(vars)
               end

        [pagy, results]
      end
    end

  end
end

