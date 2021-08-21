require File.expand_path(File.join(File.dirname(__FILE__), 'spec_helper'))

Typesense.configuration = {
  nodes: [{
    host: 'localhost',   # For Typesense Cloud use xxx.a1.typesense.net
    port: 8108,          # For Typesense Cloud use 443
    protocol: 'http'         # For Typesense Cloud use https
  }],
  api_key: 'xyz',
  connection_timeout_seconds: 2
}

describe Typesense::Utilities do
  before(:each) do
    @included_in = Typesense.instance_variable_get :@included_in
    Typesense.instance_variable_set :@included_in, []

    class Dummy
      include Typesense

      def self.model_name
        'Dummy'
      end

      typesense
    end
  end

  after(:each) do
    Typesense.instance_variable_set :@included_in, @included_in
  end

  it 'should get the models where Typesense module was included' do
    (Typesense::Utilities.get_model_classes - [Dummy]).should == []
  end
end
