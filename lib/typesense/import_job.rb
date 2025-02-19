module Typesense
  class ImportJob < ::ActiveJob::Base
    queue_as { Typesense.configuration[:queue_name] }

    def self.perform(jsonl_object, collection_name, batch_size)
      new.perform_later(jsonl_object, collection_name, batch_size)
    end

    def perform_later(jsonl_object, collection_name, batch_size)
      # Initialize client with longer timeout for batch operations
      client = Typesense::Client.new(Typesense.configuration.merge(
        connection_timeout_seconds: 3600,
      ))

      client.collections[collection_name].documents.import(jsonl_object, {
        action: "upsert",
        batch_size: batch_size,
      })
    end
  end
end
