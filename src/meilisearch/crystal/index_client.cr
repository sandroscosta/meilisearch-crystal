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
  end
end
