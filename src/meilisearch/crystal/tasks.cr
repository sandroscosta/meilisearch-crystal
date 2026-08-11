# The `tasks` resource endpoint (GET /tasks, GET /tasks/:uid).
#
# Minimal now to power `Client#wait_for_task`; the typed filterable `list`
# surface expands the models (see the tasks spec).
module Meilisearch::Crystal
  # Task lookup and filtered cursor-paginated listing operations.
  class Tasks < API
    # Fetches a single task by uid, raising `Error` if it does not exist.
    def get(uid : Int32 | Int64) : Task
      response(client.get("/tasks/#{uid}"), as: Task)
    end

    # Fetches a single task by uid, returning `nil` if it does not exist.
    def get?(uid : Int32 | Int64) : Task?
      get(uid)
    rescue error : ApiError
      return if error.code == Error::Code::TaskNotFound

      raise error
    end

    def list(uids : Array(Int64)? = nil,
             batch_uids : Array(Int64)? = nil,
             statuses : Array(BasicTask::Status)? = nil,
             types : Array(BasicTask::Type)? = nil,
             index_uids : Array(String)? = nil,
             limit : Int32? = nil,
             from : Int64? = nil,
             reverse : Bool? = nil,
             after_enqueued_at : Time? = nil,
             before_enqueued_at : Time? = nil,
             after_started_at : Time? = nil,
             before_started_at : Time? = nil,
             after_finished_at : Time? = nil,
             before_finished_at : Time? = nil) : List(Task)
      query = HTTP::Params.new
      add_csv(query, "uids", uids)
      add_csv(query, "batchUids", batch_uids)
      add_csv(query, "statuses", statuses.try(&.map(&.to_s.camelcase(lower: true))))
      add_csv(query, "types", types.try(&.map(&.to_s.camelcase(lower: true))))
      add_csv(query, "indexUids", index_uids)
      query["limit"] = limit.to_s if limit
      query["from"] = from.to_s if from
      query["reverse"] = reverse.to_s unless reverse.nil?
      add_time(query, "afterEnqueuedAt", after_enqueued_at)
      add_time(query, "beforeEnqueuedAt", before_enqueued_at)
      add_time(query, "afterStartedAt", after_started_at)
      add_time(query, "beforeStartedAt", before_started_at)
      add_time(query, "afterFinishedAt", after_finished_at)
      add_time(query, "beforeFinishedAt", before_finished_at)
      response(client.get("/tasks", query.empty? ? nil : query), as: List(Task))
    end

    private def add_csv(query : HTTP::Params, key : String, values : Enumerable(T)?) : Nil forall T
      query[key] = values.join(',') if values
    end

    private def add_time(query : HTTP::Params, key : String, value : Time?) : Nil
      query[key] = Time::Format::RFC_3339.format(value) if value
    end
  end
end
