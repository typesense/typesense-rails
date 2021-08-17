module TypesenseSearch
  class TypesenseJob < ::ActiveJob::Base
    queue_as :typesensesearch

    def perform(record, method)
      record.send(method)
    end
  end
end
