module TypesenseSearch
  module Pagination
    autoload :WillPaginate, 'typesensesearch/pagination/will_paginate'
    autoload :Kaminari, 'typesensesearch/pagination/kaminari'

    def self.create(results, total_hits, options = {})
      return results if TypesenseSearch.pagination_backend.nil?

      begin
        # classify pagination backend name
        backend = TypesenseSearch.pagination_backend.to_s.gsub(/\/(.?)/) { "::#{$1.upcase}" }.gsub(/(?:^|_)(.)/) { $1.upcase }
        Object.const_get(:TypesenseSearch).const_get(:Pagination).const_get(backend).create(results, total_hits, options)
      rescue NameError
        raise(Typesense::Error::MissingConfiguration, 'Unknown pagination backend')
      end
    end
  end
end
