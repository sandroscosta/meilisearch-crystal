require "../spec_helper"

module Meilisearch::Crystal
  if ENV["MEILISEARCH_INTEGRATION"]? == "1"
    describe "management integration" do
      it "covers keys, health, stats, backups, and tenant tokens" do
        client = Client.new
        uid = "crystal_management_#{Time.utc.to_unix_ms}"
        key_uid = "11111111-1111-4111-8111-#{Time.utc.to_unix_ms.to_s[-12, 12]}"
        created_key : Key? = nil

        begin
          client.health.status.should eq("available")
          client.version.pkg_version.should eq("1.53.0")
          client.indexes.create!(uid, "id", poll_interval: 10.milliseconds)
          settings_task = client.settings.update(uid, Settings.new(filterable_attributes: ["tenant_id"]))
          client.wait_for_task(settings_task, poll_interval: 10.milliseconds)
          client.index(uid).documents.upsert!(uid, [
            {id: 1, title: "Visible", tenant_id: 42},
            {id: 2, title: "Hidden", tenant_id: 7},
          ], poll_interval: 10.milliseconds)

          client.stats.indexes.has_key?(uid).should be_true
          client.index(uid).stats.number_of_documents.should eq(2)

          created_key = client.keys.create(["search"], [uid], name: "Crystal integration", uid: key_uid)
          client.keys.get(key_uid).name.should eq("Crystal integration")
          client.keys.update(key_uid, description: "updated").description.should eq("updated")
          client.keys.list.results.any? { |key| key.uid == key_uid }.should be_true

          token = client.generate_tenant_token(
            key_uid,
            {uid => {filter: "tenant_id = 42"}},
            Time.utc + 5.minutes,
            created_key.key
          )
          tenant = Client.new(url: client.url, api_key: token)
          tenant.index(uid).search.hits.size.should eq(1)
          tenant.close

          client.wait_for_task(client.create_dump, poll_interval: 10.milliseconds).succeeded?.should be_true
          client.wait_for_task(client.create_snapshot, poll_interval: 10.milliseconds).succeeded?.should be_true
        ensure
          if created_key
            client.keys.delete(key_uid)
          end
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
