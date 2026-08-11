require "./spec_helper"
require "webmock"

module Meilisearch::Crystal
  describe Tasks do
    after_each { WebMock.reset }

    it "parses mutation task results with typed status and type" do
      result = TaskResult.from_json(%({"taskUid":7,"indexUid":"movies","status":"enqueued","type":"documentAdditionOrUpdate","enqueuedAt":"2026-08-11T21:47:28Z"}))
      result.task_uid.should eq(7)
      result.status.should eq(BasicTask::Status::Enqueued)
      result.type.should eq(BasicTask::Type::DocumentAdditionOrUpdate)
    end

    it "dispatches full tasks to typed detail subtypes" do
      body = %({"uid":7,"batchUid":7,"indexUid":"movies","status":"succeeded","type":"documentAdditionOrUpdate","canceledBy":null,"details":{"receivedDocuments":2,"indexedDocuments":2},"error":null,"duration":"PT0.005S","enqueuedAt":"2026-08-11T21:47:28Z","startedAt":"2026-08-11T21:47:28Z","finishedAt":"2026-08-11T21:47:28Z"})
      task = Task.from_json(body)
      task.should be_a(Task::DocumentAdditionOrUpdate)
      task.as(Task::DocumentAdditionOrUpdate).details.not_nil!.indexed_documents.should eq(2)
      task.status.succeeded?.should be_true
    end

    it "lists tasks with typed filters" do
      body = %({"results":[{"uid":7,"batchUid":7,"indexUid":"movies","status":"succeeded","type":"settingsUpdate","canceledBy":null,"details":{"rankingRules":["words"]},"error":null,"duration":"PT0.005S","enqueuedAt":"2026-08-11T21:47:28Z","startedAt":"2026-08-11T21:47:28Z","finishedAt":"2026-08-11T21:47:28Z"}],"total":1,"limit":20,"from":7,"next":null})
      WebMock.stub(:get, "http://localhost:7700/tasks?indexUids=movies&limit=20&statuses=succeeded&types=settingsUpdate")
        .to_return(body: body)

      tasks = Client.new.tasks.list(
        index_uids: ["movies"],
        limit: 20,
        statuses: [BasicTask::Status::Succeeded],
        types: [BasicTask::Type::SettingsUpdate]
      )
      tasks.first.should be_a(Task::SettingsUpdate)
      tasks.total.should eq(1)
    end
  end
end
