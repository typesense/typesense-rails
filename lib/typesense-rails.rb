require "typesense"

require "typesense/version"
require "typesense/utilities"

if defined? Rails
  begin
    require "typesense/railtie"
  rescue LoadError
  end
end

begin
  require "active_job"
rescue LoadError
  # no queue support, fine
end

require "logger"

module Typesense
  class NotConfigured < StandardError; end
  class BadConfiguration < StandardError; end
  class NoBlockGiven < StandardError; end

  autoload :Configuration, "typesense/configuration"
  extend Configuration

  autoload :Pagination, "typesense/pagination"

  class << self
    attr_reader :included_in

    def included(klass)
      @included_in ||= []
      @included_in << klass
      @included_in.uniq!

      klass.class_eval do
        extend ClassMethods
        include InstanceMethods
      end
    end
  end

  class IndexSettings
    DEFAULT_BATCH_SIZE = 500

    OPTIONS = [
      :multi_way_synonyms,
      :one_way_synonyms,
      :predefined_fields,
      :default_sorting_field,
      :symbols_to_index,
      :token_separators,
      :enable_nested_fields,
      :metadata,
    ]
    OPTIONS.each do |k|
      define_method k do |v|
        instance_variable_set("@#{k}", v)
      end
    end

    def initialize(options, &block)
      @options = options
      instance_exec(&block) if block_given?
    end

    def use_serializer(serializer)
      @serializer = serializer
    end

    def attribute(*names, &block)
      raise ArgumentError.new("Cannot pass multiple attribute names if block given") if block_given? and names.length > 1
      @attributes ||= {}
      names.flatten.each do |name|
        @attributes[name.to_s] = block_given? ? Proc.new { |o| o.instance_eval(&block) } : Proc.new { |o| o.send(name) }
      end
    end

    alias :attributes :attribute

    def add_attribute(*names, &block)
      raise ArgumentError.new("Cannot pass multiple attribute names if block given") if block_given? and names.length > 1
      @additional_attributes ||= {}
      names.each do |name|
        @additional_attributes[name.to_s] = block_given? ? Proc.new { |o| o.instance_eval(&block) } : Proc.new { |o| o.send(name) }
      end
    end

    alias :add_attributes :add_attribute

    def is_mongoid?(object)
      defined?(::Mongoid::Document) && object.class.include?(::Mongoid::Document)
    end

    def is_sequel?(object)
      defined?(::Sequel) && defined?(::Sequel::Model) && object.class < ::Sequel::Model
    end

    def is_active_record?(object)
      !is_mongoid?(object) && !is_sequel?(object)
    end

    def get_default_attributes(object)
      if is_mongoid?(object)
        # work-around mongoid 2.4's unscoped method, not accepting a block
        object.attributes
      elsif is_sequel?(object)
        object.to_hash
      else
        object.class.unscoped do
          object.attributes
        end
      end
    end

    def get_attribute_names(object)
      get_attributes(object).keys
    end

    def attributes_to_hash(attributes, object)
      if attributes
        Hash[attributes.map { |name, value| [name.to_s, value.call(object)] }]
      else
        {}
      end
    end

    def get_attributes(object)
      # If a serializer is set, we ignore attributes
      # everything should be done via the serializer
      if not @serializer.nil?
        attributes = @serializer.new(object).attributes
      else
        if @attributes.nil? || @attributes.length == 0
          # no `attribute ...` have been configured, use the default attributes of the model
          attributes = get_default_attributes(object)
        else
          # at least 1 `attribute ...` has been configured, therefore use ONLY the one configured
          if is_active_record?(object)
            object.class.unscoped do
              attributes = attributes_to_hash(@attributes, object)
            end
          else
            attributes = attributes_to_hash(@attributes, object)
          end
        end
      end

      attributes.merge!(attributes_to_hash(@additional_attributes, object)) if @additional_attributes
      attributes = sanitize_attributes(attributes, Rails::Html::FullSanitizer.new) if @options[:sanitize]

      if @options[:force_utf8_encoding] && Object.const_defined?(:RUBY_VERSION) && RUBY_VERSION.to_f > 1.8
        attributes = encode_attributes(attributes)
      end

      attributes
    end

    def sanitize_attributes(v, sanitizer)
      case v
      when String
        sanitizer.sanitize(v)
      when Hash
        v.each { |key, value| v[key] = sanitize_attributes(value, sanitizer) }
      when Array
        v.map { |x| sanitize_attributes(x, sanitizer) }
      else
        v
      end
    end

    def encode_attributes(v)
      case v
      when String
        v.dup.force_encoding("utf-8")
      when Hash
        v.each { |key, value| v[key] = encode_attributes(value) }
      when Array
        v.map { |x| encode_attributes(x) }
      else
        v
      end
    end

    def get_setting(name)
      instance_variable_get("@#{name}")
    end
  end

  # Default queueing system
  if defined?(::ActiveJob::Base)
    # lazy load the ActiveJob class to ensure the
    # queue is initialized before using it
    autoload :TypesenseJob, "typesense/typesense_job"
  end

  # these are the class methods added when Typesense is included
  module ClassMethods
    def self.extended(base)
      class << base
        alias_method :without_auto_index, :typesense_without_auto_index unless method_defined? :without_auto_index
        alias_method :reindex!, :typesense_reindex! unless method_defined? :reindex!
        alias_method :reindex, :typesense_reindex unless method_defined? :reindex
        alias_method :index_objects, :typesense_index_objects unless method_defined? :index_objects
        alias_method :index!, :typesense_index! unless method_defined? :index!
        alias_method :remove_from_index!, :typesense_remove_from_index! unless method_defined? :remove_from_index!
        alias_method :clear_index!, :typesense_clear_index! unless method_defined? :clear_index!
        alias_method :search, :typesense_search unless method_defined? :search
        alias_method :raw_search, :typesense_raw_search unless method_defined? :raw_search
        alias_method :index, :typesense_index unless method_defined? :index
        alias_method :index_name, :typesense_index_name unless method_defined? :index_name
        alias_method :must_reindex?, :typesense_must_reindex? unless method_defined? :must_reindex?
        alias_method :create_collection, :typesense_create_collection unless method_defined? :create_collection
        alias_method :upsert_alias, :typesense_upsert_alias unless method_defined? :upsert_alias
        alias_method :get_collection, :typesense_get_collection unless method_defined? :get_collection
        alias_method :num_documents, :typesense_num_documents unless method_defined? :num_documents
        alias_method :get_alias, :typesense_get_alias unless method_defined? :get_alias
        alias_method :upsert_document, :typesense_upsert_document unless method_defined? :upsert_document
        alias_method :import_documents, :typesense_import_documents unless method_defined? :import_documents
        alias_method :retrieve_document, :typesense_retrieve_document unless method_defined? :retrieve_document
        alias_method :delete_document, :typesense_delete_document unless method_defined? :delete_document
        alias_method :delete_collection, :typesense_delete_collection unless method_defined? :delete_collection
        alias_method :delete_by_query, :typesense_delete_by_query unless method_defined? :delete_by_query
        alias_method :search_collection, :typesense_search_collection unless method_defined? :search_collection
        alias_method :multi_way_synonyms, :typesense_multi_way_synonyms unless method_defined? :multi_way_synonyms
        alias_method :one_way_synonyms, :typesense_one_way_synonyms unless method_defined? :one_way_synonyms
      end

      base.cattr_accessor :typesense_options, :typesense_settings, :typesense_client
    end

    def typesense_create_collection(collection_name, settings = nil)
      fields = settings.get_setting(:predefined_fields)
      default_sorting_field = settings.get_setting(:default_sorting_field)
      multi_way_synonyms = settings.get_setting(:multi_way_synonyms)
      one_way_synonyms = settings.get_setting(:one_way_synonyms)
      symbols_to_index = settings.get_setting(:symbols_to_index)
      token_separators = settings.get_setting(:token_separators)
      enable_nested_fields = settings.get_setting(:enable_nested_fields)
      metadata = settings.get_setting(:metadata)

      # Build schema starting with collection name
      schema = { name: collection_name }

      # Add fields or set auto schema
      schema[:fields] = if fields&.any?
          fields
        else
          [{ "name" => ".*", "type" => "auto" }]
        end

      schema[:default_sorting_field] = default_sorting_field if default_sorting_field
      schema[:multi_way_synonyms] = multi_way_synonyms if multi_way_synonyms
      schema[:token_separators] = token_separators if token_separators
      schema[:enable_nested_fields] = enable_nested_fields if enable_nested_fields
      schema[:metadata] = metadata if metadata

      client.collections.create(schema)
      Rails.logger.info "Collection '#{collection_name}' created!"

      multi_way_synonyms(collection_name, multi_way_synonyms) if multi_way_synonyms

      one_way_synonyms(collection_name, one_way_synonyms) if one_way_synonyms
    end

    def typesense_multi_way_synonyms(collection, synonyms)
      synonyms.each do |synonym_hash|
        synonym_hash.each do |synonym_name, synonym|
          typesense_client.collections[collection].synonyms.upsert(
            synonym_name,
            { "synonyms" => synonym }
          )
        end
      end
    end

    def typesense_one_way_synonyms(collection, synonyms)
      synonyms.each do |synonym_hash|
        synonym_hash.each do |synonym_name, synonym|
          typesense_client.collections[collection].synonyms.upsert(
            synonym_name,
            synonym
          )
        end
      end
    end

    def typesense_upsert_alias(collection_name, alias_name)
      typesense_client.aliases.upsert(alias_name, { "collection_name" => collection_name })
    end

    def typesense_get_collection(collection)
      typesense_client.collections[collection].retrieve
    rescue Typesense::Error::ObjectNotFound
      nil
    end

    def typesense_num_documents(collection)
      typesense_client.collections[collection].retrieve["num_documents"]
    end

    def typesense_get_alias(alias_name)
      typesense_client.aliases[alias_name].retrieve
    end

    def typesense_upsert_document(object, collection, dirtyvalues = nil)
      raise ArgumentError, "Object is required" unless object

      typesense_client.collections[collection].documents.upsert(object, dirty_values: dirtyvalues) if dirtyvalues
      typesense_client.collections[collection].documents.upsert(object)
    end

    def typesense_import_documents(jsonl_object, action, collection)
      raise ArgumentError, "JSONL object is required" unless jsonl_object

      typesense_client.collections[collection].documents.import(jsonl_object, action: action)
    end

    def typesense_retrieve_document(object_id, collection = nil)
      if collection
        typesense_client.collections[collection].documents[object_id].retrieve
      else
        collection_obj = typesense_ensure_init
        typesense_client.collections[collection_obj[:alias_name]].documents[object_id].retrieve
      end
    end

    def typesense_delete_document(object_id, collection)
      typesense_client.collections[collection].documents[object_id].delete
    end

    def typesense_delete_by_query(collection, query)
      typesense_client.collections[collection].documents.delete(filter_by: query)
    end

    def typesense_delete_collection(collection)
      typesense_client.collections[collection].delete
    end

    def typesense_search_collection(search_parameters, collection)
      typesense_client.collections[collection].documents.search(search_parameters)
    end

    def typesense(options = {}, &block)
      self.typesense_settings = IndexSettings.new(options, &block)
      self.typesense_options = { type: typesense_full_const_get(model_name.to_s) }.merge(options) # :per_page => typesense_settings.get_setting(:hitsPerPage) || 10, :page => 1
      self.typesense_client ||= Typesense.client
      attr_accessor :highlight_result, :snippet_result

      if options[:enqueue]
        proc = if options[:enqueue] == true
            proc do |record, remove|
              typesenseJob.perform_later(record, remove ? "typesense_remove_from_index!" : "typesense_index!")
            end
          elsif options[:enqueue].respond_to?(:call)
            options[:enqueue]
          elsif options[:enqueue].is_a?(Symbol)
            proc { |record, remove| send(options[:enqueue], record, remove) }
          else
            raise ArgumentError, "Invalid `enqueue` option: #{options[:enqueue]}"
          end
        typesense_options[:enqueue] = proc do |record, remove|
          proc.call(record, remove) unless typesense_without_auto_index_scope
        end
      end
      unless options[:auto_index] == false
        if defined?(::Sequel) && self < Sequel::Model
          class_eval do
            copy_after_validation = instance_method(:after_validation)
            copy_before_save = instance_method(:before_save)

            define_method(:after_validation) do |*args|
              super(*args)
              copy_after_validation.bind(self).call
              typesense_mark_must_reindex
            end

            define_method(:before_save) do |*args|
              copy_before_save.bind(self).call
              typesense_mark_for_auto_indexing
              super(*args)
            end

            sequel_version = Gem::Version.new(Sequel.version)
            if sequel_version >= Gem::Version.new("4.0.0") && sequel_version < Gem::Version.new("5.0.0")
              copy_after_commit = instance_method(:after_commit)
              define_method(:after_commit) do |*args|
                super(*args)
                copy_after_commit.bind(self).call
                typesense_perform_index_tasks
              end
            else
              copy_after_save = instance_method(:after_save)
              define_method(:after_save) do |*args|
                super(*args)
                copy_after_save.bind(self).call
                db.after_commit do
                  typesense_perform_index_tasks
                end
              end
            end
          end
        else
          after_validation :typesense_mark_must_reindex if respond_to?(:after_validation)
          before_save :typesense_mark_for_auto_indexing if respond_to?(:before_save)
          if respond_to?(:after_commit)
            after_commit :typesense_perform_index_tasks
          elsif respond_to?(:after_save)
            after_save :typesense_perform_index_tasks
          end
        end
      end
      unless options[:auto_remove] == false
        if defined?(::Sequel) && self < Sequel::Model
          class_eval do
            copy_after_destroy = instance_method(:after_destroy)

            define_method(:after_destroy) do |*args|
              copy_after_destroy.bind(self).call
              typesense_enqueue_remove_from_index!
              super(*args)
            end
          end
        elsif respond_to?(:after_destroy)
          after_destroy { |searchable| searchable.typesense_enqueue_remove_from_index! }
        end
      end
    end

    def typesense_without_auto_index
      self.typesense_without_auto_index_scope = true
      begin
        yield
      ensure
        self.typesense_without_auto_index_scope = false
      end
    end

    def typesense_without_auto_index_scope=(value)
      Thread.current["typesense_without_auto_index_scope_for_#{model_name}"] = value
    end

    def typesense_without_auto_index_scope
      Thread.current["typesense_without_auto_index_scope_for_#{model_name}"]
    end

    def typesense_reindex!(batch_size = Typesense::IndexSettings::DEFAULT_BATCH_SIZE)
      # typesense_reindex!: Reindexes all objects in database(does not remove deleted objects from the collection)
      return if typesense_without_auto_index_scope

      api_response = nil

      typesense_configurations.each do |options, settings|
        next if typesense_indexing_disabled?(options)

        collection_obj = typesense_ensure_init(options, settings)

        typesense_find_in_batches(batch_size) do |group|
          if typesense_conditional_index?(options)
            # delete non-indexable objects
            ids = group.reject { |o| typesense_indexable?(o, options) }.map { |o| typesense_object_id_of(o, options) }
            delete_by_query(collection_obj[:alias_name], "id: #{ids.reject(&:blank?)}")

            group = group.select { |o| typesense_indexable?(o, options) }
          end
          documents = group.map do |o|
            attributes = settings.get_attributes(o)
            attributes = attributes.to_hash unless attributes.instance_of?(Hash)
            # convert to JSON object
            attributes.merge!("id" => typesense_object_id_of(o, options)).to_json
          end

          jsonl_object = documents.join("\n")
          api_response = import_documents(jsonl_object, "upsert", collection_obj[:alias_name])
        end
      end
      api_response
    end

    # reindex whole database using a extra temporary index + move operation
    def typesense_reindex(batch_size = Typesense::IndexSettings::DEFAULT_BATCH_SIZE)
      # typesense_reindex: Reindexes whole database using alias(removes deleted objects from collection)
      return if typesense_without_auto_index_scope

      typesense_configurations.each do |options, settings|
        next if typesense_indexing_disabled?(options)

        begin
          master_index = typesense_ensure_init(options, settings, false)
          delete_collection(master_index[:alias_name])
        rescue ArgumentError
          @typesense_indexes[settings] = { collection_name: "", alias_name: typesense_index_name(options) }
          master_index = @typesense_indexes[settings]
        end

        # init temporary index
        src_index_name = collection_name(options)
        tmp_options = options.merge({ index_name: src_index_name })
        tmp_options.delete(:per_environment) # already included in the temporary index_name
        tmp_settings = settings.dup

        create_collection(src_index_name, settings)

        typesense_find_in_batches(batch_size) do |group|
          if typesense_conditional_index?(options)
            # select only indexable objects
            group = group.select { |o| typesense_indexable?(o, tmp_options) }
          end
          documents = group.map do |o|
            tmp_settings.get_attributes(o).merge!("id" => typesense_object_id_of(o, tmp_options)).to_json
          end
          jsonl_object = documents.join("\n")
          import_documents(jsonl_object, "upsert", src_index_name)
        end

        upsert_alias(src_index_name, master_index[:alias_name])
        master_index[:collection_name] = src_index_name
      end
      nil
    end

    def typesense_index_objects(objects)
      # typesense_index_objects: Upserts given object array into collection of given model.
      typesense_configurations.each do |options, settings|
        next if typesense_indexing_disabled?(options)

        collection_obj = typesense_ensure_init(options, settings)
        documents = objects.map do |o|
          settings.get_attributes(o).merge!("id" => typesense_object_id_of(o, options)).to_json
        end
        jsonl_object = documents.join("\n")
        import_documents(jsonl_object, "upsert", collection_obj[:alias_name])
        Rails.logger.info "#{objects.length} objects upserted into #{collection_obj[:collection_name]}!"
      end
      nil
    end

    def typesense_index!(object)
      # typesense_index!: Creates a document for the object and retrieves it.
      return if typesense_without_auto_index_scope

      api_response = nil

      typesense_configurations.each do |options, settings|
        next if typesense_indexing_disabled?(options)

        object_id = typesense_object_id_of(object, options)
        collection_obj = typesense_ensure_init(options, settings)

        if typesense_indexable?(object, options)
          raise ArgumentError, "Cannot index a record with a blank objectID" if object_id.blank?

          object = settings.get_attributes(object).merge!("id" => object_id)

          if options[:dirty_values]
            api_response = upsert_document(object, collection_obj[:alias_name], options[:dirty_values])
          else
            api_response = upsert_document(object, collection_obj[:alias_name])
          end
        elsif typesense_conditional_index?(options) && !object_id.blank?
          begin
            api_response = delete_document(object_id, collection_obj[:collection_name])
          rescue Typesense::Error::ObjectNotFound => e
            Rails.logger.error "Object not found in index: #{e.message}"
          end
        end
      end

      api_response
    end

    def typesense_remove_from_index!(object)
      # typesense_remove_from_index: Removes specified object from the collection of given model.
      return if typesense_without_auto_index_scope

      object_id = typesense_object_id_of(object)
      raise ArgumentError, "Cannot index a record with a blank objectID" if object_id.blank?

      typesense_configurations.each do |options, settings|
        next if typesense_indexing_disabled?(options)

        collection_obj = typesense_ensure_init(options, settings, false)

        begin
          delete_document(object_id, collection_obj[:alias_name])
        rescue Typesense::Error::ObjectNotFound => e
          Rails.logger.error "Object #{object_id} could not be removed from #{collection_obj[:collection_name]} collection! Use reindex to update the collection."
        end
        Rails.logger.info "Removed document with object id '#{object_id}' from #{collection_obj[:collection_name]}"
      end
      nil
    end

    def typesense_clear_index!
      # typesense_clear_index!: Delete collection of given model.
      typesense_configurations.each do |options, settings|
        next if typesense_indexing_disabled?(options)

        collection_obj = typesense_ensure_init(options, settings, false)

        delete_collection(collection_obj[:alias_name])
        Rails.logger.info "Deleted #{collection_obj[:alias_name]} collection!"
        @typesense_indexes[settings] = nil
      end
      nil
    end

    def typesense_raw_search(q, query_by, params = {})
      # typesense_raw_search: JSON output of search.
      params[:page] = params[:page] ? params[:page].to_i : 1
      collection_obj = typesense_index # index_name)
      search_collection(params.merge({ q: q, query_by: query_by }), collection_obj[:alias_name])
    end
  end

end
