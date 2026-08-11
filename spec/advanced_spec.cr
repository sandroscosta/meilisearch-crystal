require "./spec_helper"
require "webmock"

module Meilisearch::Crystal
  describe "advanced APIs" do
    after_each { WebMock.reset }

    it "lists and gets typed batches" do
      batch = %({"uid":7,"progress":null,"details":{},"stats":{"totalNbTasks":1},"duration":"PT0.25S","startedAt":"2026-08-11T00:00:00Z","finishedAt":"2026-08-11T00:00:00.25Z","batchStrategy":"batched all enqueued tasks"})
      WebMock.stub(:get, "http://localhost:7700/batches?limit=1").to_return(body: %({"results":[#{batch}],"total":1,"limit":1,"from":7,"next":null}))
      WebMock.stub(:get, "http://localhost:7700/batches/7").to_return(body: batch)

      batches = Client.new.batches
      batches.list(limit: 1).first.duration.should eq(250.milliseconds)
      batches.get(7).batch_strategy.should eq("batched all enqueued tasks")
    end

    it "gets and partially updates experimental features" do
      features = %({"metrics":false,"logsRoute":false,"tasksStreamingRoute":false,"editDocumentsByFunction":false,"containsFilter":true,"dynamicSearchRules":false,"network":false,"getTaskDocumentsRoute":false,"taskQueueCompactionRoute":false,"compositeEmbedders":false,"chatCompletions":false,"multimodal":false,"foreignKeys":false,"disableDocumentsFetchQueue":false,"legacySearch":false,"renderRoute":false})
      WebMock.stub(:get, "http://localhost:7700/experimental-features").to_return(body: features)
      WebMock.stub(:patch, "http://localhost:7700/experimental-features").with(body: %({"containsFilter":true})).to_return(body: features)

      api = Client.new.experimental_features
      api.get.contains_filter?.should be_true
      api.update(ExperimentalFeaturesPatch.new(contains_filter: true)).contains_filter?.should be_true
    end

    it "gets network topology" do
      body = %({"self":null,"remotes":{},"shards":{},"leader":null,"version":"00000000-0000-0000-0000-000000000000"})
      WebMock.stub(:get, "http://localhost:7700/network").to_return(body: body)
      WebMock.stub(:patch, "http://localhost:7700/network").with(body: %({})).to_return(body: body)
      network = Client.new.network
      network.get.remotes.should be_empty
      network.update(Hash(String, JSON::Any).new).shards.should be_empty
    end
  end
end
