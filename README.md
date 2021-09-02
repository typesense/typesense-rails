<p align="center">
  <!-- <a href="https://www.algolia.com">
    <img alt="Algolia for Rails" src="https://raw.githubusercontent.com/algolia/typesense-client-common/master/banners/rails.png" >
  </a> -->

  <h4 align="center">The ideal place to begin integrating <a href="https://typesense.org" target="_blank">Typesense</a> within your Rails project!</h4>

  <p align="center">
    <!-- <a href="https://circleci.com/gh/algolia/typesense-rails"><img src="https://circleci.com/gh/algolia/typesense-rails.svg?style=shield" alt="CircleCI" /></a>
    <a href="http://badge.fury.io/rb/typesense-rails"><img src="https://badge.fury.io/rb/typesense-rails.svg" alt="Gem Version"></img></a>
    <a href="https://codeclimate.com/github/algolia/typesense-rails"><img src="https://codeclimate.com/github/algolia/typesense-rails.svg" alt="Code Climate"></img></a> -->
    <img src="https://img.shields.io/badge/ActiveRecord-yes-blue.svg?style=flat-square" alt="ActiveRecord"></img>
    <img src="https://img.shields.io/badge/Mongoid-yes-blue.svg?style=flat-square" alt="Mongoid"></img>
    <img src="https://img.shields.io/badge/Sequel-yes-blue.svg?style=flat-square" alt="Sequel"></img>
  </p>
</p>

<!-- <p align="center">
  <a href="https://www.algolia.com/doc/framework-integration/rails/getting-started/setup/?language=ruby" target="_blank">Documentation</a>  •
  <a href="https://discourse.algolia.com" target="_blank">Community Forum</a>  •
  <a href="http://stackoverflow.com/questions/tagged/algolia" target="_blank">Stack Overflow</a>  •
  <a href="https://github.com/algolia/typesense-rails/issues" target="_blank">Report a bug</a>  •
  <a href="https://www.algolia.com/doc/framework-integration/rails/troubleshooting/faq/" target="_blank">FAQ</a>  •
  <a href="https://www.algolia.com/support" target="_blank">Support</a>
</p> -->

<!--You might be interested in the sample Ruby on Rails application providing a `autocomplete.js`-based auto-completion and `InstantSearch.js`-based instant search results page: [typesense-rails-example](https://github.com/algolia/typesense-rails-example/). -->

This gem makes it simple to link the Typesense API with your preferred ORM. It uses the [typesense-ruby](https://github.com/typesense/typesense-ruby) gem as a foundation. All versions of Rails 3.x, 4.x, and 5.x are supported.

## API Documentation

<!-- You can find the full reference on [Algolia's website](https://www.algolia.com/doc/framework-integration/rails/). -->

1. **[Setup](#setup)**

   - [Install](#install)
   - [Configuration](#configuration)
   - [Notes](#notes)

1. **[Usage](#usage)**

   - [Index Schema](#index-schema)
   - [Indexing](#indexing)
   - [Frontend Search (realtime experience)](#frontend-search-realtime-experience)
   - [Backend Search](#backend-search)
   - [Faceting](#faceting)
   - [Geo-Search](#geo-search)

1. **[Options](#options)**

   - [Auto-indexing &amp; asynchronism](#auto-indexing--asynchronism)
   - [Custom index name](#custom-index-name)
   - [Per-environment indices](#per-environment-indices)
   - [Custom attribute definition](#custom-attribute-definition)
   - [Nested objects/relations](#nested-objectsrelations)
   - [Custom <code>objectID</code>](#custom-objectid)
   - [Restrict indexing to a subset of your data](#restrict-indexing-to-a-subset-of-your-data)
   - [Sanitizer](#sanitizer)
   - [UTF-8 Encoding](#utf-8-encoding)

1. **[Indices](#indices)**

   - [Manual indexing](#manual-indexing)
   - [Manual removal](#manual-removal)
   - [Reindexing](#reindexing)
   - [Clearing an index](#clearing-an-index)
   - [Using the underlying index](#using-the-underlying-index)
   - [Share a single index](#share-a-single-index)

1. **[Testing](#testing)**

   - [Notes](#notes)

---

# Setup

## Install

1.

```sh
gem install typesense-rails
```

2.

Add the gem to your <code>Gemfile</code>:

```ruby
gem "typesense-rails"
```

3.

```sh
bundle install
```

Or simply run:

```sh
bundle add typesense-rails
```

## Configuration

Create a new file <code>config/initializers/typesense.rb</code> to configure your API key.

```ruby
Typesense.configuration = {
  nodes: [{
    host: 'localhost',   # For Typesense Cloud use xxx.a1.typesense.net
    port: 8108,          # For Typesense Cloud use 443
    protocol: 'http'     # For Typesense Cloud use https
  }],
  api_key: '<API_KEY>',
  connection_timeout_seconds: 2
}
```

The gem is compatible with [ActiveRecord](https://github.com/rails/rails/tree/master/activerecord), [Mongoid](https://github.com/mongoid/mongoid) and [Sequel](https://github.com/jeremyevans/sequel).

## Notes

To initiate the indexing operations, this gem extensively uses Rails callbacks. It will not index your modifications if you use methods that bypass the `after_validation`, `before_save`, or `after_commit` callbacks. `update_attribute`, for example, does not do validation checks. Instead, `update_attributes` is used to perform validations when updating.

All methods injected by the `Typesense` module are prefixed with `typesense_`. If the associated short names aren't already defined,the methods are aliased to them.

```ruby
Episode.typesense_reindex! # <=> Episode.reindex!

Episode.typesense_search("jesse","summary") # <=> Episode.search("jesse","summary")
```

---

# Usage

## Index Schema

The following code will provide search capabilities to your model and generate a collection:

```ruby
class Episode < ApplicationRecord
  belongs_to :show

  include Typesense

  typesense  do
    # all attributes will be indexed
  end
end
```

You may either define the attributes for your collection (here we limited to :name, :summary) or you can leave them blank (in that case, all attributes are indexed).

```ruby
class Episode < ApplicationRecord
  belongs_to :show

  include Typesense

  typesense  do
    attributes :name, :summary
  end
end
```

You may also use the <code>add_attribute</code> method to transmit all model attributes as well as any additional attributes:

```ruby
class Episode < ApplicationRecord
  belongs_to :show

  include Typesense

  typesense  do
    # all attributes + extra_attr will be sent
    add_attribute :extra_attr
  end

  def extra_attr
    "extra_val"
  end
end
```

To configure your collection schema with field arguments defined [here](https://typesense.org/docs/0.21.0/api/collections.html#create-a-collection), you can do:

```ruby
class Episode < ApplicationRecord
  belongs_to :show
  include Typesense

  typesense  do
    predefined_fields [
      { name: 'name', type: 'string' },
      { name: 'summary', type: 'string' },
      {name: 'number',type: 'int32'}
    ]
    default_sorting_field 'number'
  end
end
```

Be sure to use `reindex` to update your collection schema.

## Indexing

Simply call reindex on the class to index a model:

```ruby
Episode.reindex  # => Creates a new collection everytime
Episode.reindex! # => Upserts all documents without removing deleted objects
```

You can do something like this to reindex all your models:

```ruby
Rails.application.eager_load! # Ensure all models are loaded (required in development).

typesense_models = ActiveRecord::Base.descendants.select{ |model| model.respond_to?(:reindex) }

typesense_models.each(&:reindex)
```

## Frontend Search (realtime experience)

Backend search logic and functionality are common in traditional search systems. When the search experience consisted of a user inputting a search query, running the search, and then being sent to a search result page, this made sense.

It is no longer necessary to implement search on the backend. In fact, due to the additional network and processor latency, it is usually detrimental to performance. All search requests can be sent directly from the end user's browser, mobile device, or client using our [JavaScript API Client](https://github.com/typesense/typesense-js). It will lower overall search latency while simultaneously offloading your servers.

You can use the [InstantSearch.js](https://github.com/algolia/instantsearch.js) library and our [Typesense-InstantSearch-Adapter](https://github.com/typesense/typesense-instantsearch-adapter) to build a realtime search experience with amazing UI in just a few lines of code.

<!-- The JS API client is part of the gem, just require `algolia/v3/typesense.min` somewhere in your JavaScript manifest, for example in `application.js` if you are using Rails 3.1+:

```javascript
//= require algolia/v3/typesense.min
```

Then in your JavaScript code you can do:

```js
var client = typesense(ApplicationID, Search - Only - API - Key);
var index = client.initIndex("YourIndexName");
index
  .search("something", { hitsPerPage: 10, page: 0 })
  .then(function searchDone(content) {
    console.log(content);
  })
  .catch(function searchFailure(err) {
    console.error(err);
  });
```

**We recently (March 2015) released a new version (V3) of our JavaScript client, if you were using our previous version (V2), [read the migration guide](https://github.com/algolia/typesense-client-javascript/wiki/Migration-guide-from-2.x.x-to-3.x.x)** -->

## Backend Search

<!-- **_Notes:_** We recommend the usage of our [JavaScript API Client](https://github.com/algolia/typesense-client-javascript) to perform queries directly from the end-user browser without going through your server. -->

We highly recommend the usage of our [JavaScript API Client](https://github.com/typesense/typesense-client-javascript) to perform queries to decrease the overall latency and offload your servers.

A search retrieves ORM-compliant objects from your database and reloads them.

```ruby
hits =  Episode.search("jesse","summary")
```

To each ORM object,a `highlight_result` attribute is added. This attribute contains the matched token and snippet for the search result.

```ruby
hits[0].highlight_result
```

Use the following method to get the raw JSON response from the API without having to reload the objects from the database:

```ruby
json_answer = Episode.raw_search("jesse","summary")
```

All [search parameters](https://typesense.org/docs/0.21.0/api/documents.html#search) are specified dynamically at search time by passing it as a hash to the `search` method.

```ruby
Episode.raw_search("jesse","summary",{"sort_by"=>"number:asc"})
```

<!-- ## Backend Pagination

This gem supports both [will_paginate](https://github.com/mislav/will_paginate) and [kaminari](https://github.com/amatsuda/kaminari) as pagination backend.

To use <code>:will_paginate</code>, specify the <code>:pagination_backend</code> as follow:

```ruby
Typesense.configuration = { application_id: 'YourApplicationID', api_key: 'YourAPIKey', pagination_backend: :will_paginate }
```

Then, as soon as you use the `search` method, the returning results will be a paginated set:

```ruby
# in your controller
@results = MyModel.search('foo', hitsPerPage: 10)

# in your views
# if using will_paginate
<%= will_paginate @results %>

# if using kaminari
<%= paginate @results %>
``` -->

## Faceting

You would need to specify the attributes to facet in your model. `facets` method of the search answer would give the `facet_counts` field.

```ruby
class Episode < ApplicationRecord
  belongs_to :show
  include Typesense
  typesense , per_page: 10 do
    predefined_fields [
      { 'name' => 'name', 'type' => 'string' },
      { 'name' => 'show_id', 'type' => 'int32', 'facet' => true },
      { 'name' => 'summary', 'type' => 'string' }
    ]
  end
end
```

```ruby
hits = Episode.search("jesse","summary",{facet_by: 'show_id'})
p hits                    # ORM-compliant array of objects
p hits.facets             # extra method added to retrieve facets
```

## Geo-Search

With Typesense v0.21.0, you can now perform [geo-search](https://typesense.org/docs/0.21.0/api/documents.html#geosearch) queries. You will need to specify the attribute with a 'geopoint' datatype like below.

```ruby
class City < ActiveRecord::Base
  include Typesense

  typesense  do
    predefined_fields [{ 'name' => 'location', 'type' => 'geopoint' }]
  end
end
```

```ruby
 sf = City.create name: 'San Francisco', country: 'USA', lat: 37.75, lng: -122.68
 mv = City.create name: 'Mountain View', country: 'No man\'s land', lat: 37.38, lng: -122.08
 results = City.search('*', '', { 'filter_by' => 'location:(37.33, -121.89,50 km)' })
```

---

# Options

## Auto-indexing

Every time a record is saved, it will be indexed asynchronously. When a record is destroyed, on the other hand, it is asynchronously deleted from the index. That is, a network request containing the ADD/DELETE operation is submitted synchronously to the Typesense server, but the engine processes the operation asynchronously (thus the results may not reflect it if you run a search right after). Set the following options to disable auto-indexing and auto-removing.

```ruby
class Episode < ActiveRecord::Base
  include Typesense

  typesense auto_index: false, auto_remove: false do
  end
end
```

### Temporary disable auto-indexing

For performance reasons, you can also temporarily disable auto-indexing using the `without_auto_index` scope.

```ruby
Episode.delete_all
Episode.without_auto_index do
  1.upto(10000) { Episode.create! attributes } # inside this block, auto indexing task will not run.
end
Episode.reindex! # will use batch operations
```

### Queues & background jobs

You can set up the auto-indexing and auto-removal processes to run in the background using a queue. Queues from ActiveJob (Rails >=4.2) are used by default, however you can define your own:

```ruby
class Episode < ActiveRecord::Base
  include Typesense

  typesense enqueue: true do # ActiveJob will be triggered using a `typesense` queue
  end
end
```

### Things to Consider

A record deletion can be committed to your database prior to the job actually executing if you are doing updates and deletions in the background. As a result, if you load the record to delete it from the database, your ActiveRecord#find will return a RecordNotFound error.

In this scenario, you can simply communicate with the index instead of loading the record from ActiveRecord:

```ruby
class MySidekiqWorker
  def perform(id, remove)
    if remove
      # the record has likely already been removed from your database so we cannot
      # use ActiveRecord#find to load it
      Episode.remove_from_index!
    else
      # the record should be present
      c = Episode.find(id)
      c.index!
    end
  end
end
```

### With Sidekiq

If you're using [Sidekiq](https://github.com/mperham/sidekiq):

```ruby
class Episode < ActiveRecord::Base
  include Typesense

  typesense enqueue: :trigger_sidekiq_worker do
  end

  def self.trigger_sidekiq_worker(record, remove)
    MySidekiqWorker.perform_async(record.id, remove)
  end
end

class MySidekiqWorker
  def perform(id, remove)
    if remove
      # the record has likely already been removed from your database so we cannot
      # use ActiveRecord#find to load it
      Episode.remove_from_index!
    else
      # the record should be present
      c = Episode.find(id)
      c.index!
    end
  end
end
```

### With DelayedJob

If you're using [delayed_job](https://github.com/collectiveidea/delayed_job):

```ruby
class Episode < ActiveRecord::Base
  include Typesense

  typesense enqueue: :trigger_delayed_job do
  end

  def self.trigger_delayed_job(record, remove)
    if remove
      record.delay.remove_from_index!
    else
      record.delay.index!
    end
  end
end

```

<!-- ### Synchronism & testing

You can force indexing and removing to be synchronous (in that case the gem will call the `wait_task` method to ensure the operation has been taken into account once the method returns) by setting the following option: (this is **NOT** recommended, except for testing purpose)

```ruby
class Episode < ActiveRecord::Base
  include Typesense

  typesense synchronous: true do
    attribute :first_name, :last_name, :email
  end
end
``` -->

## Custom index name

The index name is set to the class name by default, e.g. "Episode." Using the index name option, you can change the name of the index:

```ruby
class Episode < ActiveRecord::Base
  include Typesense

  typesense index_name: "MyCustomName" do
  end
end
```

## Per-environment indices

You can use the following option to suffix the index name with the current Rails environment:

```ruby
class Episode < ActiveRecord::Base
  include Typesense

  typesense per_environment: true do # index name will be "Episode_#{Rails.env}"
  end
end
```

## Custom attribute definition

You can use a block to specify a complex attribute value or use `add_attribute` to add a custom attribute:

```ruby
class Episode < ActiveRecord::Base
  include Typesense

  typesense do
    attribute :with_numbers do
      "S#{season}-E#{number} #{name}"
    end
  end

end
```

```ruby
class Episode < ActiveRecord::Base
  include Typesense

  typesense do
    add_attribute :with_numbers
  end

  def with_numbers
    "S#{season}-E#{number} #{name}"
  end
end
```

**_Notes:_** When you use this code to define extra attributes, the gem will no longer be able to detect if the attribute has changed (the code detects this using Rails'`#{attribute}_changed?` function). As a result, even if your record's attributes haven't changed, it will be pushed to the API. Using the `_changed?` method, you can get around this behaviour:

```ruby
class Episode < ActiveRecord::Base
  include Typesense

  typesense do
    attribute :with_numbers do
      "S#{season}-E#{number} #{name}"
    end
  end

  def with_numbers_changed?
    season_changed? || number_changed? || name_changed?
  end
end
```

## Nested objects/relations

### Defining the relationship

By providing an extra attribute that returns any JSON-compliant object, you may easily embed nested objects (an array or a hash or a combination of both).

```ruby
class Profile < ActiveRecord::Base
  include Typesense

  belongs_to :user
  has_many :specializations

  typesense do
    attribute :user do
      # restrict the nested "user" object to its `name` + `email`
      { name: user.name, email: user.email }
    end
    attribute :public_specializations do
      # build an array of public specialization (include only `title` and `another_attr`)
      specializations.select { |s| s.public? }.map do |s|
        { title: s.title, another_attr: s.another_attr }
      end
    end
  end

end
```

### Propagating the change from a nested child

#### With ActiveRecord

With ActiveRecord, we'll be using `touch` and `after_touch` to achieve this.

```ruby
# app/models/app.rb
class App < ApplicationRecord
  include Typesense

  belongs_to :author, class_name: :User
  after_touch :index!

  typesense do
    attribute :title
    attribute :author do
      author.as_json
    end
  end
end

# app/models/user.rb
class User < ApplicationRecord
  # If your association uses belongs_to
  # - use `touch: true`
  # - do not define an `after_save` hook
  has_many :apps, foreign_key: :author_id

  after_save { apps.each(&:touch) }
end
```

#### With Sequel

With Sequel, you can use the `touch` plugin to propagate the changes:

```ruby
# app/models/app.rb
class App < Sequel::Model
  include Typesense

  many_to_one :author, class: :User

  plugin :timestamps
  plugin :touch

  typesense do
    attribute :title
    attribute :author do
      author.to_hash
    end
  end
end

# app/models/user.rb
class User < Sequel::Model
  one_to_many :apps, key: :author_id

  plugin :timestamps
  # Can't use the associations since it won't trigger the after_save
  plugin :touch

  # Define the associations that need to be touched here
  # Less performant, but allows for the after_save hook to trigger
  def touch_associations
    apps.map(&:touch)
  end

  def touch
    super
    touch_associations
  end
end
```

## Custom `objectID`

By default, the `objectID` is based on your record's `id`. You can change this behavior specifying the `:id` option (be sure to use a uniq field).

```ruby
class Episode < ApplicationRecord
  include Typesense

  typesense per_environment: true ,id: :name do
  end
end
```

## Restrict indexing to a subset of your data

You can use the `:if` and `:unless` options to provide restrictions that regulate whether or not a record must be indexed.

You can do conditional indexing on a per-document basis with it.

```ruby
class Product < ActiveRecord::Base
  include Typesense

  typesense if: :published?, unless: ->(o) { o.href.blank? } do
    attribute :href, :name
  end

  def published?
    release_date.blank? || release_date <= Time.now
  end
end
```

**Notes:** When you apply those constraints, addObjects and deleteObjects calls will be made to maintain the index in sync with the database (the state-less gem has no way of knowing if the object no longer matches your constraints or has never matched, thus we force ADD/DELETE actions to be sent). Using the \_changed? method, you can get around this behaviour:

```ruby
class Product < ActiveRecord::Base
  include Typesense

  typesense if: :published?, unless: ->(o) { o.href.blank? } do
    attribute :href, :name
  end

  def published?
    release_date.blank? || release_date <= Time.now
  end

  def published_changed?
    # return true only if you know that the 'published' state changed
  end
end
```

You can index a subset of your records using either:

```ruby
# will generate batch API calls (recommended)
MyModel.where('updated_at > ?', 10.minutes.ago).reindex!
```

or

```ruby
MyModel.index_objects MyModel.limit(5)
```

## Sanitizer

Using the sanitise option, you can sanitise all of your attributes. All HTML tags will be stripped from your attributes.

```ruby
class User < ActiveRecord::Base
  include Typesense

  typesense , sanitize: true do
    attributes :name, :email, :company
  end
end

```

If you're using Rails 4.2+, you also need to depend on `rails-html-sanitizer`:

```ruby
gem 'rails-html-sanitizer'
```

## UTF-8 Encoding

You can force the UTF-8 encoding of all your attributes using the `force_utf8_encoding` option:

```ruby
class Episode < ApplicationRecord
  include Typesense

  typesense force_utf8_encoding: true do
  end
end

```

**_Notes:_** This option is not compatible with Ruby 1.8

<!-- ## Exceptions

You can disable exceptions that could be raised while trying to reach Algolia's API by using the `raise_on_failure` option:

```ruby
class Episode < ActiveRecord::Base
  include Typesense

  # only raise exceptions in development env
  typesense raise_on_failure: Rails.env.development? do
    attribute :first_name, :last_name, :email
  end
end
``` -->

---

# Settings

## Synonyms

In addition to the `predefined_fields` and `default_sorting_field` settings, you can also use the following settings to define [synonyms](https://typesense.org/docs/0.21.0/api/synonyms.html#create-or-update-a-synonym) for your attributes.

```ruby
class Product < ActiveRecord::Base
  include Typesense

  typesense do

    multi_way_synonyms [
      { 'phone-synonym' => %w[galaxy samsung samsung_electronics] }
    ]

    one_way_synonyms [
      { 'smart-phone-synonym' => { 'root' => 'smartphone',
                                   'synonyms' => %w[nokia samsung motorola android] } }
    ]
  end
end

# Product.search('galaxy', 'name') would be equivalent to Product.search('samsung', 'name') in case of multi-way synonyms.
# Product.search('smartphone', 'name') would include all hits for the synonyms defined in case of one-way synonyms.
```

---

# Indices

## Manual indexing

You can trigger indexing using the <code>index!</code> instance method.

```ruby
c = Episode.create!(params[:Episode])
c.index!
```

## Manual removal

And trigger index removing using the <code>remove_from_index!</code> instance method.

```ruby
c.remove_from_index!
c.destroy
```

## Reindexing

There are 2 ways to reindex all your objects:

### Atomical reindexing

To reindex all your records (taking into account the deleted objects), the `reindex` class method creates a new collection and points the alias to that. This is the safest way to reindex all your content.

```ruby
Episode.reindex
```

**Warning:** You should not use such an atomic reindexing operation while scoping/filtering the model because this operation **replaces the entire index**, keeping the filtered objects only. ie: Don't do `MyModel.where(...).reindex` but do `MyModel.where(...).reindex!` (with the trailing `!`)!

### Regular reindexing

Use the reindex! class method to reindex all of your items in place (without destroying removed objects).

```ruby
Episode.reindex!
```

## Clearing an index

To clear an index, use the <code>clear_index!</code> class method:

```ruby
Episode.clear_index!
```

## Using the underlying index

You can access the underlying `index` object which is basically a hash of the collection name and its alias name by calling the `index` class method:

```ruby
index = Episode.index
#{:collection_name=>"Episode_1630520536", :alias_name=>"Episode"}
```

## Share a single index

It is possible to share an index among several models. To do so, make sure you don't have any conflicts with the underlying models' object ids.

```ruby
class Student < ActiveRecord::Base
  attr_protected

  include Typesense

  typesense index_name: 'people', id: :typesense_id do
    # [...]
  end

  private
  def typesense_id
    "student_#{id}" # ensure the teacher & student IDs are not conflicting
  end
end

class Teacher < ActiveRecord::Base
  attr_protected

  include Typesense

  typesense index_name: 'people', id: :typesense_id do
    # [...]
  end

  private
  def typesense_id
    "teacher_#{id}" # ensure the teacher & student IDs are not conflicting
  end
end
```

**_Notes:_** If you want to reindex a single index from many models, you must use `MyModel.reindex!`instead of `MyModel.reindex`. The reindex method will delete the collection and the final collection will only contain entries for the current model, as it will not reindex the others.

---

# Testing

## Notes

You may want to disable all indexing (add, update & delete operations) API calls, you can set the `disable_indexing` option:

```ruby
class User < ActiveRecord::Base
  include Typesense

  typesense , disable_indexing: Rails.env.test? do
  end
end

class User < ActiveRecord::Base
  include Typesense

  typesense , disable_indexing: Proc.new { Rails.env.test? || more_complex_condition } do
  end
end
```

<!-- ## ❓ Troubleshooting

Encountering an issue? Before reaching out to support, we recommend heading to our [FAQ](https://www.algolia.com/doc/api-client/troubleshooting/faq/ruby/) where you will find answers for the most common issues and gotchas with the client.

## Use the Dockerfile

If you want to contribute to this project without installing all its dependencies, you can use our Docker image. Please check our [dedicated guide](DOCKER_README.MD) to learn more. -->
