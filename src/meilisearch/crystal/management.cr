require "base64"
require "openssl/hmac"

module Meilisearch::Crystal
  # A Meilisearch API key and its permissions.
  struct Key < Resource
    field uid : String
    field name : String?
    field description : String?
    field key : String
    field actions : Array(String)
    field indexes : Array(String)
    @[JSON::Field(key: "expiresAt", converter: TaskTimeConverter)]
    getter expires_at : Time?
    @[JSON::Field(key: "createdAt", converter: TaskTimeConverter)]
    getter created_at : Time
    @[JSON::Field(key: "updatedAt", converter: TaskTimeConverter)]
    getter updated_at : Time
  end

  # API-key lifecycle operations.
  class Keys < API
    def list(offset : Int32? = nil, limit : Int32? = nil) : List(Key)
      query = HTTP::Params.new
      query["offset"] = offset.to_s if offset
      query["limit"] = limit.to_s if limit
      response(client.get("/keys", query.empty? ? nil : query), as: List(Key))
    end

    def get(uid : String) : Key
      response(client.get(key_path(uid)), as: Key)
    end

    def get?(uid : String) : Key?
      get(uid)
    rescue error : ApiError
      return if error.code == Error::Code::APIKeyNotFound
      raise error
    end

    def create(actions : Array(String), indexes : Array(String),
               expires_at : Time? = nil, name : String? = nil,
               description : String? = nil, uid : String? = nil) : Key
      body = JSON.build do |json|
        json.object do
          json.field("actions", actions)
          json.field("indexes", indexes)
          json.field("expiresAt", expires_at.try { |time| Time::Format::RFC_3339.format(time) })
          json.field("name", name) if name
          json.field("description", description) if description
          json.field("uid", uid) if uid
        end
      end
      response(client.post("/keys", body), as: Key)
    end

    def update(uid : String, name : String? = nil, description : String? = nil) : Key
      body = JSON.build do |json|
        json.object do
          json.field("name", name) if name
          json.field("description", description) if description
        end
      end
      response(client.patch(key_path(uid), body), as: Key)
    end

    def delete(uid : String) : Nil
      response(client.delete(key_path(uid)), as: Nil)
    end

    private def key_path(uid : String) : String
      "/keys/#{URI.encode_path_segment(uid)}"
    end
  end

  # Server health response.
  struct Health < Resource
    field status : String
  end

  # Server build and package version response.
  struct Version < Resource
    field commit_sha : String
    field commit_date : String
    field pkg_version : String
  end

  # Server-wide database and per-index statistics.
  struct Stats < Resource
    field database_size : Int64
    field used_database_size : Int64?
    field last_update : Time?
    field indexes : Hash(String, Index::Stats)
  end

  # Health, version, statistics, dump, and snapshot operations.
  class Management < API
    def health : Health
      response(client.get("/health"), as: Health)
    end

    def version : Version
      response(client.get("/version"), as: Version)
    end

    def stats : Stats
      response(client.get("/stats"), as: Stats)
    end

    def index_stats(uid : String) : Index::Stats
      response(client.get("/indexes/#{URI.encode_path_segment(uid)}/stats"), as: Index::Stats)
    end

    def create_dump : TaskResult
      response(client.post("/dumps"), as: TaskResult)
    end

    def create_snapshot : TaskResult
      response(client.post("/snapshots"), as: TaskResult)
    end
  end

  # Generates HS256 tenant tokens for scoped search access.
  module TenantToken
    extend self

    def generate(api_key : String, api_key_uid : String, search_rules,
                 expires_at : Time? = nil) : String
      header = {alg: "HS256", typ: "JWT"}.to_json
      payload = JSON.build do |json|
        json.object do
          json.field("apiKeyUid", api_key_uid)
          json.field("searchRules") { search_rules.to_json(json) }
          json.field("exp", expires_at.to_unix) if expires_at
        end
      end
      encoded = "#{encode(header)}.#{encode(payload)}"
      signature = OpenSSL::HMAC.digest(OpenSSL::Algorithm::SHA256, api_key, encoded)
      "#{encoded}.#{encode(signature)}"
    end

    private def encode(value : String | Bytes) : String
      Base64.urlsafe_encode(value, padding: false)
    end
  end
end
