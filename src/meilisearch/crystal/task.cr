# Task models.
#
# Meilisearch processes all mutation requests asynchronously, returning a
# task uid that can be polled. This file defines the base task shape used by
# `Client#wait_for_task`; the discriminated subtypes land with the full task
# model (see the tasks spec).
require "json"

module Meilisearch::Crystal
  # Converts `status`/`type` JSON strings (lowercase / camelCase) to their
  # enum members (e.g. `"succeeded"` → `BasicTask::Status::Succeeded`).
  # Defined before `BasicTask` so the annotation resolves for serialization.
  module TaskStatusCodeConverter
    extend self

    def from_json(pull : JSON::PullParser) : BasicTask::Status
      BasicTask::Status.parse?(pull.read_string.camelcase) || BasicTask::Status::Enqueued
    end

    def to_json(value : BasicTask::Status, json : JSON::Builder)
      json.string(value.to_s.camelcase(lower: true))
    end
  end

  module TaskTypeConverter
    extend self

    def from_json(pull : JSON::PullParser) : BasicTask::Type
      BasicTask::Type.parse?(pull.read_string.camelcase) || BasicTask::Type::Unknown
    end

    def to_json(value : BasicTask::Type, json : JSON::Builder)
      json.string(value.to_s.camelcase(lower: true))
    end
  end

  # Parses current RFC 3339 task timestamps while retaining compatibility
  # with older millisecond timestamp responses.
  module TaskTimeConverter
    extend self

    def from_json(pull : JSON::PullParser) : Time
      case pull.kind
      when .string?
        Time::Format::RFC_3339.parse(pull.read_string)
      when .int?
        Time.unix_ms(pull.read_int)
      else
        raise ArgumentError.new("Expected an RFC 3339 string or epoch milliseconds")
      end
    end

    def to_json(value : Time, json : JSON::Builder) : Nil
      json.string(Time::Format::RFC_3339.format(value))
    end
  end

  # The minimal task envelope returned by task endpoints: the fields every
  # task shares, independent of its type.
  struct BasicTask
    include JSON::Serializable

    # Terminal and lifecycle statuses of a Meilisearch task.
    enum Status
      Enqueued
      Processing
      Succeeded
      Failed
      Canceled
    end

    # The distinct task kinds Meilisearch can report.
    enum Type
      IndexCreation
      IndexUpdate
      IndexDeletion
      IndexSwap
      DocumentAdditionOrUpdate
      DocumentDeletion
      SettingsUpdate
      DumpCreation
      TaskCancelation
      TaskDeletion
      SnapshotCreation
      Unknown
    end

    getter uid : Int64
    @[JSON::Field(key: "indexUid")]
    getter index_uid : String?
    @[JSON::Field(converter: TaskStatusCodeConverter)]
    getter status : Status
    @[JSON::Field(converter: TaskTypeConverter)]
    getter type : Type
    @[JSON::Field(key: "enqueuedAt", converter: TaskTimeConverter)]
    getter enqueued_at : Time
    @[JSON::Field(key: "startedAt", converter: TaskTimeConverter)]
    getter started_at : Time?
    @[JSON::Field(key: "finishedAt", converter: TaskTimeConverter)]
    getter finished_at : Time?

    def succeeded? : Bool
      status == Status::Succeeded
    end

    def failed? : Bool
      status == Status::Failed
    end

    def canceled? : Bool
      status == Status::Canceled
    end

    def terminal? : Bool
      succeeded? || failed? || canceled?
    end
  end

  # Returned by mutation endpoints: carries only the uid of the enqueued task.
  struct TaskResult
    include JSON::Serializable

    @[JSON::Field(key: "taskUid")]
    getter task_uid : Int64?
  end
end
