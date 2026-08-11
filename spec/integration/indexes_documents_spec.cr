require "../spec_helper"

module Meilisearch::Crystal
  if ENV["MEILISEARCH_INTEGRATION"]? == "1"
    describe "indexes and documents integration" do
      it "runs index and document lifecycles against Meilisearch" do
        allow_integration_connections
        client = Client.new
        indexes = client.indexes
        suffix = Time.utc.to_unix_ms
        first_uid = "crystal_integration_#{suffix}"
        renamed_uid = "#{first_uid}_renamed"
        second_uid = "#{first_uid}_second"

        begin
          created = indexes.create!(first_uid, "id", poll_interval: 10.milliseconds)
          created.uid.should eq(first_uid)
          created.primary_key.should eq("id")
          indexes.list.any? { |index| index.uid == first_uid }.should be_true

          update_task = indexes.update(first_uid, new_uid: renamed_uid)
          client.wait_for_task(update_task, poll_interval: 10.milliseconds).succeeded?.should be_true
          indexes.get?(first_uid).should be_nil
          indexes.get(renamed_uid).uid.should eq(renamed_uid)

          indexes.create!(second_uid, "id", poll_interval: 10.milliseconds)
          documents = client.index(renamed_uid).documents
          settings_task = TaskResult.from_json(
            client.patch(
              "/indexes/#{renamed_uid}/settings",
              {filterableAttributes: ["year"]}.to_json
            ).body
          )
          client.wait_for_task(settings_task, poll_interval: 10.milliseconds).succeeded?.should be_true
          documents.upsert!(renamed_uid, [{id: 1, title: "Alien", year: 1979}], poll_interval: 10.milliseconds)
          documents.upsert_patch!(renamed_uid, [{id: 1, title: "Aliens"}], poll_interval: 10.milliseconds)

          typed = documents.fetch(renamed_uid, as: IntegrationMovie)
          typed.first.title.should eq("Aliens")
          typed.first.year.should eq(1979)

          streamed = (2..3).each.map { |id| {id: id, title: "Movie #{id}", year: 2000 + id} }
          documents.upsert!(renamed_uid, streamed, poll_interval: 10.milliseconds)
          documents.fetch(renamed_uid).total.should eq(3)

          documents.delete(renamed_uid, filter: "year > 2000").tap do |task|
            client.wait_for_task(task, poll_interval: 10.milliseconds).succeeded?.should be_true
          end
          documents.delete(renamed_uid, 1).tap do |task|
            client.wait_for_task(task, poll_interval: 10.milliseconds).succeeded?.should be_true
          end
          documents.fetch(renamed_uid).total.should eq(0)

          swap_task = indexes.swap(renamed_uid, second_uid)
          client.wait_for_task(swap_task, poll_interval: 10.milliseconds).succeeded?.should be_true
        ensure
          [first_uid, renamed_uid, second_uid].each do |uid|
            if indexes.get?(uid)
              task = indexes.delete(uid)
              client.wait_for_task(task, poll_interval: 10.milliseconds)
            end
          end
          client.close
        end
      end
    end
  end

  private struct IntegrationMovie
    include JSON::Serializable

    getter id : Int32
    getter title : String
    getter year : Int32
  end
end
