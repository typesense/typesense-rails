namespace :typesense do
  desc "Reindex all models"
  task :reindex => :environment do
    Typesense::Utilities.reindex_all_models
  end

  desc "Set settings to all indexes"
  task :set_all_settings => :environment do
    Typesense::Utilities.set_settings_all_models
  end

  desc "Clear all indexes"
  task :clear_indexes => :environment do
    puts "clearing all indexes"
    Typesense::Utilities.clear_all_indexes
  end
end
