# Index-scoped handle returned by `Client#index(uid)`.
#
# Binds an index uid to the client and will delegate to the
# `Documents` / `Search` / `Settings` resources (filled in as those resources
# land). For now it carries the binding and the metadata snapshot accessor.
module Meilisearch::Crystal
  class IndexClient
    getter client : Client
    getter uid : String

    def initialize(@client : Client, @uid : String)
    end

    # Fetches the current typed metadata snapshot for this index.
    def metadata : Index
      client.indexes.get(uid)
    end

    # Updates the bound index's primary key or uid.
    def update(primary_key : String? = nil, new_uid : String? = nil) : TaskResult
      client.indexes.update(uid, primary_key: primary_key, new_uid: new_uid)
    end

    # Deletes the bound index.
    def delete : TaskResult
      client.indexes.delete(uid)
    end

    # Document operations scoped to this index.
    def documents : Documents
      Documents.new(client)
    end

    # Searches this index with a typed query object.
    def search(query : Query) : SearchResponse(JSON::Any)
      client.search.search(uid, query)
    end

    def search(query : Query, as type : T.class) : SearchResponse(T) forall T
      client.search.search(uid, query, as: T)
    end

    # Searches this index from a query string.
    def search(q : String? = nil) : SearchResponse(JSON::Any)
      client.search.search(uid, q)
    end

    def search(q : String?, as type : T.class) : SearchResponse(T) forall T
      client.search.search(uid, q, as: T)
    end

    def facet_search(request : FacetSearchRequest) : FacetSearchResponse
      client.search.facet(uid, request)
    end

    def similar(id : String | Int32 | Int64, embedder : String) : SearchResponse(JSON::Any)
      client.search.similar(uid, id, embedder)
    end

    def similar(id : String | Int32 | Int64, embedder : String, as type : T.class) : SearchResponse(T) forall T
      client.search.similar(uid, id, embedder, as: T)
    end

    # Fetches this index's current typed settings.
    def settings : Settings
      client.settings.get(uid)
    end

    def update_settings(settings : Settings) : TaskResult
      client.settings.update(uid, settings)
    end

    def reset_settings : TaskResult
      client.settings.reset(uid)
    end

    def tasks(limit : Int32? = nil) : List(Task)
      client.tasks.list(index_uids: [uid], limit: limit)
    end

    def stats : Index::Stats
      Management.new(client).index_stats(uid)
    end

    def with_tenant_token(api_key_uid : String, search_rules,
                          expires_at : Time? = nil,
                          api_key : String? = client.api_key) : IndexClient
      token = client.generate_tenant_token(api_key_uid, search_rules, expires_at, api_key)
      Client.new(url: client.url, api_key: token, timeout: client.timeout).index(uid)
    end
  end
end
