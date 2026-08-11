# Index lifecycle API.
module Meilisearch::Crystal
  # Index lifecycle, listing, and lookup operations.
  class Indexes < API
    def list(offset : Int32? = nil, limit : Int32? = nil) : List(Index)
      query = HTTP::Params.new
      query["offset"] = offset.to_s if offset
      query["limit"] = limit.to_s if limit
      response(client.get("/indexes", query.empty? ? nil : query), as: List(Index))
    end

    def get(uid : String) : Index
      response(client.get(index_path(uid)), as: Index)
    end

    def get?(uid : String) : Index?
      get(uid)
    rescue error : ApiError
      return if error.code == Error::Code::IndexNotFound

      raise error
    end

    def create(uid : String, primary_key : String? = nil) : TaskResult
      body = JSON.build do |json|
        json.object do
          json.field("uid", uid)
          json.field("primaryKey", primary_key) if primary_key
        end
      end
      response(client.post("/indexes", body), as: TaskResult)
    end

    def create!(uid : String,
                primary_key : String? = nil,
                timeout : Time::Span? = nil,
                poll_interval : Time::Span = 100.milliseconds) : Index
      task = client.wait_for_task(create(uid, primary_key), timeout: timeout, poll_interval: poll_interval)
      ensure_success(task)
      get(uid)
    end

    def update(uid : String, primary_key : String? = nil, new_uid : String? = nil) : TaskResult
      body = JSON.build do |json|
        json.object do
          json.field("primaryKey", primary_key) if primary_key
          json.field("uid", new_uid) if new_uid
        end
      end
      response(client.patch(index_path(uid), body), as: TaskResult)
    end

    def delete(uid : String) : TaskResult
      response(client.delete(index_path(uid)), as: TaskResult)
    end

    def swap(first_uid : String, second_uid : String) : TaskResult
      swap([{first_uid, second_uid}])
    end

    def swap(pairs : Enumerable(Tuple(String, String))) : TaskResult
      body = JSON.build do |json|
        json.array do
          pairs.each do |pair|
            json.object do
              json.field("indexes") do
                json.array do
                  json.string(pair[0])
                  json.string(pair[1])
                end
              end
            end
          end
        end
      end
      response(client.post("/swap-indexes", body), as: TaskResult)
    end

    private def index_path(uid : String) : String
      "/indexes/#{URI.encode_path_segment(uid)}"
    end

    private def ensure_success(task : BasicTask) : Nil
      return if task.succeeded?

      raise TaskUnsuccessful.new("Task #{task.uid} finished with status #{task.status}")
    end
  end
end
