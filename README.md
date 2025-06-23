# typesense-rails

A Ruby on Rails integration for Typesense search engine that provides seamless integration with ActiveRecord, Sequel and Mongoid models. 

This gem is a fork of the [algolia-rails](https://github.com/algolia/algoliasearch-rails) gem, adapted to work with Typesense while maintaining similar functionality and API patterns.
The core integration patterns and much of the functionality were inspired by Algolia's excellent work. 
Special thanks to the Algolia team for their original implementation, which provided a solid foundation for this Typesense integration.

## Features

- Seamless integration with ActiveRecord, Sequel, and Mongoid models
- Automatic indexing of model data with callbacks
- Support for multiple pagination backends (Kaminari, WillPaginate, Pagy)
- Rich attribute customization and serialization
- Support for nested relationships and hierarchical data
- Background job processing via ActiveJob integration
- Conditional indexing based on model state
- Environment-specific indexing
- Support for faceted search and filtering
- Customizable schema with predefined fields
- Multi-way and one-way synonyms support
- Rake tasks for index management

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'typesense-rails', '~> 1.0.0.rc1'
```

Then execute:

```bash
$ bundle install
```

## Configuration

Initialize Typesense in your Rails application (e.g., in `config/initializers/typesense.rb`):

```ruby
Typesense.configuration = {
  nodes: [{
    host: 'localhost',     # For Typesense Cloud use xxx.a1.typesense.net
    port: '8108',         # For Typesense Cloud use 443
    protocol: 'http'     # For Typesense Cloud use https
  }],
  api_key: 'your-api-key',
  connection_timeout_seconds: 2
}
```

## Usage

### Basic Model Configuration

```ruby
class Product < ApplicationRecord
  include Typesense
  
  typesense do
    # Define attributes to be indexed
    attributes :name, :description, :price
    
    # Add dynamic attributes
    attribute :full_name do
      "#{first_name} #{last_name}"
    end
    
    # Define predefined fields with specific types
    predefined_fields [
      { 'name' => 'name', 'type' => 'string', 'facet' => true },
      { 'name' => 'price', 'type' => 'float' }
    ]
    
    # Set default sorting
    default_sorting_field 'price'
    
    # Configure synonyms
    multi_way_synonyms [
      { "phone-synonym" => %w[galaxy samsung samsung_electronics] }
    ]
    
    one_way_synonyms [
      { "smart-phone-synonym" => {
          "root" => "smartphone",
          "synonyms" => %w[nokia samsung motorola android]
        }
      }
    ]

    # Symbols to index
    symbols_to_index ["-", "_"]

    # Token separators
    token_separator ["-", "_"]

    # Enable nested fields
    enable_nested_fields true
  end
end
```

### Working with Relationships

```ruby
class Profile < ApplicationRecord
  include Typesense
  belongs_to :user
  has_many :specializations
  
  typesense do
    # Nest user data
    attribute :user do
      { name: user.name, email: user.email }
    end
    
    # Include related data
    attribute :specializations do
      specializations.select(&:public?).map do |s|
        { title: s.title, category: s.category }
      end
    end
  end
end
```

### Working with ActionText

ActionText `has_rich_text` defines an association to the ActionText::RichText model. Use `to_plain_text` on this association to get a plain text version for indexing with Typesense.

```ruby
class Product < ApplicationRecord
  include Typesense

  has_rich_text :description

  typesense do
    attribute :description do
      description.to_plain_text
    end
  end
end
```

### Searching

```ruby
# Basic search of "phone" against name and description attributes
results = Product.search('phone', 'name,description')

# Search with filters and sorting
results = Product.search('phone', 'name', {
  filter_by: 'price:< 500',
  sort_by: 'price:asc'
})

# Faceted search
results = Product.search('*', '', {
  facet_by: 'category',
  per_page: 20
})
```

### Indexing

```ruby
# Reindex all records (with zero-downtime)
Product.reindex

# Regular reindexing (overwrites existing records)
Product.reindex!

# Index specific records
Product.where('updated_at > ?', 10.minutes.ago).reindex!

# Index a single record
product.index!

# Remove from index
product.remove_from_index!

# Conditional indexing
typesense if: :published?, unless: :draft? do
  # indexing configuration
end
```

### Background Jobs

Process indexing operations asynchronously using ActiveJob:

```ruby
class Product < ApplicationRecord
  include Typesense
  
  typesense enqueue: true do
    attributes :name, :description, :price
  end
end
```

Or define custom job processing:

```ruby
class Product < ApplicationRecord
  include Typesense
  
  typesense enqueue: :trigger_worker do
    attributes :name, :description, :price
  end
  
  def self.trigger_worker(record, remove)
    IndexingWorker.perform_async(record.id, remove)
  end
end
```

## Pagination Support

The gem supports multiple pagination backends:

```ruby
# Configure pagination backend
Typesense.configuration = {
  # ... other configuration ...
  pagination_backend: :kaminari  # or :will_paginate or :pagy
}
```

## Testing

To run the test suite:

```bash
bundle install
bundle exec rake
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin feature/my-new-feature`)
5. Create a new Pull Request

Please make sure to update tests as appropriate and follow the existing coding style.

### Releasing

To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
