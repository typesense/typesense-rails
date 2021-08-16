require File.expand_path(File.join(File.dirname(__FILE__), 'spec_helper'))

NEW_RAILS = Gem.loaded_specs['rails'].version >= Gem::Version.new('6.0')

require 'active_record'
unless NEW_RAILS
  require 'active_job/test_helper'
  ActiveJob::Base.queue_adapter = :test
end
require 'sqlite3' unless defined?(JRUBY_VERSION)
require 'logger'
require 'sequel'
require 'active_model_serializers'

AlgoliaSearch.configuration = {
  nodes: [{
    host: 'localhost',   # For Typesense Cloud use xxx.a1.typesense.net
    port: 8108,          # For Typesense Cloud use 443
    protocol: 'http' # For Typesense Cloud use https
  }],
  api_key: 'xyz',
  connection_timeout_seconds: 2
}

begin
  FileUtils.rm('data.sqlite3')
rescue StandardError
  nil
end
ActiveRecord::Base.logger = Logger.new(STDOUT)
ActiveRecord::Base.logger.level = Logger::WARN
ActiveRecord::Base.establish_connection(
  'adapter' => defined?(JRUBY_VERSION) ? 'jdbcsqlite3' : 'sqlite3',
  'database' => 'data.sqlite3',
  'pool' => 5,
  'timeout' => 5000
)

if ActiveRecord::Base.respond_to?(:raise_in_transactional_callbacks)
  ActiveRecord::Base.raise_in_transactional_callbacks = true
end

SEQUEL_DB = Sequel.connect(if defined?(JRUBY_VERSION)
                             'jdbc:sqlite:sequel_data.sqlite3'
                           else
                             { 'adapter' => 'sqlite',
                               'database' => 'sequel_data.sqlite3' }
                           end)

unless SEQUEL_DB.table_exists?(:sequel_books)
  SEQUEL_DB.create_table(:sequel_books) do
    primary_key :id
    String :name
    String :author
    FalseClass :released
    FalseClass :premium
  end
end

ActiveRecord::Schema.define do
  create_table :products do |t|
    t.string :name
    t.string :href
    # t.string :tags
    t.string :type
    t.text :description
    t.datetime :release_date
  end
  create_table :colors do |t|
    t.string :name
    t.string :short_name
    t.integer :hex
  end
  create_table :namespaced_models do |t|
    t.string :name
    t.integer :another_private_value
  end
  create_table :uniq_users, id: false do |t|
    t.string :name
  end
  create_table :nullable_ids do |t|
  end
  create_table :nested_items do |t|
    t.integer :parent_id
    t.boolean :hidden
  end
  create_table :cities do |t|
    t.string :name
    t.string :country
    t.float :lat
    t.float :lng
    t.string :gl_array
  end
  create_table :with_slaves do |t|
  end
  create_table :mongo_objects do |t|
    t.string :name
  end
  create_table :books do |t|
    t.string :name
    t.string :author
    t.boolean :premium
    t.boolean :released
  end
  create_table :ebooks do |t|
    t.string :name
    t.string :author
    t.boolean :premium
    t.boolean :released
  end
  create_table :disabled_booleans do |t|
    t.string :name
  end
  create_table :disabled_procs do |t|
    t.string :name
  end
  create_table :disabled_symbols do |t|
    t.string :name
  end
  create_table :encoded_strings do |t|
  end
  create_table :forward_to_replicas do |t|
    t.string :name
  end
  create_table :forward_to_replicas_twos do |t|
    t.string :name
  end
  create_table :sub_replicas do |t|
    t.string :name
  end
  create_table :enqueued_objects do |t|
    t.string :name
  end
  create_table :disabled_enqueued_objects do |t|
    t.string :name
  end
  create_table :misconfigured_blocks do |t|
    t.string :name
  end
  if defined?(ActiveModel::Serializer)
    create_table :serialized_objects do |t|
      t.string :name
      t.string :skip
    end
  end
end

class Product < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch auto_index: false,
                if: :published?, unless: ->(o) { o.href.blank? },
                index_name: safe_index_name('my_products_index') do
    attribute :href, :name # , :tags

    multi_way_synonyms [
      { 'phone-synonym' => %w[galaxy samsung samsung_electronics] }
    ]

    one_way_synonyms [
      { 'smart-phone-synonym' => { 'root' => 'smartphone',
                                   'synonyms' => %w[nokia samsung motorola android] } }
    ]
  end

  def published?
    release_date.blank? || release_date <= Time.now
  end
end

class Camera < Product
end

class Color < ActiveRecord::Base
  include AlgoliaSearch
  attr_accessor :not_indexed

  algoliasearch index_name: safe_index_name('Color'), per_environment: true do
    predefined_fields [
      { 'name' => 'name', 'type' => 'string', 'facet' => true },
      { 'name' => 'short_name', 'type' => 'string', 'index' => false, 'optional' => true },
      { 'name' => 'hex', 'type' => 'int32' }
    ]

    default_sorting_field 'hex'

    # we're using all attributes of the Color class + the _tag "extra" attribute
  end

  def hex_changed?
    false
  end

  def will_save_change_to_short_name?
    false
  end
end

class DisabledBoolean < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch disable_indexing: true, index_name: safe_index_name('DisabledBoolean') do
  end
end

class DisabledProc < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch disable_indexing: proc { true }, index_name: safe_index_name('DisabledProc') do
  end
end

class DisabledSymbol < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch disable_indexing: :truth, index_name: safe_index_name('DisabledSymbol') do
  end

  def self.truth
    true
  end
end

module Namespaced
  def self.table_name_prefix
    'namespaced_'
  end
end

class Namespaced::Model < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch index_name: safe_index_name(algolia_index_name({})) do
    attribute :customAttr do
      40 + another_private_value
    end
    attribute :myid do
      id
    end
  end
end

class UniqUser < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch index_name: safe_index_name('UniqUser'), per_environment: true, id: :name do
  end
end

class NullableId < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch index_name: safe_index_name('NullableId'), per_environment: true, id: :custom_id,
                if: :never do
  end

  def custom_id
    nil
  end

  def never
    false
  end
end

class NestedItem < ActiveRecord::Base
  has_many :children, class_name: 'NestedItem', foreign_key: 'parent_id'

  include AlgoliaSearch

  algoliasearch index_name: safe_index_name('NestedItem'), per_environment: true, unless: :hidden do
    attribute :nb_children
  end

  def nb_children
    children.count
  end
end

class City < ActiveRecord::Base
  include AlgoliaSearch

  serialize :gl_array

  def location
    lat.present? && lng.present? ? [lat, lng] : gl_array
  end

  algoliasearch index_name: safe_index_name('City'), per_environment: true do
    add_attribute :a_null_lat, :a_lng, :location

    predefined_fields [{ 'name' => 'location', 'type' => 'geopoint' }]
  end

  def a_null_lat
    nil
  end

  def a_lng
    1.2345678
  end
end

class SequelBook < Sequel::Model(SEQUEL_DB)
  plugin :active_model

  include AlgoliaSearch

  algoliasearch index_name: safe_index_name('SequelBook'), per_environment: true, sanitize: true do
    add_attribute :test
    add_attribute :test2
  end

  def after_create
    SequelBook.new
  end

  def test
    'test'
  end

  def test2
    'test2'
  end

  private

  def public?
    released && !premium
  end
end

describe 'SequelBook' do
  before(:all) do
    SequelBook.clear_index!
  rescue StandardError
    ArgumentError
  end

  it 'should index the book' do
    @steve_jobs = SequelBook.create name: 'Steve Jobs', author: 'Walter Isaacson', premium: true,
                                    released: true
    results = SequelBook.search('steve', 'name')
    expect(results.size).to eq(1)
    expect(results[0].id).to eq(@steve_jobs.id)
  end

  it 'should not override after hooks' do
    expect(SequelBook).to receive(:new).twice.and_call_original
    SequelBook.create name: 'Steve Jobs', author: 'Walter Isaacson', premium: true, released: true
  end
end

class MongoObject < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch index_name: safe_index_name('MongoObject') do
  end

  def self.reindex!
    raise NameError, 'never reached'
  end

  def index!
    raise NameError, 'never reached'
  end
end

class Book < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch index_name: safe_index_name('SecuredBook'), per_environment: true, sanitize: true do
  end

  private

  def public?
    released && !premium
  end
end

class Ebook < ActiveRecord::Base
  include AlgoliaSearch
  attr_accessor :current_time, :published_at

  algoliasearch index_name: safe_index_name('eBooks') do
  end

  def algolia_dirty?
    return true if published_at.nil? || current_time.nil?

    # Consider dirty if published date is in the past
    # This doesn't make so much business sense but it's easy to test.
    published_at < current_time
  end
end

class EncodedString < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch force_utf8_encoding: true, index_name: safe_index_name('EncodedString') do
    attribute :value do
      "\xC2\xA0\xE2\x80\xA2\xC2\xA0".force_encoding('ascii-8bit')
    end
  end
end

class SubReplicas < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch force_utf8_encoding: true, index_name: safe_index_name('SubReplicas') do
  end
end

class EnqueuedObject < ActiveRecord::Base
  include AlgoliaSearch

  include GlobalID::Identification

  def id
    read_attribute(:id)
  end

  def self.find(_id)
    EnqueuedObject.first
  end

  algoliasearch enqueue: proc { |record| raise "enqueued #{record.id}" },
                index_name: safe_index_name('EnqueuedObject') do
    attributes ['name']
  end
end

class DisabledEnqueuedObject < ActiveRecord::Base
  include AlgoliaSearch

  algoliasearch(enqueue: proc { |_record| raise 'enqueued' },
                index_name: safe_index_name('EnqueuedObject'),
                disable_indexing: true) do
    attributes ['name']
  end
end

class MisconfiguredBlock < ActiveRecord::Base
  include AlgoliaSearch
end

if defined?(ActiveModel::Serializer)
  class SerializedObjectSerializer < ActiveModel::Serializer
    attributes :name
  end

  class SerializedObject < ActiveRecord::Base
    include AlgoliaSearch

    algoliasearch index_name: safe_index_name('SerializedObject') do
      use_serializer SerializedObjectSerializer
    end
  end
end

if defined?(ActiveModel::Serializer)
  describe 'SerializedObject' do
    before(:all) do
      SerializedObject.clear_index!
    rescue StandardError
      ArgumentError
    end

    it 'should push the name but not the other attribute' do
      o = SerializedObject.new name: 'test', skip: 'skip me'
      attributes = SerializedObject.algoliasearch_settings.get_attributes(o)
      expect(attributes).to eq({ name: 'test' }) # , "_tags" => ['tag1', 'tag2']})
    end
  end
end

describe 'Encoding' do
  before(:all) do
    EncodedString.clear_index!
  rescue StandardError
    ArgumentError
  end

  if Object.const_defined?(:RUBY_VERSION) && RUBY_VERSION.to_f > 1.8
    it 'should convert to utf-8' do
      EncodedString.create!
      results = EncodedString.raw_search('', 'value')
      expect(results['hits'].size).to eq(1)
      expect(results['hits'].first['document']['value']).to eq("\xC2\xA0\xE2\x80\xA2\xC2\xA0".force_encoding('utf-8'))
    end
  end
end

describe 'Settings' do
  it 'should detect settings changes' do
    Color.send(:algoliasearch_settings_changed?, nil, {}).should == true
    Color.send(:algoliasearch_settings_changed?, {}, { 'searchableAttributes' => ['name'] }).should == true
    Color.send(:algoliasearch_settings_changed?, { 'searchableAttributes' => ['name'] },
               { 'searchableAttributes' => %w[name hex] }).should == true
    Color.send(:algoliasearch_settings_changed?, { 'searchableAttributes' => ['name'] },
               { 'customRanking' => ['asc(hex)'] }).should == true
  end

  it 'should not detect settings changes' do
    Color.send(:algoliasearch_settings_changed?, {}, {}).should == false
    Color.send(:algoliasearch_settings_changed?, { 'searchableAttributes' => ['name'] },
               { searchableAttributes: ['name'] }).should == false
    Color.send(:algoliasearch_settings_changed?, { 'searchableAttributes' => ['name'], 'customRanking' => ['asc(hex)'] },
               { 'customRanking' => ['asc(hex)'] }).should == false
  end
end

describe 'Change detection' do
  it 'should detect attribute changes' do
    color = Color.new name: 'dark-blue', short_name: 'blue', hex: 123

    Color.algolia_must_reindex?(color).should == true
    color.save
    Color.algolia_must_reindex?(color).should == false

    color.hex = 123_456
    Color.algolia_must_reindex?(color).should == false

    color.not_indexed = 'strstr'
    Color.algolia_must_reindex?(color).should == false
    color.name = 'red'
    Color.algolia_must_reindex?(color).should == true

    color.delete
  end

  it 'should detect attribute changes even in a transaction' do
    color = Color.new name: 'dark-blue', short_name: 'blue', hex: 123
    color.save

    color.instance_variable_get('@algolia_must_reindex').should.nil?
    Color.transaction do
      color.name = 'red'
      color.save
      color.not_indexed = 'strstr'
      color.save
      color.instance_variable_get('@algolia_must_reindex').should == true
    end
    color.instance_variable_get('@algolia_must_reindex').should.nil?

    color.delete
  end

  it 'should detect change with algolia_dirty? method' do
    ebook = Ebook.new name: 'My life', author: 'Myself', premium: false, released: true

    Ebook.algolia_must_reindex?(ebook).should == true # Because it's defined in algolia_dirty? method
    ebook.current_time = 10
    ebook.published_at = 8
    Ebook.algolia_must_reindex?(ebook).should == true
    ebook.published_at = 12
    Ebook.algolia_must_reindex?(ebook).should == false
  end

  it 'should know if the _changed? method is user-defined',
     skip: Object.const_defined?(:RUBY_VERSION) && RUBY_VERSION.to_f < 1.9 do
    color = Color.new name: 'dark-blue', short_name: 'blue', hex: 123

    expect do
      Color.send(:automatic_changed_method?, color, :something_that_doesnt_exist)
    end.to raise_error(ArgumentError)

    Color.send(:automatic_changed_method?, color, :name_changed?).should == true
    Color.send(:automatic_changed_method?, color, :hex_changed?).should == false

    Color.send(:automatic_changed_method?, color, :will_save_change_to_short_name?).should == false

    if Color.send(:automatic_changed_method_deprecated?)
      Color.send(:automatic_changed_method?, color, :will_save_change_to_name?).should == true
      Color.send(:automatic_changed_method?, color, :will_save_change_to_hex?).should == true
    end
  end
end

describe 'Namespaced::Model' do
  before(:all) do
    Namespaced::Model.clear_index!
  rescue StandardError
    ArgumentError
  end

  it 'should have an index name without :: hierarchy' do
    Namespaced::Model.index_name.end_with?('Namespaced_Model').should == true
  end

  it "should use the block to determine attribute's value" do
    m = Namespaced::Model.new(another_private_value: 2)
    attributes = Namespaced::Model.algoliasearch_settings.get_attributes(m)
    attributes['customAttr'].should == 42
    attributes['myid'].should == m.id
  end

  it 'should always update when there is no custom _changed? function' do
    m = Namespaced::Model.new(another_private_value: 2)
    m.save
    results = Namespaced::Model.search('*', '', { 'filter_by' => 'customAttr:42' })
    expect(results.size).to eq(1)
    expect(results[0].id).to eq(m.id)

    m.another_private_value = 5
    m.save

    results = Namespaced::Model.search('*', '', { 'filter_by' => 'customAttr:42' })
    expect(results.size).to eq(0)

    results = Namespaced::Model.search('*', '', { 'filter_by' => 'customAttr:45' })
    expect(results.size).to eq(1)
    expect(results[0].id).to eq(m.id)
  end
end

describe 'UniqUsers' do
  before(:all) do
    UniqUser.clear_index!
  rescue StandardError
    ArgumentError
  end

  it 'should not use the id field' do
    UniqUser.create name: 'fooBar'
    results = UniqUser.search('foo', 'name')
    expect(results.size).to eq(1)
  end
end

describe 'NestedItem' do
  before(:all) do
    NestedItem.clear_index!
  rescue StandardError
    ArgumentError
  end

  it 'should fetch attributes unscoped' do
    @i1 = NestedItem.create hidden: false
    @i2 = NestedItem.create hidden: true

    @i1.children << NestedItem.create(hidden: true) << NestedItem.create(hidden: true)
    NestedItem.where(id: [@i1.id, @i2.id]).reindex!(AlgoliaSearch::IndexSettings::DEFAULT_BATCH_SIZE) # , true)

    result = NestedItem.retrieve_document(@i1.id)
    result['nb_children'].should == 2

    result = NestedItem.raw_search('', 'id')
    result['found'].should == 1

    if @i2.respond_to? :update_attributes
      @i2.update_attributes hidden: false
    else
      @i2.update hidden: false
    end

    result = NestedItem.raw_search('', 'id')
    result['found'].should == 2
  end
end

describe 'Colors' do
  before(:all) do
    Color.clear_index!
  end

  it 'should detect predefined_fields' do
    color = Color.create name: 'dark-blue', hex: 123
    color.short_name.should.nil?
  end

  it 'should auto index' do
    @blue = Color.create!(name: 'blue', short_name: 'b', hex: 0xFF0000)
    results = Color.search('blue', 'name')
    expect(results.size).to eq(1)
    results.should include(@blue)
  end

  it 'should facet as well' do
    results = Color.search('*', '', { 'facet_by' => 'name' })

    results.raw_answer.should_not be_nil
    results.raw_answer['facet_counts'].should_not be_nil
    results.raw_answer['facet_counts'].size.should eq(1)
    results.raw_answer['facet_counts'][0]['counts'][0]['count'].should eq(1)
  end

  it 'should be raw searchable' do
    results = Color.raw_search('blue', 'name')
    results['hits'].size.should eq(1)
    results['found'].should eq(1)
  end

  it 'should not auto index if scoped' do
    Color.without_auto_index do
      Color.create!(name: 'blue', short_name: 'b', hex: 0xFF0000)
    end
    expect(Color.search('blue', 'name').size).to eq(1)
    Color.reindex!(AlgoliaSearch::IndexSettings::DEFAULT_BATCH_SIZE)
    expect(Color.search('blue', 'name').size).to eq(2)
  end

  it 'should not be searchable with non-indexed fields' do
    @blue = Color.create!(name: 'blue', short_name: 'x', hex: 0xFF0000)
    expect { Color.search('x', 'short_name') }.to raise_error(Typesense::Error)
    # expect(results.size).to eq(0)
  end

  it 'should rank with default_sorting_field hex' do
    @blue = Color.create!(name: 'red', short_name: 'r3', hex: 3)
    @blue2 = Color.create!(name: 'red', short_name: 'r1', hex: 1)
    @blue3 = Color.create!(name: 'red', short_name: 'r2', hex: 2)
    results = Color.search('red', 'name')
    expect(results.size).to eq(3)
    results[0].hex.should eq(3)
    results[1].hex.should eq(2)
    results[2].hex.should eq(1)
  end

  it 'should update the index if the attribute changed' do
    @purple = Color.create!(name: 'purple', short_name: 'p', hex: 123)
    expect(Color.search('purple', 'name').size).to eq(1)
    expect(Color.search('pink', 'name').size).to eq(0)
    @purple.name = 'pink'
    @purple.save
    expect(Color.search('purple', 'name').size).to eq(0)
    expect(Color.search('pink', 'name').size).to eq(1)
  end

  it 'should use the specified scope' do
    Color.clear_index!
    Color.where(name: 'red').reindex!(AlgoliaSearch::IndexSettings::DEFAULT_BATCH_SIZE)
    expect(Color.search('*', '').size).to eq(3)
    Color.clear_index!
    Color.where(id: Color.first.id).reindex!(AlgoliaSearch::IndexSettings::DEFAULT_BATCH_SIZE)
    expect(Color.search('*', '').size).to eq(1)
  end

  it 'should have a Rails env-based index name' do
    Color.index_name.should == safe_index_name('Color') + "_#{Rails.env}"
  end

  it 'should include the _highlightResult and _snippetResults' do
    @green = Color.create!(name: 'green', short_name: 'gre', hex: 0x00FF00)
    results = Color.search('green', 'name', { 'highlight_fields' => ['short_name'] })
    expect(results.size).to eq(1)
    expect(results[0].highlight_result).to_not be_nil
    expect(results[0].snippet_result).to_not be_nil
  end

  it 'should index an array of objects' do
    json = Color.raw_search('*', '')
    Color.index_objects Color.limit(1)
    json['found'].should eq(Color.raw_search('*', '')['found'])
  end

  it 'should not index non-saved object' do
    expect { Color.new(name: 'purple').index!(true) }.to raise_error(ArgumentError)
    expect { Color.new(name: 'purple').remove_from_index!(true) }.to raise_error(ArgumentError)
  end

  it 'should reindex with a temporary index name based on custom index name & per_environment' do
    Color.reindex
  end
end

describe 'An imaginary store' do
  before(:all) do
    begin
      Product.clear_index!
    rescue StandardError
      ArgumentError
    end
    # Google products
    @blackberry = Product.create!(name: 'blackberry', href: 'google')
    @nokia = Product.create!(name: 'nokia', href: 'google')

    # Amazon products
    @android = Product.create!(name: 'android', href: 'amazon')
    @samsung = Product.create!(name: 'samsung', href: 'amazon')
    @motorola = Product.create!(name: 'motorola', href: 'amazon',
                                description: "Not sure about features since I've never owned one.")

    # Ebay products
    @palmpre = Product.create!(name: 'palmpre', href: 'ebay')
    @palm_pixi_plus = Product.create!(name: 'palm pixi plus', href: 'ebay')
    @lg_vortex = Product.create!(name: 'lg vortex', href: 'ebay')
    @t_mobile = Product.create!(name: 't mobile', href: 'ebay')

    # Yahoo products
    @htc = Product.create!(name: 'htc', href: 'yahoo')
    @htc_evo = Product.create!(name: 'htc evo', href: 'yahoo')
    @ericson = Product.create!(name: 'ericson', href: 'yahoo')

    # Apple products
    @iphone = Product.create!(name: 'iphone', href: 'apple',
                              description: 'Puts even more features at your fingertips')

    # Unindexed products
    @sekrit = Product.create!(name: 'super sekrit', href: 'amazon', release_date: Time.now + 1.day)
    @no_href = Product.create!(name: 'super sekrit too; missing href')

    # Subproducts
    @camera = Camera.create!(name: 'canon eos rebel t3', href: 'canon')

    100.times do
      Product.create!(name: 'crapoola', href: 'crappy')
    end

    @products_in_database = Product.all

    Product.reindex(AlgoliaSearch::IndexSettings::DEFAULT_BATCH_SIZE)
    sleep 5
  end

  describe 'pagination' do
    it 'should display total results correctly' do
      results = Product.search('crapoola', 'name', { 'per_page' => AlgoliaSearch::IndexSettings::DEFAULT_BATCH_SIZE })
      results.length.should == Product.where(name: 'crapoola').count
    end
  end

  describe 'basic searching' do
    it 'should find the iphone' do
      results = Product.search('iphone', 'name')
      expect(results.size).to eq(1)
      results.should include(@iphone)
    end

    it 'should search case insensitively' do
      results = Product.search('IPHONE', 'name')
      expect(results.size).to eq(1)
      results.should include(@iphone)
    end

    it 'should find all amazon products' do
      results = Product.search('amazon', 'href')
      expect(results.size).to eq(3)
      results.should include(@android, @samsung, @motorola)
    end

    it 'should find all "palm" phones with wildcard word search' do
      results = Product.search('pal', 'name')

      results.should include(@palmpre, @palm_pixi_plus)
    end

    it 'should search multiple words from the same field' do
      results = Product.search('palm pixi plus', 'name')
      results.should include(@palm_pixi_plus)
    end

    it 'should narrow the results by searching across multiple fields' do
      results = Product.search('apple iphone', 'href,name')
      expect(results.size).to eq(1)
      results.should include(@iphone)
    end

    it 'should not search on non-indexed fields' do
      expect { Product.search('features', 'description') }.to raise_error(Typesense::Error)
    end

    it 'should delete the associated record' do
      @iphone.destroy
      results = Product.search('iphone', 'name')
      expect(results.size).to eq(0)
    end

    it "should not throw an exception if a search result isn't found locally" do
      Product.without_auto_index { @palmpre.destroy }
      expect { Product.search('pal', 'name').to_json }.to_not raise_error
    end

    it 'should return the other results if those are still available locally' do
      Product.without_auto_index { @palmpre.destroy }
      results = Product.search('pal', 'name')
      results.should include(@palm_pixi_plus)
    end

    it 'should not duplicate an already indexed record' do
      expect(Product.search('nokia', 'name').size).to eq(1)
      @nokia.index!
      expect(Product.search('nokia', 'name').size).to eq(1)
      @nokia.index!
      @nokia.index!
      expect(Product.search('nokia', 'name').size).to eq(1)
    end

    it 'should not duplicate while reindexing' do
      n = Product.search('*', '', { 'per_page' => AlgoliaSearch::IndexSettings::DEFAULT_BATCH_SIZE }).length
      Product.reindex!(AlgoliaSearch::IndexSettings::DEFAULT_BATCH_SIZE)
      expect(Product.search('*', '', { 'per_page' => AlgoliaSearch::IndexSettings::DEFAULT_BATCH_SIZE }).size).to eq(n)
      Product.reindex!(AlgoliaSearch::IndexSettings::DEFAULT_BATCH_SIZE)
      Product.reindex!(AlgoliaSearch::IndexSettings::DEFAULT_BATCH_SIZE)
      expect(Product.search('*', '', { 'per_page' => AlgoliaSearch::IndexSettings::DEFAULT_BATCH_SIZE }).size).to eq(n)
    end

    it 'should not return products that are not indexable' do
      @sekrit.index!
      @no_href.index!
      results = Product.search('sekrit', 'name')
      expect(results.size).to eq(0)
    end

    it 'should include items belong to subclasses' do
      @camera.index!
      results = Product.search('eos rebel', 'name')
      results.should include(@camera)
    end

    it 'should delete a not-anymore-indexable product' do
      results = Product.search('sekrit', 'name')
      expect(results.size).to eq(0)

      @sekrit.release_date = Time.now - 1.day
      @sekrit.save!
      @sekrit.index!
      results = Product.search('sekrit', 'name')
      expect(results.size).to eq(1)

      @sekrit.release_date = Time.now + 1.day
      @sekrit.save!
      @sekrit.index!
      results = Product.search('sekrit', 'name')
      expect(results.size).to eq(0)
    end

    it 'should delete not-anymore-indexable product while reindexing' do
      n = Product.search('*', '', { 'per_page' => AlgoliaSearch::IndexSettings::DEFAULT_BATCH_SIZE }).size
      Product.where(release_date: nil).first.update_attribute :release_date, Time.now + 1.day
      Product.reindex!(AlgoliaSearch::IndexSettings::DEFAULT_BATCH_SIZE)
      expect(Product.search('*', '',
                            { 'per_page' => AlgoliaSearch::IndexSettings::DEFAULT_BATCH_SIZE }).size).to eq(n - 1)
    end

    it 'should find using multi-way synonyms' do
      expect(Product.search('galaxy', 'name').size).to eq(Product.search('samsung', 'name').size)
    end

    it 'should find using one-way synonyms' do
      expect(Product.search('smartphone', 'name').size).to eq(4)
    end
  end
end

describe 'Cities' do
  before(:all) do
    City.clear_index!
  rescue StandardError
    ArgumentError
  end

  it 'should index geo' do
    sf = City.create name: 'San Francisco', country: 'USA', lat: 37.75, lng: -122.68
    mv = City.create name: 'Mountain View', country: 'No man\'s land', lat: 37.38, lng: -122.08
    sf_and_mv = City.create name: 'San Francisco & Mountain View', country: 'Hybrid', gl_array: [37.75, -122.08] # [{ :lat => 37.75, :lng => -122.68 }, { :lat => 37.38, :lng => -122.08 }]
    results = City.search('*', '', { 'filter_by' => 'location:(37.33, -121.89,50 km)' })
    expect(results.size).to eq(2)
    results.should include(mv, sf_and_mv)

    results = City.search('*', '', { 'filter_by' => 'location:(37.33, -121.89, 500 km)' })
    expect(results.size).to eq(3)
    results.should include(mv)
    results.should include(sf)
    results.should include(sf_and_mv)
  end
end

describe 'MongoObject' do
  it 'should not have method conflicts' do
    expect { MongoObject.reindex! }.to raise_error(NameError)
    expect { MongoObject.new.index! }.to raise_error(NameError)
    MongoObject.algolia_reindex!
    MongoObject.create(name: 'mongo').algolia_index!
  end
end

describe 'Book' do
  before(:all) do
    Book.clear_index!
  rescue StandardError
    ArgumentError
  end

  it 'should sanitize attributes' do
    @hack = Book.create! name: '"><img src=x onerror=alert(1)> hack0r',
                         author: '<script type="text/javascript">alert(1)</script>', premium: true, released: true
    b = Book.raw_search('hack', 'name')
    expect(b['hits'].length).to eq(1)
    begin
      expect(b['hits'][0]['document']['name']).to eq('"> hack0r')
      expect(b['hits'][0]['document']['author']).to eq('alert(1)')
      expect(b['hits'][0]['highlights'][0]['snippet']).to eq('"> <mark>hack0r</mark>')
    rescue StandardError
      # rails 4.2's sanitizer
      begin
        expect(b['hits'][0]['document']['name']).to eq('&quot;&gt; hack0r')
        expect(b['hits'][0]['document']['author']).to eq('')
        expect(b['hits'][0]['highlights'][0]['snippet']).to eq('&quot;&gt; <mark>hack0r</mark>')
      rescue StandardError
        # jruby
        expect(b['hits'][0]['document']['name']).to eq('"&gt; hack0r')
        expect(b['hits'][0]['document']['author']).to eq('')
        expect(b['hits'][0]['highlights'][0]['snippet']).to eq('"&gt; <mark>hack0r</mark>')
      end
    end
  end
end

describe 'Kaminari' do
  before(:all) do
    require 'kaminari'
    AlgoliaSearch.configuration = {
      nodes: [{
        host: 'localhost',   # For Typesense Cloud use xxx.a1.typesense.net
        port: 8108,          # For Typesense Cloud use 443
        protocol: 'http' # For Typesense Cloud use https
      }],
      api_key: 'xyz',
      connection_timeout_seconds: 2,
      pagination_backend: :kaminari
    }
  end

  it 'should paginate' do
    pagination = City.search('*', '')
    pagination.total_count.should eq(City.raw_search('*', '')['found'])

    p1 = City.search('*', '', { 'page' => 1, 'per_page' => 1 })

    p1.size.should eq(1)
    p1[0].should eq(pagination[0])
    p1.total_count.should eq(City.raw_search('*', '')['found'])

    p2 = City.search('*', '', { 'page' => 2, 'per_page' => 1 })

    p2.size.should eq(1)
    p2[0].should eq(pagination[1])
    p2.total_count.should eq(City.raw_search('*', '')['found'])
  end
end

describe 'Will_paginate' do
  before(:all) do
    require 'will_paginate'
    AlgoliaSearch.configuration = {
      nodes: [{
        host: 'localhost',   # For Typesense Cloud use xxx.a1.typesense.net
        port: 8108,          # For Typesense Cloud use 443
        protocol: 'http'         # For Typesense Cloud use https
      }],
      api_key: 'xyz',
      connection_timeout_seconds: 2,
      pagination_backend: :will_paginate
    }
  end

  it 'should paginate' do
    p1 = City.search('*', '', { 'per_page' => 2 })

    p1.length.should eq(2)
    p1.per_page.should eq(2)
    p1.total_entries.should eq(City.raw_search('*', '')['found'])
  end
end

describe 'Disabled' do
  before(:all) do
    begin
      DisabledBoolean.clear_index!
    rescue StandardError
      ArgumentError
    end
    begin
      DisabledProc.clear_index!
    rescue StandardError
      ArgumentError
    end
    begin
      DisabledSymbol.clear_index!
    rescue StandardError
      ArgumentError
    end
  end

  it 'should disable the indexing using a boolean' do
    DisabledBoolean.create name: 'foo'
    expect(DisabledBoolean.search('*', '').size).to eq(0)
  end

  it 'should disable the indexing using a proc' do
    DisabledProc.create name: 'foo'
    expect(DisabledProc.search('*', '').size).to eq(0)
  end

  it 'should disable the indexing using a symbol' do
    DisabledSymbol.create name: 'foo'
    expect(DisabledSymbol.search('*', '').size).to eq(0)
  end
end

describe 'NullableId' do
  before(:all) do
  end

  it 'should not delete a null objectID' do
    NullableId.create!
  end
end

describe 'EnqueuedObject' do
  it 'should enqueue a job' do
    expect do
      EnqueuedObject.create! name: 'test'
    end.to raise_error('enqueued 1')
  end

  it 'should not enqueue a job inside no index block' do
    expect do
      EnqueuedObject.without_auto_index do
        EnqueuedObject.create! name: 'test'
      end
    end.not_to raise_error
  end
end

describe 'DisabledEnqueuedObject' do
  it 'should not try to enqueue a job' do
    expect do
      DisabledEnqueuedObject.create! name: 'test'
    end.not_to raise_error
  end
end

describe 'Misconfigured Block' do
  it 'should force the algoliasearch block' do
    expect do
      MisconfiguredBlock.reindex
    end.to raise_error(ArgumentError)
  end
end
