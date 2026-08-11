# Parsed Meilisearch error envelope.
#
# Meilisearch reports API errors as a JSON body of the form
#
# ```
# {"message": "Index `movies` not found.", "code": "index_not_found", "type": "invalid_request", "link": "https://docs.meilisearch.com/errors#index_not_found"}
# ```
#
# `Error` parses that envelope into typed fields. The `code` field is a typed
# enum covering the documented Meilisearch error catalog; codes the server
# sends that are not (yet) in the catalog parse to `Code::Unknown` so error
# handling survives server upgrades.
require "json"
require "uri/json"

module Meilisearch::Crystal
  struct Error
    include JSON::Serializable

    getter message : String
    @[JSON::Field(converter: CodeConverter)]
    getter code : Code
    getter type : String
    getter link : URI

    # Converts the `code` JSON string to its enum value. Unknown strings map
    # to `Code::Unknown` instead of raising.
    module CodeConverter
      extend self

      def from_json(pull : JSON::PullParser) : Code
        Code.parse?(pull.read_string) || Code::Unknown
      end

      def to_json(value : Code, json : JSON::Builder)
        json.string(value.to_s.camelcase(lower: true))
      end
    end

    # JSON::Serializable's generated `to_json` fails to resolve converters on
    # the installed Crystal toolchain (1.20.3), so we serialize the code field
    # manually via the converter. The client only ever *parses* error
    # envelopes; serialization exists for completeness/tests.
    def to_json(json : JSON::Builder)
      json.object do
        json.field("message", message)
        json.field("code") { CodeConverter.to_json(code, json) }
        json.field("type", type)
        json.field("link", link)
      end
    end

    # All documented Meilisearch error codes.
    #
    # Transcribed from the Meilisearch error reference and cross-checked
    # against jgaskins/meilisearch (MIT). Grouped by concern for readability;
    # parsing is by name, so order is not significant.
    enum Code
      # ---- API keys ----
      APIKeyAlreadyExists
      APIKeyNotFound
      ImmutableAPIKeyActions
      ImmutableAPIKeyCreatedAt
      ImmutableAPIKeyExpiresAt
      ImmutableAPIKeyIndexes
      ImmutableAPIKeyKey
      ImmutableAPIKeyUid
      ImmutableAPIKeyUpdatedAt
      InvalidAPIKey
      InvalidAPIKeyActions
      InvalidAPIKeyDescription
      InvalidAPIKeyExpiresAt
      InvalidAPIKeyIndexes
      InvalidAPIKeyLimit
      InvalidAPIKeyName
      InvalidAPIKeyOffset
      InvalidAPIKeyUid
      MissingAPIKeyActions
      MissingAPIKeyExpiresAt
      MissingAPIKeyIndexes

      # ---- indexes ----
      IndexAlreadyExists
      IndexCreationFailed
      IndexNotFound
      IndexPrimaryKeyAlreadyExists
      IndexPrimaryKeyMultipleCandidatesFound
      InvalidIndexLimit
      InvalidIndexOffset
      InvalidIndexUid
      InvalidIndexPrimaryKey
      IndexPrimaryKeyNoCandidateFound
      MissingIndexUid

      # ---- documents / payload / environment ----
      DocumentFieldsLimitReached
      DocumentNotFound
      InvalidDocumentCsvDelimiter
      InvalidDocumentId
      InvalidDocumentFields
      InvalidDocumentFilter
      InvalidDocumentLimit
      InvalidDocumentOffset
      InvalidDocumentSort
      InvalidDocumentGeoField
      IoError
      MalformedPayload
      MissingAuthorizationHeader
      MissingContentType
      MissingDocumentFilter
      MissingDocumentId
      MissingFacetSearchFacetName
      MissingMasterKey
      MissingNetworkUrl
      MissingPayload
      MissingSwapIndexes
      MissingTaskFilters
      NoSpaceLeftOnDevice
      TooManyOpenFiles
      TooManySearchRequests
      UnretrievableDocument

      # ---- tasks ----
      InvalidTaskAfterEnqueuedAt
      InvalidTaskAfterFinishedAt
      InvalidTaskAfterStartedAt
      InvalidTaskBeforeEnqueuedAt
      InvalidTaskBeforeFinishedAt
      InvalidTaskBeforeStartedAt
      InvalidTaskCanceledBy
      InvalidTaskIndexUids
      InvalidTaskLimit
      InvalidTaskStatuses
      InvalidTaskTypes
      InvalidTaskUids
      TaskNotFound

      # ---- settings & search ----
      InvalidSearchAttributesToSearchOn
      InvalidSearchAttributesToCrop
      InvalidSearchAttributesToHighlight
      InvalidSearchAttributesToRetrieve
      InvalidSearchCropLength
      InvalidSearchCropMarker
      InvalidSearchEmbedder
      InvalidSearchFacets
      InvalidSearchFilter
      InvalidSearchHighlightPostTag
      InvalidSearchHighlightPreTag
      InvalidSearchHitsPerPage
      InvalidSearchHybridQuery
      InvalidSearchLimit
      InvalidSearchLocales
      InvalidSettingsEmbedder
      InvalidSettingsEmbedders
      InvalidSettingsFacetSearch
      InvalidSettingsLocalizedAttributes
      InvalidSearchMatchingStrategy
      InvalidSearchOffset
      InvalidSettingsPrefixSearch
      InvalidSearchPage
      InvalidSearchQ
      InvalidSearchRankingScoreThreshold
      InvalidSearchShowMatchesPosition
      InvalidSearchSort
      InvalidSettingsDisplayedAttributes
      InvalidSettingsDistinctAttribute
      InvalidSettingsFacetingSortFacetValuesBy
      InvalidSettingsFacetingMaxValuesPerFacet
      InvalidSettingsFilterableAttributes
      InvalidSettingsPagination
      InvalidSettingsRankingRules
      InvalidSettingsSearchableAttributes
      InvalidSettingsSearchCutoffMs
      InvalidSettingsSortableAttributes
      InvalidSettingsStopWords
      InvalidSettingsSynonyms
      InvalidSettingsTypoTolerance

      # ---- facet search ----
      InvalidFacetSearchFacetName
      InvalidFacetSearchFacetQuery

      # ---- similar documents ----
      InvalidSimilarId
      NotFoundSimilarId
      InvalidSimilarAttributesToRetrieve
      InvalidSimilarEmbedder
      InvalidSimilarFilter
      InvalidSimilarLimit
      InvalidSimilarOffset
      InvalidSimilarShowRankingScore
      InvalidSimilarShowRankingScoreDetails
      InvalidSimilarRankingScoreThreshold

      # ---- index swaps ----
      InvalidSwapDuplicateIndexFound
      InvalidSwapIndexes

      # ---- multi-search / federation / remote ----
      InvalidMultiSearchQueryFederated
      InvalidMultiSearchQueryPagination
      InvalidMultiSearchQueryPosition
      InvalidMultiSearchWeight
      InvalidMultiSearchQueriesRankingRules
      InvalidMultiSearchFacets
      InvalidMultiSearchSortFacetValuesBy
      InvalidMultiSearchQueryFacets
      InvalidMultiSearchMergeFacets
      InvalidMultiSearchMaxValuesPerFacet
      InvalidMultiSearchFacetOrder
      InvalidMultiSearchFacetsByIndex
      InvalidMultiSearchRemote
      InvalidNetworkSelf
      InvalidNetworkRemotes
      InvalidNetworkUrl
      InvalidNetworkSearchAPIKey
      RemoteBadResponse
      RemoteBadRequest
      RemoteCouldNotSendRequest
      RemoteInvalidAPIKey
      RemoteRemoteError
      RemoteTimeout

      # ---- embeddings ----
      VectorEmbeddingError

      # ---- general ----
      BadRequest
      BatchNotFound
      DatabaseSizeLimitReached
      DumpProcessFailed
      FacetSearchDisabled
      FeatureNotEnabled
      ImmutableIndexUid
      ImmutableIndexUpdatedAt
      Internal
      InvalidContentType
      InvalidState
      InvalidStoreFile
      NotFound
      PayloadTooLarge

      # ---- fallback for undocumented codes ----
      Unknown
    end
  end
end
