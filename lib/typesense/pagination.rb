module Typesense
  module Pagination

    autoload :WillPaginate, 'typesense/pagination/will_paginate'
    autoload :Kaminari, 'typesense/pagination/kaminari'
    autoload :Pagy, 'typesense/pagination/pagy'

    def self.create(results, total_hits, options = {})
      return results if Typesense.configuration[:pagination_backend].nil?
      begin
        backend = Typesense.configuration[:pagination_backend].to_s.gsub(/\/(.?)/) { "::#{$1.upcase}" }.gsub(/(?:^|_)(.)/) { $1.upcase } # classify pagination backend name
        page = Object.const_get(:Typesense).const_get(:Pagination).const_get(backend).create(results, total_hits, options)
        page
      rescue NameError
        raise(BadConfiguration, "Unknown pagination backend")
      end
    end
    
  end
end
