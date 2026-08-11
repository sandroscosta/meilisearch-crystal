require "./spec_helper"
require "webmock"

module Meilisearch::Crystal
  struct SearchMovie
    include JSON::Serializable

    getter id : Int32
    getter title : String
  end

  describe Search do
    after_each { WebMock.reset }

    it "serializes the full typed query surface" do
      query = Query.new(
        q: "alien",
        index_uid: "movies",
        filter: ["year > 1970"],
        matching_strategy: MatchingStrategy::All,
        hybrid: Hybrid.new("default", 0.7),
        retrieve_vectors: true,
        federation_options: FederationOptions.new(weight: 2.0)
      )
      json = JSON.parse(query.to_json)
      json["matchingStrategy"].as_s.should eq("all")
      json["hybrid"]["semanticRatio"].as_f.should eq(0.7)
      json["federationOptions"]["weight"].as_f.should eq(2.0)
      json.as_h.has_key?("limit").should be_false
    end

    it "returns raw or typed enumerable search hits" do
      body = %({"hits":[{"id":1,"title":"Alien"}],"query":"alien","processingTimeMs":2,"estimatedTotalHits":1,"limit":20,"offset":0})
      WebMock.stub(:post, "http://localhost:7700/indexes/movies/search").to_return(body: body)

      index = Client.new.index("movies")
      index.search("alien").first["title"].as_s.should eq("Alien")
      index.search("alien", as: SearchMovie).first.title.should eq("Alien")
    end

    it "performs facet and similar searches" do
      WebMock.stub(:post, "http://localhost:7700/indexes/movies/facet-search")
        .to_return(body: %({"facetHits":[{"value":"Drama","count":3}],"facetQuery":"dr","processingTimeMs":1}))
      WebMock.stub(:post, "http://localhost:7700/indexes/movies/similar")
        .to_return(body: %({"hits":[{"id":2,"title":"Aliens"}],"processingTimeMs":1,"estimatedTotalHits":1,"limit":20,"offset":0}))

      index = Client.new.index("movies")
      index.facet_search(FacetSearchRequest.new("genres", "dr")).facet_hits.first.count.should eq(3)
      index.similar(1, "default", as: SearchMovie).first.title.should eq("Aliens")
    end

    it "supports typed multi-search and federated hits" do
      multi_body = %({"results":[{"indexUid":"movies","hits":[{"id":1,"title":"Alien"}],"query":"alien","processingTimeMs":1,"estimatedTotalHits":1,"limit":20,"offset":0}]})
      federation_body = %({"hits":[{"id":1,"title":"Alien","_federation":{"indexUid":"movies","queriesPosition":0}}],"processingTimeMs":1,"estimatedTotalHits":1,"limit":20,"offset":0})
      WebMock.stub(:post, "http://localhost:7700/multi-search").to_return(body: multi_body)

      search = Client.new.search
      query = Query.new(q: "alien", index_uid: "movies")
      search.multi([query], as: SearchMovie).results.first.first.title.should eq("Alien")
      WebMock.reset
      WebMock.stub(:post, "http://localhost:7700/multi-search").to_return(body: federation_body)
      hit = search.federated([query], MultiSearch::Federation.new, as: SearchMovie).first
      hit.document.title.should eq("Alien")
      hit.federation.index_uid.should eq("movies")
    end
  end
end
