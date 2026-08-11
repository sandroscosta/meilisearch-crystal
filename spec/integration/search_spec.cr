require "../spec_helper"

module Meilisearch::Crystal
  if ENV["MEILISEARCH_INTEGRATION"]? == "1"
    describe "search integration" do
      it "covers typed, facet, similar, multi, and federated search" do
        allow_integration_connections
        client = Client.new
        uid = "crystal_search_#{Time.utc.to_unix_ms}"

        begin
          client.indexes.create!(uid, "id", poll_interval: 10.milliseconds)
          settings = {
            filterableAttributes: ["genre", "year"],
            sortableAttributes:   ["year"],
            embedders:            {manual: {source: "userProvided", dimensions: 3}},
          }
          settings_task = TaskResult.from_json(client.patch("/indexes/#{uid}/settings", settings.to_json).body)
          client.wait_for_task(settings_task, poll_interval: 10.milliseconds).succeeded?.should be_true

          documents = client.index(uid).documents
          documents.upsert!(uid, [
            {id: 1, title: "Alien", genre: "Science Fiction", year: 1979, _vectors: {manual: [1.0, 0.0, 0.0]}},
            {id: 2, title: "Aliens", genre: "Science Fiction", year: 1986, _vectors: {manual: [0.9, 0.1, 0.0]}},
            {id: 3, title: "Arrival", genre: "Drama", year: 2016, _vectors: {manual: [0.7, 0.3, 0.0]}},
          ], poll_interval: 10.milliseconds)

          index = client.index(uid)
          query = Query.new(q: "alien", filter: "year > 1980", sort: ["year:asc"], facets: ["genre"])
          typed = index.search(query, as: IntegrationSearchMovie)
          typed.first.title.should eq("Aliens")
          facets = typed.facet_distribution || raise "expected facet distribution"
          facets["genre"]["Science Fiction"].should eq(1)
          index.search("alien").first["id"].as_i.should eq(1)

          facet = index.facet_search(FacetSearchRequest.new("genre", "sci"))
          facet.facet_hits.first.value.should eq("Science Fiction")

          similar = index.similar(1, "manual", as: IntegrationSearchMovie)
          similar.any? { |movie| movie.id == 2 }.should be_true

          queries = [Query.new(q: "alien", index_uid: uid), Query.new(q: "arrival", index_uid: uid)]
          client.search.multi(queries, as: IntegrationSearchMovie).results.size.should eq(2)
          federated = client.search.federated(queries, MultiSearch::Federation.new, as: IntegrationSearchMovie)
          federated.first.federation.index_uid.should eq(uid)
        ensure
          if client.indexes.get?(uid)
            task = client.indexes.delete(uid)
            client.wait_for_task(task, poll_interval: 10.milliseconds)
          end
          client.close
        end
      end
    end
  end

  private struct IntegrationSearchMovie
    include JSON::Serializable

    getter id : Int32
    getter title : String
    getter genre : String
    getter year : Int32
  end
end
