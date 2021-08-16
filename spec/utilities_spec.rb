require File.expand_path(File.join(File.dirname(__FILE__), 'spec_helper'))

AlgoliaSearch.configuration = {
  nodes: [{
    host: 'localhost',   # For Typesense Cloud use xxx.a1.typesense.net
    port: 8108,          # For Typesense Cloud use 443
    protocol: 'http'         # For Typesense Cloud use https
  }],
  api_key: 'xyz',
  connection_timeout_seconds: 2
}

describe AlgoliaSearch::Utilities do
  before(:each) do
    @included_in = AlgoliaSearch.instance_variable_get :@included_in
    AlgoliaSearch.instance_variable_set :@included_in, []

    class Dummy
      include AlgoliaSearch

      def self.model_name
        'Dummy'
      end

      algoliasearch
    end
  end

  after(:each) do
    AlgoliaSearch.instance_variable_set :@included_in, @included_in
  end

  it 'should get the models where AlgoliaSearch module was included' do
    (AlgoliaSearch::Utilities.get_model_classes - [Dummy]).should == []
  end
end
