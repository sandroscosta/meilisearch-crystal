# Document write, fetch, and deletion API.
module Meilisearch::Crystal
  class Documents < API
    def upsert(uid : String, documents : Array, primary_key : String? = nil) : TaskResult
      response(client.post(documents_path(uid, primary_key), documents.to_json), as: TaskResult)
    end

    def upsert(uid : String, documents : Enumerable, primary_key : String? = nil) : TaskResult
      stream(uid, documents, primary_key, patch: false)
    end

    def upsert!(uid : String, documents, primary_key : String? = nil,
                timeout : Time::Span? = nil,
                poll_interval : Time::Span = 100.milliseconds) : BasicTask
      await_success(upsert(uid, documents, primary_key), timeout, poll_interval)
    end

    def upsert_patch(uid : String, documents : Array, primary_key : String? = nil) : TaskResult
      response(client.put(documents_path(uid, primary_key), documents.to_json), as: TaskResult)
    end

    def upsert_patch(uid : String, documents : Enumerable, primary_key : String? = nil) : TaskResult
      stream(uid, documents, primary_key, patch: true)
    end

    def upsert_patch!(uid : String, documents, primary_key : String? = nil,
                      timeout : Time::Span? = nil,
                      poll_interval : Time::Span = 100.milliseconds) : BasicTask
      await_success(upsert_patch(uid, documents, primary_key), timeout, poll_interval)
    end

    def fetch(uid : String,
              offset : Int32? = nil,
              limit : Int32? = nil,
              fields : Enumerable(String)? = nil,
              ids : Array(String) | Array(Int32) | Array(Int64) | Nil = nil,
              filter : String? = nil,
              sort : Enumerable(String)? = nil) : List(JSON::Any)
      fetch(uid, JSON::Any, offset, limit, fields, ids, filter, sort)
    end

    def fetch(uid : String,
              as type : T.class,
              offset : Int32? = nil,
              limit : Int32? = nil,
              fields : Enumerable(String)? = nil,
              ids : Array(String) | Array(Int32) | Array(Int64) | Nil = nil,
              filter : String? = nil,
              sort : Enumerable(String)? = nil) : List(T) forall T
      body = JSON.build do |json|
        json.object do
          json.field("offset", offset) if offset
          json.field("limit", limit) if limit
          json.field("fields") { fields.to_json(json) } if fields
          json.field("ids") { ids.to_json(json) } if ids
          json.field("filter", filter) if filter
          json.field("sort") { sort.to_json(json) } if sort
        end
      end
      response(client.post("#{index_path(uid)}/documents/fetch", body), as: List(T))
    end

    def delete(uid : String, id : String | Int32 | Int64) : TaskResult
      response(client.delete("#{index_path(uid)}/documents/#{URI.encode_path_segment(id.to_s)}"), as: TaskResult)
    end

    def delete(uid : String, ids : Enumerable) : TaskResult
      response(client.post("#{index_path(uid)}/documents/delete-batch", ids.to_json), as: TaskResult)
    end

    def delete(uid : String, *, filter : String) : TaskResult
      response(client.post("#{index_path(uid)}/documents/delete", {filter: filter}.to_json), as: TaskResult)
    end

    def delete_all(uid : String) : TaskResult
      response(client.delete("#{index_path(uid)}/documents"), as: TaskResult)
    end

    private def stream(uid : String, documents : Enumerable, primary_key : String?, patch : Bool) : TaskResult
      reader, writer = IO.pipe
      spawn do
        begin
          documents.each do |document|
            document.to_json(writer)
            writer << '\n'
          end
        ensure
          writer.close
        end
      end

      headers = HTTP::Headers{"Content-Type" => "application/x-ndjson"}
      http_response = if patch
                        client.put(documents_path(uid, primary_key), reader, headers)
                      else
                        client.post(documents_path(uid, primary_key), reader, headers)
                      end
      response(http_response, as: TaskResult)
    ensure
      reader.try &.close
    end

    private def await_success(result : TaskResult, timeout : Time::Span?, poll_interval : Time::Span) : BasicTask
      task = client.wait_for_task(result, timeout: timeout, poll_interval: poll_interval)
      return task if task.succeeded?

      raise TaskUnsuccessful.new("Task #{task.uid} finished with status #{task.status}")
    end

    private def documents_path(uid : String, primary_key : String?) : String
      path = "#{index_path(uid)}/documents"
      primary_key ? "#{path}?primaryKey=#{URI.encode_www_form(primary_key)}" : path
    end

    private def index_path(uid : String) : String
      "/indexes/#{URI.encode_path_segment(uid)}"
    end
  end
end
