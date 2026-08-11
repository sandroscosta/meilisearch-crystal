require "./spec_helper"

describe Meilisearch::Crystal do
  it "exposes the shard version from shard.yml" do
    Meilisearch::Crystal::VERSION.should eq("0.1.0")
  end

  it "defines the library exception hierarchy" do
    Meilisearch::Crystal::Exception.should be < ::Exception
    Meilisearch::Crystal::CommunicationError.should be < Meilisearch::Crystal::Exception
    Meilisearch::Crystal::TimeoutError.should be < Meilisearch::Crystal::Exception
    Meilisearch::Crystal::TaskUnsuccessful.should be < Meilisearch::Crystal::Exception
    Meilisearch::Crystal::MissingValue.should be < Meilisearch::Crystal::Exception
  end
end
