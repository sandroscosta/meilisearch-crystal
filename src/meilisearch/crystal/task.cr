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
  abstract struct BasicTask
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
    @[JSON::Field(key: "indexUid")]
    getter index_uid : String?
    @[JSON::Field(converter: TaskStatusCodeConverter)]
    getter status : BasicTask::Status?
    @[JSON::Field(converter: TaskTypeConverter)]
    getter type : BasicTask::Type?
    @[JSON::Field(key: "enqueuedAt", converter: TaskTimeConverter)]
    getter enqueued_at : Time?
  end

  # A complete task response dispatched to a concrete subtype by task type.
  abstract struct Task < BasicTask
    @[JSON::Field(key: "batchUid")]
    getter batch_uid : Int64?
    @[JSON::Field(key: "canceledBy")]
    getter canceled_by : Int64?
    @[JSON::Field(converter: DurationConverter)]
    getter duration : Time::Span?
    getter error : Error?

    def self.new(pull : JSON::PullParser) : Task
      from_json(pull.read_raw)
    end

    def self.from_json(source : String | IO) : Task
      raw = source.is_a?(String) ? source : source.gets_to_end
      case JSON.parse(raw)["type"].as_s
      when "indexCreation"            then IndexCreation.parse(raw)
      when "indexUpdate"              then IndexUpdate.parse(raw)
      when "indexDeletion"            then IndexDeletion.parse(raw)
      when "indexSwap"                then IndexSwap.parse(raw)
      when "documentAdditionOrUpdate" then DocumentAdditionOrUpdate.parse(raw)
      when "documentDeletion", "documentDeletionByFilter", "documentClear"
        DocumentDeletion.parse(raw)
      else
        parse_remaining(raw)
      end
    end

    private def self.parse_remaining(raw : String) : Task
      case JSON.parse(raw)["type"].as_s
      when "settingsUpdate"   then SettingsUpdate.parse(raw)
      when "dumpCreation"     then DumpCreation.parse(raw)
      when "taskCancelation"  then TaskCancelation.parse(raw)
      when "taskDeletion"     then TaskDeletion.parse(raw)
      when "snapshotCreation" then SnapshotCreation.parse(raw)
      else                         Unknown.parse(raw)
      end
    end

    # Adds a non-dispatching parser to a concrete task subtype.
    macro parseable
      def self.parse(source : String)
        new_from_json_pull_parser(JSON::PullParser.new(source))
      end
    end

    # Details reported by index lifecycle tasks.
    struct IndexDetails < Resource
      field primary_key : String?
      field deleted_documents : Int64?
    end

    # Details reported by index-swap tasks.
    struct SwapDetails < Resource
      field swaps : Array(JSON::Any)?
    end

    # Counts and filters reported by document mutation tasks.
    struct DocumentDetails < Resource
      field received_documents : Int64?
      field indexed_documents : Int64?
      field deleted_documents : Int64?
      field provided_ids : Int64?
      field original_filter : String?
    end

    # Settings changed by a settings-update task.
    struct SettingsDetails < Resource
      field ranking_rules : Array(String)?
      field filterable_attributes : Array(String)?
      field sortable_attributes : Array(String)?
      field searchable_attributes : Array(String)?
    end

    # Counts reported by task cancellation and deletion operations.
    struct CountDetails < Resource
      field matched_tasks : Int64?
      field canceled_tasks : Int64?
      field deleted_tasks : Int64?
    end

    # Identifier produced by a dump-creation task.
    struct DumpDetails < Resource
      field dump_uid : String?
    end

    # A completed or pending index-creation task.
    struct IndexCreation < Task
      parseable
      getter details : IndexDetails?
    end

    # A completed or pending index-update task.
    struct IndexUpdate < Task
      parseable
      getter details : IndexDetails?
    end

    # A completed or pending index-deletion task.
    struct IndexDeletion < Task
      parseable
      getter details : IndexDetails?
    end

    # A completed or pending index-swap task.
    struct IndexSwap < Task
      parseable
      getter details : SwapDetails?
    end

    # A completed or pending document ingestion task.
    struct DocumentAdditionOrUpdate < Task
      parseable
      getter details : DocumentDetails?
    end

    # A completed or pending document-deletion task.
    struct DocumentDeletion < Task
      parseable
      getter details : DocumentDetails?
    end

    # A completed or pending settings-update task.
    struct SettingsUpdate < Task
      parseable
      getter details : SettingsDetails?
    end

    # A completed or pending dump-creation task.
    struct DumpCreation < Task
      parseable
      getter details : DumpDetails?
    end

    # A completed or pending task-cancellation task.
    struct TaskCancelation < Task
      parseable
      getter details : CountDetails?
    end

    # A completed or pending task-deletion task.
    struct TaskDeletion < Task
      parseable
      getter details : CountDetails?
    end

    # A completed or pending snapshot-creation task.
    struct SnapshotCreation < Task
      parseable
      getter details : JSON::Any?
    end

    # Forward-compatible representation of an unknown task type.
    struct Unknown < Task
      parseable
      getter details : JSON::Any?
    end
  end
end
