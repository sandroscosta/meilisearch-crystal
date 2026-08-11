require "../spec_helper"

module Meilisearch::Crystal
  if ENV["MEILISEARCH_INTEGRATION"]? == "1"
    describe "settings integration" do
      it "gets, partially updates, reads, and resets typed settings" do
        allow_integration_connections
        client = Client.new
        uid = "crystal_settings_#{Time.utc.to_unix_ms}"

        begin
          client.indexes.create!(uid, "id", poll_interval: 10.milliseconds)
          update = Settings.new(
            filterable_attributes: ["genre"],
            sortable_attributes: ["year"],
            ranking_rules: ["words", "typo", "sort"],
            prefix_search: PrefixSearch::Disabled,
            embedders: {"manual" => Embedder.new(EmbedderSource::UserProvided, dimensions: 3)}
          )
          task = client.settings.update(uid, update)
          client.wait_for_task(task, poll_interval: 10.milliseconds).succeeded?.should be_true

          settings = client.index(uid).settings
          settings.filterable_attributes.should eq(["genre"])
          settings.prefix_search.should eq(PrefixSearch::Disabled)
          embedders = settings.embedders || raise "expected embedders"
          embedders["manual"].dimensions.should eq(3)
          client.settings.ranking_rules(uid).should eq(["words", "typo", "sort"])

          reset_task = client.settings.reset_ranking_rules(uid)
          client.wait_for_task(reset_task, poll_interval: 10.milliseconds).succeeded?.should be_true
          client.settings.ranking_rules(uid).should_not eq(["words", "typo", "sort"])

          reset_all = client.settings.reset(uid)
          client.wait_for_task(reset_all, poll_interval: 10.milliseconds).succeeded?.should be_true
          client.settings.prefix_search(uid).should eq(PrefixSearch::IndexingTime)
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
end
