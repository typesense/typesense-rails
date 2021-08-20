require File.join(File.dirname(__FILE__), 'lib', 'typesense', 'version')

require 'date'

Gem::Specification.new do |s|
  s.name = 'typesense-rails'
  s.version = TypesenseSearch::VERSION

  s.required_rubygems_version = Gem::Requirement.new('>= 0') if s.respond_to? :required_rubygems_version=
  s.authors = ['typesense']
  s.description = 'TypesenseSearch integration to your favorite ORM'
  s.email = 'contact@typesense.com'
  s.extra_rdoc_files = [
    'CHANGELOG.MD',
    'LICENSE',
    'README.md'
  ]
  s.files = [
    '.document',
    '.rspec',
    '.travis.yml',
    'CHANGELOG.MD',
    'Gemfile',
    'Gemfile.lock',
    'LICENSE',
    'README.md',
    'Rakefile',
    'typesensesearch-rails.gemspec',
    'lib/typesensesearch-rails.rb',
    'lib/typesensesearch/algolia_job.rb',
    'lib/typesensesearch/configuration.rb',
    'lib/typesensesearch/pagination.rb',
    'lib/typesensesearch/pagination/kaminari.rb',
    'lib/typesensesearch/pagination/will_paginate.rb',
    'lib/typesensesearch/railtie.rb',
    'lib/typesensesearch/tasks/typesensesearch.rake',
    'lib/typesensesearch/utilities.rb',
    'lib/typesensesearch/version.rb',
    'spec/spec_helper.rb',
    'spec/utilities_spec.rb'
  ]
  s.homepage = 'http://github.com/typesense/typesense-rails'
  s.licenses = ['MIT']
  s.require_paths = ['lib']
  s.rubygems_version = '2.1.11'
  s.summary = 'Typesense integration to your favorite ORM'

  if s.respond_to? :specification_version
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0')
      s.add_runtime_dependency('json', ['>= 1.5.1'])
      s.add_runtime_dependency 'typesense', '>=0.13.0'
      s.add_development_dependency('kaminari', ['>= 0'])
      s.add_development_dependency 'rake'
      s.add_development_dependency 'rdoc'
      s.add_development_dependency 'travis'
      s.add_development_dependency('will_paginate', ['>= 2.3.15'])
    else
      s.add_dependency('json', ['>= 1.5.1'])
      s.add_dependency 'typesense', '>=0.13.0'
    end
  else
    s.add_dependency('json', ['>= 1.5.1'])
    s.add_dependency 'typesense', '>=0.13.0'
  end
end
