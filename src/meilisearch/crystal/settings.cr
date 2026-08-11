# Typed index settings and settings endpoints.
module Meilisearch::Crystal
  enum PrefixSearch
    IndexingTime
    Disabled
  end

  enum ProximityPrecision
    ByWord
    ByAttribute
  end

  enum EmbedderSource
    OpenAi
    HuggingFace
    Ollama
    Rest
    UserProvided
  end

  struct TypoWordSize < Resource
    field one_typo : Int32
    field two_typos : Int32
  end

  struct TypoTolerance < Resource
    field enabled : Bool
    field min_word_size_for_typos : TypoWordSize
    field disable_on_words : Array(String)
    field disable_on_attributes : Array(String)
    field disable_on_numbers : Bool?
  end

  struct Faceting < Resource
    field max_values_per_facet : Int32
    field sort_facet_values_by : Hash(String, String)
  end

  struct Pagination < Resource
    field max_total_hits : Int32
  end

  struct LocalizedAttribute < Resource
    field locales : Array(String)
    field attribute_patterns : Array(String)
  end

  struct Embedder < Resource
    @[JSON::Field(converter: Meilisearch::Crystal::LowerCamelEnumConverter(Meilisearch::Crystal::EmbedderSource))]
    getter source : EmbedderSource
    field model : String?
    field revision : String?
    field document_template : String?
    field document_template_max_bytes : Int32?
    field dimensions : Int32?
    field url : String?
    field api_key : String?
    field request : JSON::Any?
    field response : JSON::Any?
    field headers : Hash(String, String)?
    field pooling : String?

    def initialize(@source : EmbedderSource,
                   @model : String? = nil,
                   @revision : String? = nil,
                   @document_template : String? = nil,
                   @document_template_max_bytes : Int32? = nil,
                   @dimensions : Int32? = nil,
                   @url : String? = nil,
                   @api_key : String? = nil,
                   @request : JSON::Any? = nil,
                   @response : JSON::Any? = nil,
                   @headers : Hash(String, String)? = nil,
                   @pooling : String? = nil)
    end
  end

  # Complete typed settings response and partial update payload.
  struct Settings < Resource
    field displayed_attributes : Array(String)?
    field searchable_attributes : Array(String)?
    field filterable_attributes : Array(String)?
    field sortable_attributes : Array(String)?
    field ranking_rules : Array(String)?
    field stop_words : Array(String)?
    field non_separator_tokens : Array(String)?
    field separator_tokens : Array(String)?
    field dictionary : Array(String)?
    field synonyms : Hash(String, Array(String))?
    field distinct_attribute : String?
    field typo_tolerance : TypoTolerance?
    field faceting : Faceting?
    field pagination : Pagination?
    @[JSON::Field(key: "proximityPrecision", converter: Meilisearch::Crystal::LowerCamelEnumConverter(Meilisearch::Crystal::ProximityPrecision))]
    getter proximity_precision : ProximityPrecision?
    field embedders : Hash(String, Embedder)?
    field search_cutoff_ms : Int64?
    field localized_attributes : Array(LocalizedAttribute)?
    field facet_search : Bool?
    @[JSON::Field(key: "prefixSearch", converter: Meilisearch::Crystal::LowerCamelEnumConverter(Meilisearch::Crystal::PrefixSearch))]
    getter prefix_search : PrefixSearch?

    def initialize(@displayed_attributes : Array(String)? = nil,
                   @searchable_attributes : Array(String)? = nil,
                   @filterable_attributes : Array(String)? = nil,
                   @sortable_attributes : Array(String)? = nil,
                   @ranking_rules : Array(String)? = nil,
                   @stop_words : Array(String)? = nil,
                   @non_separator_tokens : Array(String)? = nil,
                   @separator_tokens : Array(String)? = nil,
                   @dictionary : Array(String)? = nil,
                   @synonyms : Hash(String, Array(String))? = nil,
                   @distinct_attribute : String? = nil,
                   @typo_tolerance : TypoTolerance? = nil,
                   @faceting : Faceting? = nil,
                   @pagination : Pagination? = nil,
                   @proximity_precision : ProximityPrecision? = nil,
                   @embedders : Hash(String, Embedder)? = nil,
                   @search_cutoff_ms : Int64? = nil,
                   @localized_attributes : Array(LocalizedAttribute)? = nil,
                   @facet_search : Bool? = nil,
                   @prefix_search : PrefixSearch? = nil)
    end
  end

  class SettingsAPI < API
    def get(uid : String) : Settings
      response(client.get(settings_path(uid)), as: Settings)
    end

    def update(uid : String, settings : Settings) : TaskResult
      response(client.patch(settings_path(uid), settings.to_json), as: TaskResult)
    end

    def reset(uid : String) : TaskResult
      response(client.delete(settings_path(uid)), as: TaskResult)
    end

    macro setting(name, path, type)
      def {{ name.id }}(uid : String) : {{ type }}
        response(client.get(settings_path(uid) + "/" + {{ path }}), as: {{ type }})
      end

      def reset_{{ name.id }}(uid : String) : TaskResult
        response(client.delete(settings_path(uid) + "/" + {{ path }}), as: TaskResult)
      end
    end

    setting displayed_attributes, "displayed-attributes", Array(String)
    setting searchable_attributes, "searchable-attributes", Array(String)
    setting filterable_attributes, "filterable-attributes", Array(String)
    setting sortable_attributes, "sortable-attributes", Array(String)
    setting ranking_rules, "ranking-rules", Array(String)
    setting stop_words, "stop-words", Array(String)
    setting non_separator_tokens, "non-separator-tokens", Array(String)
    setting separator_tokens, "separator-tokens", Array(String)
    setting dictionary, "dictionary", Array(String)
    setting synonyms, "synonyms", Hash(String, Array(String))
    setting distinct_attribute, "distinct-attribute", String?
    setting typo_tolerance, "typo-tolerance", TypoTolerance
    setting faceting, "faceting", Faceting
    setting pagination, "pagination", Pagination
    setting proximity_precision, "proximity-precision", ProximityPrecision
    setting embedders, "embedders", Hash(String, Embedder)
    setting search_cutoff_ms, "search-cutoff-ms", Int64?
    setting localized_attributes, "localized-attributes", Array(LocalizedAttribute)
    setting facet_search, "facet-search", Bool
    setting prefix_search, "prefix-search", PrefixSearch

    private def settings_path(uid : String) : String
      "/indexes/#{URI.encode_path_segment(uid)}/settings"
    end
  end
end
