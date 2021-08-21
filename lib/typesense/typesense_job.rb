module Typesense
  class TypesenseJob < ::ActiveJob::Base
    queue_as :typesense

    def perform(record, method)
      record.send(method)
    end
  end
end
