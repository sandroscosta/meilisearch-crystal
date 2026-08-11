require "./spec_helper"
require "webmock"

module Meilisearch::Crystal
  describe Indexes do
    after_each { WebMock.reset }

    it "deserializes typed index metadata" do
      body = %({"uid":"movies","primaryKey":"id","createdAt":"2026-08-11T10:00:00Z","updatedAt":"2026-08-11T11:00:00Z"})
      index = Index.from_json(body)
      index.uid.should eq("movies")
      index.primary_key.should eq("id")
      index.created_at.should eq(Time.utc(2026, 8, 11, 10))
    end

    it "lists indexes with pagination" do
      body = %({"results":[{"uid":"movies","primaryKey":null,"createdAt":"2026-08-11T10:00:00Z","updatedAt":"2026-08-11T11:00:00Z"}],"offset":1,"limit":2,"total":3})
      WebMock.stub(:get, "http://localhost:7700/indexes?limit=2&offset=1")
        .to_return(body: body)

      indexes = Client.new.indexes.list(offset: 1, limit: 2)
      indexes.first.uid.should eq("movies")
      indexes.total.should eq(3)
    end

    it "fetches an index and safely handles index-not-found" do
      WebMock.stub(:get, "http://localhost:7700/indexes/movies")
        .to_return(body: %({"uid":"movies","primaryKey":"id","createdAt":"2026-08-11T10:00:00Z","updatedAt":"2026-08-11T11:00:00Z"}))
      WebMock.stub(:get, "http://localhost:7700/indexes/missing")
        .to_return(status: 404, body: %({"message":"missing","code":"index_not_found","type":"invalid_request","link":"https://docs.meilisearch.com/errors#index_not_found"}))

      indexes = Client.new.indexes
      indexes.get("movies").uid.should eq("movies")
      indexes.get?("missing").should be_nil
    end

    it "creates, updates, deletes, and swaps indexes" do
      task = %({"taskUid":1})
      WebMock.stub(:post, "http://localhost:7700/indexes")
        .with(body: %({"uid":"movies","primaryKey":"id"}))
        .to_return(status: 202, body: task)
      WebMock.stub(:patch, "http://localhost:7700/indexes/movies")
        .with(body: %({"primaryKey":"movie_id","uid":"films"}))
        .to_return(status: 202, body: task)
      WebMock.stub(:delete, "http://localhost:7700/indexes/movies")
        .to_return(status: 202, body: task)
      WebMock.stub(:post, "http://localhost:7700/swap-indexes")
        .with(body: %([{"indexes":["movies","films"]}]))
        .to_return(status: 202, body: task)

      indexes = Client.new.indexes
      indexes.create("movies", "id").task_uid.should eq(1)
      indexes.update("movies", primary_key: "movie_id", new_uid: "films").task_uid.should eq(1)
      indexes.delete("movies").task_uid.should eq(1)
      indexes.swap("movies", "films").task_uid.should eq(1)
    end

    it "exposes metadata lifecycle through IndexClient" do
      WebMock.stub(:get, "http://localhost:7700/indexes/movies")
        .to_return(body: %({"uid":"movies","primaryKey":null,"createdAt":"2026-08-11T10:00:00Z","updatedAt":"2026-08-11T11:00:00Z"}))

      Client.new.index("movies").metadata.uid.should eq("movies")
    end
  end
end
