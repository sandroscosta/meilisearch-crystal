# Typed search models and endpoints.
module Meilisearch::Crystal
  enum MatchingStrategy
    Last
    All
    Frequency
  end

  struct Hybrid < Resource
    field embedder : String
    field semantic_ratio : Float64?

    def initialize(@embedder : String, @semantic_ratio : Float64? = nil)
    end
  end

  struct FederationOptions < Resource
    field weight : Float64?
    field remote : String?
    field query_position : Int32?

    def initialize(@weight : Float64? = nil, @remote : String? = nil, @query_position : Int32? = nil)
    end
  end

  # A typed POST-search request. Nil fields are omitted from its JSON body.
  struct Query < Resource
    field index_uid : String?
    field q : String?
    field offset : Int32?
    field limit : Int32?
    field page : Int32?
    field hits_per_page : Int32?
    field filter : String | Array(String) | Nil
    field facets : Array(String)?
    field attributes_to_retrieve : Array(String)?
    field attributes_to_crop : Array(String)?
    field crop_length : Int32?
    field crop_marker : String?
    field attributes_to_highlight : Array(String)?
    field highlight_pre_tag : String?
    field highlight_post_tag : String?
    field show_matches_position : Bool?
    field sort : Array(String)?
    @[JSON::Field(key: "matchingStrategy", converter: Meilisearch::Crystal::LowerCamelEnumConverter(Meilisearch::Crystal::MatchingStrategy))]
    getter matching_strategy : MatchingStrategy?
    field show_ranking_score : Bool?
    field show_ranking_score_details : Bool?
    field ranking_score_threshold : Float64?
    field attributes_to_search_on : Array(String)?
    field hybrid : Hybrid?
    field vector : Array(Float64)?
    field retrieve_vectors : Bool?
    field locales : Array(String)?
    field federation_options : FederationOptions?
    field distinct : String?

    def initialize(@q : String? = nil,
                   @index_uid : String? = nil,
                   @offset : Int32? = nil,
                   @limit : Int32? = nil,
                   @page : Int32? = nil,
                   @hits_per_page : Int32? = nil,
                   @filter : String | Array(String) | Nil = nil,
                   @facets : Array(String)? = nil,
                   @attributes_to_retrieve : Array(String)? = nil,
                   @attributes_to_crop : Array(String)? = nil,
                   @crop_length : Int32? = nil,
                   @crop_marker : String? = nil,
                   @attributes_to_highlight : Array(String)? = nil,
                   @highlight_pre_tag : String? = nil,
                   @highlight_post_tag : String? = nil,
                   @show_matches_position : Bool? = nil,
                   @sort : Array(String)? = nil,
                   @matching_strategy : MatchingStrategy? = nil,
                   @show_ranking_score : Bool? = nil,
                   @show_ranking_score_details : Bool? = nil,
                   @ranking_score_threshold : Float64? = nil,
                   @attributes_to_search_on : Array(String)? = nil,
                   @hybrid : Hybrid? = nil,
                   @vector : Array(Float64)? = nil,
                   @retrieve_vectors : Bool? = nil,
                   @locales : Array(String)? = nil,
                   @federation_options : FederationOptions? = nil,
                   @distinct : String? = nil)
    end
  end

  struct FacetStats < Resource
    field min : Float64
    field max : Float64
  end

  struct SearchResponse(T) < Resource
    include Enumerable(T)

    field hits : Array(T)
    field query : String?
    @[JSON::Field(key: "processingTimeMs", converter: SpanMillisecondsConverter)]
    getter processing_time : Time::Span
    field estimated_total_hits : Int64?
    field total_hits : Int64?
    field total_pages : Int32?
    field page : Int32?
    field hits_per_page : Int32?
    field index_uid : String?
    field limit : Int32?
    field offset : Int32?
    field facet_distribution : Hash(String, Hash(String, Int64))?
    field facet_stats : Hash(String, FacetStats)?
    field facets_by_index : Hash(String, JSON::Any)?

    def each(& : T ->) : Nil
      hits.each { |hit| yield hit }
    end
  end

  struct FacetHit < Resource
    field value : String
    field count : Int64
  end

  struct FacetSearchRequest < Resource
    field facet_name : String
    field facet_query : String?
    field q : String?
    field filter : String | Array(String) | Nil
    @[JSON::Field(key: "matchingStrategy", converter: Meilisearch::Crystal::LowerCamelEnumConverter(Meilisearch::Crystal::MatchingStrategy))]
    getter matching_strategy : MatchingStrategy?
    field exhaustive_facet_count : Bool?

    def initialize(@facet_name : String,
                   @facet_query : String? = nil,
                   @q : String? = nil,
                   @filter : String | Array(String) | Nil = nil,
                   @matching_strategy : MatchingStrategy? = nil,
                   @exhaustive_facet_count : Bool? = nil)
    end
  end

  struct FacetSearchResponse < Resource
    field facet_hits : Array(FacetHit)
    field facet_query : String?
    @[JSON::Field(key: "processingTimeMs", converter: SpanMillisecondsConverter)]
    getter processing_time : Time::Span?
  end

  module MultiSearch
    struct Response(T) < Resource
      field results : Array(SearchResponse(T))
    end

    struct Federation < Resource
      field offset : Int32?
      field limit : Int32?
      field page : Int32?
      field hits_per_page : Int32?
      field facets_by_index : Hash(String, Array(String))?
      field merge_facets : Hash(String, JSON::Any)?

      def initialize(@offset : Int32? = nil,
                     @limit : Int32? = nil,
                     @page : Int32? = nil,
                     @hits_per_page : Int32? = nil,
                     @facets_by_index : Hash(String, Array(String))? = nil,
                     @merge_facets : Hash(String, JSON::Any)? = nil)
      end
    end

    struct FederationMetadata < Resource
      field index_uid : String
      field queries_position : Int32
    end

    struct FederatedResult(T)
      getter document : T
      getter federation : FederationMetadata

      def initialize(@document : T, @federation : FederationMetadata)
      end

      def self.new(pull : JSON::PullParser) : self
        from_json(pull.read_raw)
      end

      def self.from_json(source : String | IO) : self
        raw = JSON.parse(source)
        metadata = FederationMetadata.from_json(raw["_federation"].to_json)
        new(T.from_json(raw.to_json), metadata)
      end

      def to_json(json : JSON::Builder) : Nil
        JSON.parse(document.to_json).as_h.merge({"_federation" => JSON.parse(federation.to_json)}).to_json(json)
      end
    end
  end

  class Search < API
    def search(uid : String, query : Query) : SearchResponse(JSON::Any)
      search(uid, query, JSON::Any)
    end

    def search(uid : String, query : Query, as type : T.class) : SearchResponse(T) forall T
      response(client.post(search_path(uid), query.to_json), as: SearchResponse(T))
    end

    def search(uid : String, q : String? = nil) : SearchResponse(JSON::Any)
      search(uid, Query.new(q: q))
    end

    def search(uid : String, q : String?, as type : T.class) : SearchResponse(T) forall T
      search(uid, Query.new(q: q), as: T)
    end

    def facet(uid : String, request : FacetSearchRequest) : FacetSearchResponse
      response(client.post("#{index_path(uid)}/facet-search", request.to_json), as: FacetSearchResponse)
    end

    def similar(uid : String, id : String | Int32 | Int64, embedder : String) : SearchResponse(JSON::Any)
      similar(uid, id, embedder, JSON::Any)
    end

    def similar(uid : String, id : String | Int32 | Int64, embedder : String, as type : T.class) : SearchResponse(T) forall T
      response(client.post("#{index_path(uid)}/similar", {id: id, embedder: embedder}.to_json), as: SearchResponse(T))
    end

    def multi(queries : Array(Query)) : MultiSearch::Response(JSON::Any)
      multi(queries, JSON::Any)
    end

    def multi(queries : Array(Query), as type : T.class) : MultiSearch::Response(T) forall T
      response(client.post("/multi-search", {queries: queries}.to_json), as: MultiSearch::Response(T))
    end

    def federated(queries : Array(Query), federation : MultiSearch::Federation = MultiSearch::Federation.new) : SearchResponse(MultiSearch::FederatedResult(JSON::Any))
      federated(queries, federation, JSON::Any)
    end

    def federated(queries : Array(Query), federation : MultiSearch::Federation, as type : T.class) : SearchResponse(MultiSearch::FederatedResult(T)) forall T
      body = {queries: queries, federation: federation}.to_json
      response(client.post("/multi-search", body), as: SearchResponse(MultiSearch::FederatedResult(T)))
    end

    private def search_path(uid : String) : String
      "#{index_path(uid)}/search"
    end

    private def index_path(uid : String) : String
      "/indexes/#{URI.encode_path_segment(uid)}"
    end
  end
end
