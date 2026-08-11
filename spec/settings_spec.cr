require "./spec_helper"
require "webmock"

module Meilisearch::Crystal
  describe SettingsAPI do
    after_each { WebMock.reset }

    it "deserializes typed settings and embedder configuration" do
      body = %({"displayedAttributes":["*"],"searchableAttributes":["title"],"filterableAttributes":["genre"],"sortableAttributes":["year"],"rankingRules":["words"],"stopWords":[],"nonSeparatorTokens":[],"separatorTokens":[],"dictionary":[],"synonyms":{},"distinctAttribute":null,"typoTolerance":{"enabled":true,"minWordSizeForTypos":{"oneTypo":5,"twoTypos":9},"disableOnWords":[],"disableOnAttributes":[],"disableOnNumbers":false},"faceting":{"maxValuesPerFacet":100,"sortFacetValuesBy":{"*":"alpha"}},"pagination":{"maxTotalHits":1000},"proximityPrecision":"byWord","embedders":{"manual":{"source":"userProvided","dimensions":3}},"searchCutoffMs":null,"localizedAttributes":[],"facetSearch":true,"prefixSearch":"indexingTime"})
      settings = Settings.from_json(body)
      settings.prefix_search.should eq(PrefixSearch::IndexingTime)
      settings.proximity_precision.should eq(ProximityPrecision::ByWord)
      embedders = settings.embedders || raise "expected embedders"
      embedders["manual"].source.should eq(EmbedderSource::UserProvided)
    end

    it "gets, partially updates, and resets settings" do
      WebMock.stub(:get, "http://localhost:7700/indexes/movies/settings")
        .to_return(body: %({"displayedAttributes":["*"],"searchableAttributes":["*"],"filterableAttributes":[],"sortableAttributes":[],"rankingRules":[],"stopWords":[],"nonSeparatorTokens":[],"separatorTokens":[],"dictionary":[],"synonyms":{},"distinctAttribute":null,"typoTolerance":null,"faceting":null,"pagination":null,"proximityPrecision":"byWord","embedders":{},"searchCutoffMs":null,"localizedAttributes":[],"facetSearch":true,"prefixSearch":"indexingTime"}))
      WebMock.stub(:patch, "http://localhost:7700/indexes/movies/settings")
        .with(body: %({"filterableAttributes":["genre"]}))
        .to_return(status: 202, body: %({"taskUid":1}))
      WebMock.stub(:delete, "http://localhost:7700/indexes/movies/settings")
        .to_return(status: 202, body: %({"taskUid":2}))

      api = Client.new.settings
      api.get("movies").facet_search.should be_true
      api.update("movies", Settings.new(filterable_attributes: ["genre"])).task_uid.should eq(1)
      api.reset("movies").task_uid.should eq(2)
    end

    it "reads and resets individual settings" do
      WebMock.stub(:get, "http://localhost:7700/indexes/movies/settings/ranking-rules")
        .to_return(body: %(["words","typo"]))
      WebMock.stub(:delete, "http://localhost:7700/indexes/movies/settings/ranking-rules")
        .to_return(status: 202, body: %({"taskUid":3}))

      api = Client.new.settings
      api.ranking_rules("movies").should eq(["words", "typo"])
      api.reset_ranking_rules("movies").task_uid.should eq(3)
    end
  end
end
