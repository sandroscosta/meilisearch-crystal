# Typed index metadata and index-scoped response shapes.
module Meilisearch::Crystal
  struct Index < Resource
    field uid : String
    field primary_key : String?
    field created_at : Time
    field updated_at : Time

    # Shape returned by the index stats endpoint.
    struct Stats < Resource
      field number_of_documents : Int64
      field is_indexing : Bool
      field field_distribution : Hash(String, Int64)
      field raw_document_db_size : Int64?
      field avg_document_size : Int64?
      field number_of_embeddings : Int64?
      field number_of_embedded_documents : Int64?
    end

    # Core settings shape embedded in index-related responses. The complete
    # settings model extends this surface in the settings resource.
    struct Settings < Resource
      field displayed_attributes : Array(String)?
      field searchable_attributes : Array(String)?
      field filterable_attributes : Array(String)?
      field sortable_attributes : Array(String)?
      field ranking_rules : Array(String)?
      field stop_words : Array(String)?
      field synonyms : Hash(String, Array(String))?
      field distinct_attribute : String?
    end
  end
end
