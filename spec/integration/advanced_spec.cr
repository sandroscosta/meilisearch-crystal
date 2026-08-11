require "../spec_helper"

module Meilisearch::Crystal
  if ENV["MEILISEARCH_INTEGRATION"]? == "1"
    describe "advanced APIs integration" do
      it "round-trips batches and experimental features" do
        client = Client.new
        index_uid = "crystal_advanced_#{Time.utc.to_unix_ms}"
        task = client.indexes.create(index_uid)
        completed = client.wait_for_task(task, timeout: 15.seconds)

        batch_uid = completed.batch_uid.not_nil!
        client.batches.get(batch_uid).uid.should eq(batch_uid)
        client.batches.list(limit: 1).results.should_not be_empty

        current = client.experimental_features.get
        updated = client.experimental_features.update(
          ExperimentalFeaturesPatch.new(contains_filter: current.contains_filter?)
        )
        updated.contains_filter?.should eq(current.contains_filter?)
      ensure
        if cleanup_client = client
          if cleanup_uid = index_uid
            cleanup = cleanup_client.indexes.delete(cleanup_uid)
            cleanup_client.wait_for_task(cleanup, timeout: 15.seconds)
          end
        end
      end
    end
  end
end
