module Typesense
  class TypesenseJob < ::ActiveJob::Base
    queue_as { Typesense.configuration[:queue_name] }

    def perform(record, method)
      record.send(method)
    end
  end
end
