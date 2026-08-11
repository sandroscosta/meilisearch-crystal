# Batch, experimental-feature, and network administration APIs.
module Meilisearch::Crystal
  # A group of tasks processed together by Meilisearch.
  struct Batch < Resource
    field uid : Int64
    field progress : JSON::Any?
    field details : JSON::Any
    field stats : JSON::Any
    @[JSON::Field(converter: DurationConverter)]
    getter duration : Time::Span?
    @[JSON::Field(key: "startedAt", converter: TaskTimeConverter)]
    getter started_at : Time?
    @[JSON::Field(key: "finishedAt", converter: TaskTimeConverter)]
    getter finished_at : Time?
    field batch_strategy : String?
  end

  # Batch lookup and cursor-paginated listing operations.
  class Batches < API
    def get(uid : Int32 | Int64) : Batch
      response(client.get("/batches/#{uid}"), as: Batch)
    end

    def get?(uid : Int32 | Int64) : Batch?
      get(uid)
    rescue error : ApiError
      return if error.code == Error::Code::BatchNotFound

      raise error
    end

    def list(limit : Int32? = nil, from : Int64? = nil, reverse : Bool? = nil) : List(Batch)
      query = HTTP::Params.new
      query["limit"] = limit.to_s if limit
      query["from"] = from.to_s if from
      query["reverse"] = reverse.to_s unless reverse.nil?
      response(client.get("/batches", query.empty? ? nil : query), as: List(Batch))
    end
  end

  # Feature flags exposed by Meilisearch v1.53's experimental-features API.
  struct ExperimentalFeatures < Resource
    field? metrics : Bool
    field? logs_route : Bool
    field? tasks_streaming_route : Bool
    field? edit_documents_by_function : Bool
    field? contains_filter : Bool
    field? dynamic_search_rules : Bool
    field? network : Bool
    field? get_task_documents_route : Bool
    field? task_queue_compaction_route : Bool
    field? composite_embedders : Bool
    field? chat_completions : Bool
    field? multimodal : Bool
    field? foreign_keys : Bool
    field? disable_documents_fetch_queue : Bool
    field? legacy_search : Bool
    field? render_route : Bool
  end

  # A partial update for experimental feature flags.
  struct ExperimentalFeaturesPatch
    include JSON::Serializable

    property metrics : Bool?
    @[JSON::Field(key: "logsRoute")]
    property logs_route : Bool?
    @[JSON::Field(key: "tasksStreamingRoute")]
    property tasks_streaming_route : Bool?
    @[JSON::Field(key: "editDocumentsByFunction")]
    property edit_documents_by_function : Bool?
    @[JSON::Field(key: "containsFilter")]
    property contains_filter : Bool?
    @[JSON::Field(key: "dynamicSearchRules")]
    property dynamic_search_rules : Bool?
    property network : Bool?
    @[JSON::Field(key: "getTaskDocumentsRoute")]
    property get_task_documents_route : Bool?
    @[JSON::Field(key: "taskQueueCompactionRoute")]
    property task_queue_compaction_route : Bool?
    @[JSON::Field(key: "compositeEmbedders")]
    property composite_embedders : Bool?
    @[JSON::Field(key: "chatCompletions")]
    property chat_completions : Bool?
    property multimodal : Bool?
    @[JSON::Field(key: "foreignKeys")]
    property foreign_keys : Bool?
    @[JSON::Field(key: "disableDocumentsFetchQueue")]
    property disable_documents_fetch_queue : Bool?
    @[JSON::Field(key: "legacySearch")]
    property legacy_search : Bool?
    @[JSON::Field(key: "renderRoute")]
    property render_route : Bool?

    def initialize(@metrics = nil, @logs_route = nil, @tasks_streaming_route = nil,
                   @edit_documents_by_function = nil, @contains_filter = nil,
                   @dynamic_search_rules = nil, @network = nil,
                   @get_task_documents_route = nil, @task_queue_compaction_route = nil,
                   @composite_embedders = nil, @chat_completions = nil,
                   @multimodal = nil, @foreign_keys = nil,
                   @disable_documents_fetch_queue = nil, @legacy_search = nil,
                   @render_route = nil)
    end
  end

  # Experimental feature administration.
  class ExperimentalFeaturesAPI < API
    def get : ExperimentalFeatures
      response(client.get("/experimental-features"), as: ExperimentalFeatures)
    end

    def update(features : ExperimentalFeaturesPatch) : ExperimentalFeatures
      response(client.patch("/experimental-features", features.to_json, json_headers), as: ExperimentalFeatures)
    end
  end

  # Network topology configuration. Nested remote and shard schemas remain
  # JSON values because they are explicitly experimental and evolve rapidly.
  struct NetworkConfig < Resource
    field self : String?
    field remotes : Hash(String, JSON::Any)
    field shards : Hash(String, JSON::Any)
    field leader : String?
    field version : String
  end

  # Experimental network topology reads and updates.
  class Network < API
    def get : NetworkConfig
      response(client.get("/network"), as: NetworkConfig)
    end

    def update(config : Hash(String, JSON::Any)) : NetworkConfig
      response(client.patch("/network", config.to_json, json_headers), as: NetworkConfig)
    end
  end
end
