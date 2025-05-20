require 'rails'

module Typesense
  class Railtie < Rails::Railtie
    rake_tasks do
      load "typesense/tasks/typesense.rake"
    end
  end

  class Engine < Rails::Engine
  end
end
