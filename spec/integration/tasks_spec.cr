require "../spec_helper"

module Meilisearch::Crystal
  if ENV["MEILISEARCH_INTEGRATION"]? == "1"
    describe "tasks integration" do
      it "dispatches details and lists with typed filters" do
        client = Client.new
        uid = "crystal_tasks_#{Time.utc.to_unix_ms}"

        begin
          client.indexes.create!(uid, "id", poll_interval: 10.milliseconds)
          result = client.index(uid).documents.upsert(uid, [{id: 1, title: "Alien"}])
          completed = client.wait_for_task(result, poll_interval: 10.milliseconds)
          completed.should be_a(Task::DocumentAdditionOrUpdate)
          details = completed.as(Task::DocumentAdditionOrUpdate).details.not_nil!
          details.received_documents.should eq(1)
          details.indexed_documents.should eq(1)

          listed = client.tasks.list(
            index_uids: [uid],
            statuses: [BasicTask::Status::Succeeded],
            types: [BasicTask::Type::DocumentAdditionOrUpdate]
          )
          listed.any? { |task| task.uid == completed.uid }.should be_true
          client.index(uid).tasks.any? { |task| task.index_uid == uid }.should be_true
          client.tasks.get?(4_000_000_000_i64).should be_nil
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
