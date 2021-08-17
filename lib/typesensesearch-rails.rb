# require 'algolia'
require 'typesense'
require 'typesensesearch/version'
require 'typesensesearch/utilities'
require 'rails/all'

if defined? Rails
  begin
    require 'typesensesearch/railtie'
  rescue LoadError
  end
end

begin
  require 'active_job'
rescue LoadError
  # no queue support, fine
end

require 'logger'
Rails.logger = Logger.new(STDOUT)
Rails.logger.level = Logger::INFO

module TypesenseSearch
  class NotConfigured < StandardError; end

  class BadConfiguration < StandardError; end

  class NoBlockGiven < StandardError; end

  class MixedSlavesAndReplicas < StandardError; end

  autoload :Configuration, 'typesensesearch/configuration'
  extend Configuration

  autoload :Pagination, 'typesensesearch/pagination'

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
    DEFAULT_BATCH_SIZE = 250

    # TypesenseSearch settings
    OPTIONS = %i[
      multi_way_synonyms one_way_synonyms predefined_fields default_sorting_field
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
      # instance_variable_set("@serializer", serializer)
    end

    def attribute(*names, &block)
      raise ArgumentError, 'Cannot pass multiple attribute names if block given' if block_given? && (names.length > 1)

      @attributes ||= {}
      names.flatten.each do |name|
        @attributes[name.to_s] = block_given? ? proc { |o| o.instance_eval(&block) } : proc { |o| o.send(name) }
      end
    end

    alias attributes attribute

    def add_attribute(*names, &block)
      raise ArgumentError, 'Cannot pass multiple attribute names if block given' if block_given? && (names.length > 1)

      @additional_attributes ||= {}
      names.each do |name|
        @additional_attributes[name.to_s] = if block_given?
                                              proc { |o| o.instance_eval(&block) }
                                            else
                                              proc { |o|
                                                o.send(name)
                                              }
                                            end
      end
    end

    alias add_attributes add_attribute

    def mongoid?(object)
      defined?(::Mongoid::Document) && object.class.include?(::Mongoid::Document)
    end

    def sequel?(object)
      defined?(::Sequel) && object.class < ::Sequel::Model
    end

    def active_record?(object)
      !mongoid?(object) && !sequel?(object)
    end

    def get_default_attributes(object)
      if mongoid?(object)
        # work-around mongoid 2.4's unscoped method, not accepting a block
        object.attributes
      elsif sequel?(object)
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
      if !@serializer.nil?
        attributes = @serializer.new(object).attributes
      elsif @attributes.nil? || @attributes.length.zero?
        attributes = get_default_attributes(object)
      # no `attribute ...` have been configured, use the default attributes of the model
      elsif active_record?(object)
        # at least 1 `attribute ...` has been configured, therefore use ONLY the one configured
        object.class.unscoped do
          attributes = attributes_to_hash(@attributes, object)
        end
      else
        attributes = attributes_to_hash(@attributes, object)
      end

      attributes.merge!(attributes_to_hash(@additional_attributes, object)) if @additional_attributes

      if @options[:sanitize]
        sanitizer = begin
          ::HTML::FullSanitizer.new
        rescue NameError
          # from rails 4.2
          ::Rails::Html::FullSanitizer.new
        end
        attributes = sanitize_attributes(attributes, sanitizer)
      end

      attributes = encode_attributes(attributes) if @options[:force_utf8_encoding] && Object.const_defined?(:RUBY_VERSION) && RUBY_VERSION.to_f > 1.8

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
        v.force_encoding('utf-8')
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
    autoload :TypesenseJob, 'typesensesearch/typesense_job'
  end

  # these are the class methods added when TypesenseSearch is included
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
      end

      base.cattr_accessor :typesensesearch_options, :typesensesearch_settings, :typesense_client
    end

    def collection_name(options)
      "#{typesense_index_name(options)}_#{Time.now.to_i}"
    end

    def typesense_create_collection(collection_name, settings = nil)
      fields = settings.get_setting(:predefined_fields)
      default_sorting_field = settings.get_setting(:default_sorting_field)
      multi_way_synonyms = settings.get_setting(:multi_way_synonyms)
      one_way_synonyms = settings.get_setting(:one_way_synonyms)
      typesense_client.collections.create(
        { 'name' => collection_name }
          .merge(
            if fields
              { 'fields' => fields.push({ 'name' => 'id',
                                          'type' => 'string' }) }
            else
              { 'fields' => [{ 'name' => 'id', 'type' => 'string' },
                             { 'name' => '.*',
                               'type' => 'auto' }] }
            end,
            default_sorting_field ? { 'default_sorting_field' => default_sorting_field } : {}
          )
      )
      Rails.logger.info "Collection '#{collection_name}' created!"

      typesense_multi_way_synonyms(collection_name, multi_way_synonyms) if multi_way_synonyms

      typesense_one_way_synonyms(collection_name, one_way_synonyms) if one_way_synonyms
    end

    def typesense_upsert_alias(collection_name, alias_name)
      typesense_client.aliases.upsert(alias_name, { 'collection_name' => collection_name })
    end

    def typesense_get_collection(collection)
      typesense_client.collections[collection].retrieve
    rescue Typesense::Error::ObjectNotFound
      nil
    end

    def typesense_num_documents(collection)
      typesense_client.collections[collection].retrieve['num_documents']
    end

    def typesense_get_alias(alias_name)
      typesense_client.aliases[alias_name].retrieve
    end

    def typesense_upsert_document(object, collection, dirtyvalues = nil)
      raise ArgumentError, 'Object is required' unless object

      typesense_client.collections[collection].documents.upsert(object, dirty_values: dirtyvalues) if dirtyvalues
      typesense_client.collections[collection].documents.upsert(object)
    end

    def typesense_import_documents(jsonl_object, action, collection)
      raise ArgumentError, 'JSONL object is required' unless jsonl_object

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
      typesense_client.collections[collection].documents.delete('filter_by': query)
    end

    def typesense_delete_collection(collection)
      typesense_client.collections[collection].delete
    end

    def typesense_search_collection(search_parameters, collection)
      typesense_client.collections[collection].documents.search(search_parameters)
    end

    def typesense_multi_way_synonyms(collection, synonyms)
      synonyms.each do |synonym_hash|
        synonym_hash.each do |synonym_name, synonym|
          typesense_client.collections[collection].synonyms.upsert(
            synonym_name,
            { 'synonyms' => synonym }
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

    def typesense(options = {}, &block)
      self.typesensesearch_settings = IndexSettings.new(options, &block)
      self.typesensesearch_options = { type: typesense_full_const_get(model_name.to_s) }.merge(options) # :per_page => typesensesearch_settings.get_setting(:hitsPerPage) || 10, :page => 1
      self.typesense_client ||= TypesenseSearch.client
      attr_accessor :highlight_result, :snippet_result

      if options[:enqueue]
        proc = if options[:enqueue] == true
                 proc do |record, remove|
                   typesenseJob.perform_later(record, remove ? 'typesense_remove_from_index!' : 'typesense_index!')
                 end
               elsif options[:enqueue].respond_to?(:call)
                 options[:enqueue]
               elsif options[:enqueue].is_a?(Symbol)
                 proc { |record, remove| send(options[:enqueue], record, remove) }
               else
                 raise ArgumentError, "Invalid `enqueue` option: #{options[:enqueue]}"
               end
        typesensesearch_options[:enqueue] = proc do |record, remove|
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
            if sequel_version >= Gem::Version.new('4.0.0') && sequel_version < Gem::Version.new('5.0.0')
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

    def typesense_reindex!(batch_size = TypesenseSearch::IndexSettings::DEFAULT_BATCH_SIZE)
      # typesense_reindex!: Reindexes all objects in database(does not remove deleted objects from the collection)
      return if typesense_without_auto_index_scope

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
            attributes.merge!('id' => typesense_object_id_of(o, options)).to_json
          end

          jsonl_object = documents.join("\n")
          import_documents(jsonl_object, 'upsert', collection_obj[:alias_name])
        end
      end
      nil
    end

    def typesense_reindex(batch_size = TypesenseSearch::IndexSettings::DEFAULT_BATCH_SIZE)
      # typesense_reindex: Reindexes whole database using alias(removes deleted objects from collection)
      return if typesense_without_auto_index_scope

      typesense_configurations.each do |options, settings|
        next if typesense_indexing_disabled?(options)

        begin
          master_index = typesense_ensure_init(options, settings, false)
          delete_collection(master_index[:alias_name])
        rescue ArgumentError
          @typesense_indexes[settings] = { collection_name: '', alias_name: typesense_index_name(options) }
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
            tmp_settings.get_attributes(o).merge!('id' => typesense_object_id_of(o, tmp_options)).to_json
          end
          jsonl_object = documents.join("\n")
          import_documents(jsonl_object, 'upsert', src_index_name)
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
          settings.get_attributes(o).merge!('id' => typesense_object_id_of(o, options)).to_json
        end
        jsonl_object = documents.join("\n")
        import_documents(jsonl_object, 'upsert', collection_obj[:alias_name])
        Rails.logger.info "#{objects.length} objects upserted into #{collection_obj[:collection_name]}!"
      end
      nil
    end

    def typesense_index!(object)
      # typesense_index!: Creates a document for the object and retrieves it.
      return if typesense_without_auto_index_scope

      typesense_configurations.each do |options, settings|
        next if typesense_indexing_disabled?(options)

        object_id = typesense_object_id_of(object, options)
        collection_obj = typesense_ensure_init(options, settings)

        if typesense_indexable?(object, options)
          raise ArgumentError, 'Cannot index a record with a blank objectID' if object_id.blank?

          object = settings.get_attributes(object).merge!('id' => object_id)

          if options[:dirty_values]
            upsert_document(object, collection_obj[:alias_name], options[:dirty_values])
          else
            upsert_document(object, collection_obj[:alias_name])
          end

        elsif typesense_conditional_index?(options) && !object_id.blank?

          begin
            delete_document(object_id, collection_obj[:collection_name])
          rescue Typesense::Error::ObjectNotFound => e
            Rails.logger.error "Object not found in index: #{e.message}"
          end
        end
      end
      nil
    end

    def typesense_remove_from_index!(object)
      # typesense_remove_from_index: Removes specified object from the collection of given model.
      return if typesense_without_auto_index_scope

      object_id = typesense_object_id_of(object)
      raise ArgumentError, 'Cannot index a record with a blank objectID' if object_id.blank?

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
      collection_obj = typesense_index # index_name)
      search_collection(params.merge({ 'q': q, 'query_by': query_by }), collection_obj[:alias_name])
    end

    module AdditionalMethods
      def self.extended(base)
        class << base
          alias_method :raw_answer, :typesense_raw_answer unless method_defined? :raw_answer
          alias_method :facets, :typesense_facets unless method_defined? :facets
        end
      end

      def typesense_raw_answer
        @typesense_json
      end

      def typesense_facets
        @typesense_json['facets']
      end

      private

      def typesense_init_raw_answer(json)
        @typesense_json = json
      end
    end

    def typesense_search(q, query_by, params = {})
      # typsense_search: Searches and returns matching objects from the database.

      json = typesense_raw_search(q, query_by, params)
      hit_ids = json['hits'].map { |hit| hit['document']['id'] }

      condition_key = if defined?(::Mongoid::Document) && include?(::Mongoid::Document)
                        typesense_object_id_method.in
                      else
                        typesense_object_id_method
                      end

      results_by_id = typesensesearch_options[:type].where(condition_key => hit_ids).index_by do |hit|
        typesense_object_id_of(hit)
      end

      results = json['hits'].map do |hit|
        o = results_by_id[hit['document']['id'].to_s]
        next unless o

        o.highlight_result = hit['highlights']
        o.snippet_result = hit['highlights'].map do |highlight|
          highlight['snippet']
        end
        o
      end.compact

      total_hits = json['found']
      res = TypesenseSearch::Pagination.create(results, total_hits,
                                               typesensesearch_options.merge({ page: json['page'].to_i, per_page: json['request_params']['per_page'] }))
      res.extend(AdditionalMethods)
      res.send(:typesense_init_raw_answer, json)
      res
    end

    def typesense_index(name = nil)
      # typesense_index: Creates collection and its alias.
      if name
        typesense_configurations.each do |o, s|
          return typesense_ensure_init(o, s) if o[:index_name].to_s == name.to_s
        end
        raise ArgumentError, "Invalid index/replica name: #{name}"
      end
      typesense_ensure_init
    end

    def typesense_index_name(options = nil)
      options ||= typesensesearch_options
      name = options[:index_name] || model_name.to_s.gsub('::', '_')
      name = "#{name}_#{Rails.env}" if options[:per_environment]
      name
    end

    def typesense_must_reindex?(object)
      # use +typesense_dirty?+ method if implemented
      return object.send(:typesense_dirty?) if object.respond_to?(:typesense_dirty?)

      # Loop over each index to see if a attribute used in records has changed
      typesense_configurations.each do |options, settings|
        next if typesense_indexing_disabled?(options)
        # next if options[:replica]
        return true if typesense_object_id_changed?(object, options)

        settings.get_attribute_names(object).each do |k|
          return true if typesense_attribute_changed?(object, k)
          # return true if !object.respond_to?(changed_method) || object.send(changed_method)
        end
        [options[:if], options[:unless]].each do |condition|
          case condition
          when nil
          when String, Symbol
            return true if typesense_attribute_changed?(object, condition)
          else
            # if the :if, :unless condition is a anything else,
            # we have no idea whether we should reindex or not
            # let's always reindex then
            return true
          end
        end
      end
      # By default, we don't reindex
      false
    end

    protected

    def typesense_ensure_init(options = nil, settings = nil, create = true)
      raise ArgumentError, 'No `typesense` block found in your model.' if typesensesearch_settings.nil?

      @typesense_indexes ||= {}

      options ||= typesensesearch_options
      settings ||= typesensesearch_settings

      return @typesense_indexes[settings] if @typesense_indexes[settings] && get_collection(@typesense_indexes[settings][:alias_name])

      alias_name = typesense_index_name(options)
      collection = get_collection(alias_name)

      if collection
        collection_name = collection['name']
      else
        collection_name = self.collection_name(options)
        raise ArgumentError, "#{collection_name} is not found in your model." unless create

        create_collection(collection_name, settings)
        upsert_alias(collection_name, alias_name)
      end
      @typesense_indexes[settings] = { collection_name: collection_name, alias_name: alias_name }

      @typesense_indexes[settings]
    end

    private

    def typesense_configurations
      raise ArgumentError, 'No `typesense` block found in your model.' if typesensesearch_settings.nil?

      if @configurations.nil?
        @configurations = {}
        @configurations[typesensesearch_options] = typesensesearch_settings
      end
      @configurations
    end

    def typesense_object_id_method(options = nil)
      options ||= typesensesearch_options
      options[:id] || options[:object_id] || :id
    end

    def typesense_object_id_of(o, options = nil)
      o.send(typesense_object_id_method(options)).to_s
    end

    def typesense_object_id_changed?(o, options = nil)
      changed = typesense_attribute_changed?(o, typesense_object_id_method(options))
      changed.nil? ? false : changed
    end

    def typesensesearch_settings_changed?(prev, current)
      return true if prev.nil?

      current.each do |k, v|
        prev_v = prev[k.to_s]
        if v.is_a?(Array) && prev_v.is_a?(Array)
          # compare array of strings, avoiding symbols VS strings comparison
          return true if v.map(&:to_s) != prev_v.map(&:to_s)
        elsif prev_v != v
          return true
        end
      end
      false
    end

    def typesense_full_const_get(name)
      list = name.split('::')
      list.shift if list.first.blank?
      obj = Object.const_defined?(:RUBY_VERSION) && RUBY_VERSION.to_f < 1.9 ? Object : self
      list.each do |x|
        # This is required because const_get tries to look for constants in the
        # ancestor chain, but we only want constants that are HERE
        obj = obj.const_defined?(x) ? obj.const_get(x) : obj.const_missing(x)
      end
      obj
    end

    def typesense_conditional_index?(options = nil)
      options ||= typesensesearch_options
      options[:if].present? || options[:unless].present?
    end

    def typesense_indexable?(object, options = nil)
      options ||= typesensesearch_options
      if_passes = options[:if].blank? || typesense_constraint_passes?(object, options[:if])
      unless_passes = options[:unless].blank? || !typesense_constraint_passes?(object, options[:unless])
      if_passes && unless_passes
    end

    def typesense_constraint_passes?(object, constraint)
      case constraint
      when Symbol
        object.send(constraint)
      when String
        object.send(constraint.to_sym)
      when Enumerable
        # All constraints must pass
        constraint.all? { |inner_constraint| typesense_constraint_passes?(object, inner_constraint) }
      else
        raise ArgumentError, "Unknown constraint type: #{constraint} (#{constraint.class})" unless constraint.respond_to?(:call)

        constraint.call(object)
      end
    end

    def typesense_indexing_disabled?(options = nil)
      options ||= typesensesearch_options
      constraint = options[:disable_indexing] || options['disable_indexing']
      case constraint
      when nil
        return false
      when true, false
        return constraint
      when String, Symbol
        return send(constraint)
      else
        return constraint.call if constraint.respond_to?(:call) # Proc
      end
      raise ArgumentError, "Unknown constraint type: #{constraint} (#{constraint.class})"
    end

    def typesense_find_in_batches(batch_size, &block)
      if (defined?(::ActiveRecord) && ancestors.include?(::ActiveRecord::Base)) || respond_to?(:find_in_batches)
        find_in_batches(batch_size: batch_size, &block)
      elsif defined?(::Sequel) && self < Sequel::Model
        dataset.extension(:pagination).each_page(batch_size, &block)
      else
        # don't worry, mongoid has its own underlying cursor/streaming mechanism
        items = []
        all.each do |item|
          items << item
          if items.length % batch_size.zero?
            yield items
            items = []
          end
        end
        yield items unless items.empty?
      end
    end

    def typesense_attribute_changed?(object, attr_name)
      # if one of two method is implemented, we return its result
      # true/false means whether it has changed or not
      # +#{attr_name}_changed?+ always defined for automatic attributes but deprecated after Rails 5.2
      # +will_save_change_to_#{attr_name}?+ should be use instead for Rails 5.2+, also defined for automatic attributes.
      # If none of the method are defined, it's a dynamic attribute

      method_name = "#{attr_name}_changed?"
      if object.respond_to?(method_name)
        # If +#{attr_name}_changed?+ respond we want to see if the method is user defined or if it's automatically
        # defined by Rails.
        # If it's user-defined, we call it.
        # If it's automatic we check ActiveRecord version to see if this method is deprecated
        # and try to call +will_save_change_to_#{attr_name}?+ instead.
        # See: https://github.com/typesense/typesense-rails/pull/338
        # This feature is not compatible with Ruby 1.8
        # In this case, we always call #{attr_name}_changed?
        return object.send(method_name) if Object.const_defined?(:RUBY_VERSION) && RUBY_VERSION.to_f < 1.9
        return object.send(method_name) unless automatic_changed_method?(object, method_name) && automatic_changed_method_deprecated?
      end

      return object.send("will_save_change_to_#{attr_name}?") if object.respond_to?("will_save_change_to_#{attr_name}?")

      # We don't know if the attribute has changed, so conservatively assume it has
      true
    end

    def automatic_changed_method?(object, method_name)
      unless object.respond_to?(method_name)
        raise ArgumentError,
              "Method #{method_name} doesn't exist on #{object.class.name}"
      end

      file = object.method(method_name).source_location[0]
      file.end_with?('active_model/attribute_methods.rb')
    end

    def automatic_changed_method_deprecated?
      (defined?(::ActiveRecord) && ActiveRecord::VERSION::MAJOR >= 5 && ActiveRecord::VERSION::MINOR >= 1) ||
        (defined?(::ActiveRecord) && ActiveRecord::VERSION::MAJOR > 5)
    end
  end

  # these are the instance methods included
  module InstanceMethods
    def self.included(base)
      base.instance_eval do
        alias_method :index!, :typesense_index! unless method_defined? :index!
        alias_method :remove_from_index!, :typesense_remove_from_index! unless method_defined? :remove_from_index!
      end
    end

    def typesense_index!
      self.class.typesense_index!(self)
    end

    def typesense_remove_from_index!
      self.class.typesense_remove_from_index!(self)
    end

    def typesense_enqueue_remove_from_index!
      if typesensesearch_options[:enqueue]
        typesensesearch_options[:enqueue].call(self, true) unless self.class.send(:typesense_indexing_disabled?,
                                                                                  typesensesearch_options)
      else
        typesense_remove_from_index!
      end
    end

    def typesense_enqueue_index!
      if typesensesearch_options[:enqueue]
        typesensesearch_options[:enqueue].call(self, false) unless self.class.send(:typesense_indexing_disabled?,
                                                                                   typesensesearch_options)
      else
        typesense_index!
      end
    end

    private

    def typesense_mark_for_auto_indexing
      @typesense_auto_indexing = true
    end

    def typesense_mark_must_reindex
      # typesense_must_reindex flag is reset after every commit as part. If we must reindex at any point in
      # a stransaction, keep flag set until it is explicitly unset
      @typesense_must_reindex ||= if defined?(::Sequel) && is_a?(Sequel::Model)
                                    new? || self.class.typesense_must_reindex?(self)
                                  else
                                    new_record? || self.class.typesense_must_reindex?(self)
                                  end
      true
    end

    def typesense_perform_index_tasks
      return if !@typesense_auto_indexing || @typesense_must_reindex == false

      typesense_enqueue_index!
      remove_instance_variable(:@typesense_auto_indexing) if instance_variable_defined?(:@typesense_auto_indexing)
      remove_instance_variable(:@typesense_must_reindex) if instance_variable_defined?(:@typesense_must_reindex)
    end
  end
end
