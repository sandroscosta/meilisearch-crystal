# The `tasks` resource endpoint (GET /tasks, GET /tasks/:uid).
#
# Minimal now to power `Client#wait_for_task`; the typed filterable `list`
# surface expands the models (see the tasks spec).
module Meilisearch::Crystal
  class Tasks < API
    # Fetches a single task by uid, raising `Error` if it does not exist.
    def get(uid : Int32 | Int64) : BasicTask
      response(client.get("/tasks/#{uid}"), as: BasicTask)
    end

    # Fetches a single task by uid, returning `nil` if it does not exist.
    def get?(uid : Int32 | Int64) : BasicTask?
      begin
        get(uid)
      rescue ApiError
        nil
      end
    end
  end
end
