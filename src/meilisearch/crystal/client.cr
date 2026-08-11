# The Meilisearch client: configuration, HTTP transport, and task waiting.
#
# ```
# client = Meilisearch::Crystal::Client.new(
#   url: "http://localhost:7700",
#   api_key: "masterKey"
# )
# ```
require "http/client"
require "./task"

module Meilisearch::Crystal
  # Manages a connection to a Meilisearch server and provides the typed
  # request plumbing shared by all resource classes.
  class Client
    USER_AGENT = "meilisearch-crystal/#{VERSION}"

    # Environment variables consulted when `Client.new` is called without
    # explicit arguments.
    ENV_URL     = "MEILISEARCH_URL"
    ENV_API_KEY = "MEILISEARCH_API_KEY"

    DEFAULT_URL     = "http://localhost:7700"
    DEFAULT_TIMEOUT = 5.seconds

    getter url : URI
    getter api_key : String?
    getter timeout : Time::Span
    getter http : HTTP::Client

    # Builds a client against `url` with optional `api_key` and `timeout`.
    #
    # When `url`/`api_key` are omitted, environment variables
    # (`MEILISEARCH_URL`, `MEILISEARCH_API_KEY`) are consulted; `timeout`
    # defaults to 5 seconds.
    def initialize(url : String | URI? = nil, api_key : String? = nil, timeout : Time::Span? = nil)
      @url = Client.resolve_url(url || ENV[ENV_URL]? || DEFAULT_URL)
      @api_key = api_key || ENV[ENV_API_KEY]?
      @timeout = timeout || DEFAULT_TIMEOUT
      @http = build_http_client
    end

    # Handle for index-scoped operations (search, documents, settings, ...).
    # The returned `IndexClient` binds `uid` to this client.
    def index(uid : String) : IndexClient
      IndexClient.new(self, uid)
    end

    # Index lifecycle operations and typed metadata access.
    def indexes : Indexes
      Indexes.new(self)
    end

    # Task lookup and listing operations.
    def tasks : Tasks
      Tasks.new(self)
    end

    # Search, facet, similar-document, and multi-index operations.
    def search : Search
      Search.new(self)
    end

    # Index settings operations.
    def settings : SettingsAPI
      SettingsAPI.new(self)
    end

    def keys : Keys
      Keys.new(self)
    end

    def batches : Batches
      Batches.new(self)
    end

    def experimental_features : ExperimentalFeaturesAPI
      ExperimentalFeaturesAPI.new(self)
    end

    def network : Network
      Network.new(self)
    end

    def health : Health
      Management.new(self).health
    end

    def version : Version
      Management.new(self).version
    end

    def stats : Stats
      Management.new(self).stats
    end

    def create_dump : TaskResult
      Management.new(self).create_dump
    end

    def create_snapshot : TaskResult
      Management.new(self).create_snapshot
    end

    def generate_tenant_token(api_key_uid : String, search_rules,
                              expires_at : Time? = nil,
                              api_key : String? = @api_key) : String
      secret = api_key || raise MissingValue.new("An API key is required to sign a tenant token")
      TenantToken.generate(secret, api_key_uid, search_rules, expires_at)
    end

    # Fetches a task by uid, polling until it reaches a terminal status
    # (succeeded / failed / canceled). Raises `TimeoutError` when the task
    # does not complete within the client's timeout.
    #
    # ```
    # task = client.wait_for_task(task_uid, poll_interval: 50.milliseconds)
    # ```
    def wait_for_task(uid : Int32 | Int64,
                      timeout : Time::Span? = nil,
                      poll_interval : Time::Span = 100.milliseconds) : BasicTask
      deadline = Time.instant + (timeout || @timeout)
      loop do
        task = Tasks.new(self).get(uid)
        case task.status
        when BasicTask::Status::Succeeded,
             BasicTask::Status::Failed,
             BasicTask::Status::Canceled
          return task
        end
        raise TimeoutError.new("timed out waiting for task #{uid}") if Time.instant >= deadline
        sleep(poll_interval)
      end
    end

    def wait_for_task(task : BasicTask,
                      timeout : Time::Span? = nil,
                      poll_interval : Time::Span = 100.milliseconds) : BasicTask
      wait_for_task(task.uid, timeout: timeout, poll_interval: poll_interval)
    end

    def wait_for_task(task : TaskResult,
                      timeout : Time::Span? = nil,
                      poll_interval : Time::Span = 100.milliseconds) : BasicTask
      uid = task.task_uid || raise MissingValue.new("Task result does not contain a task uid")
      wait_for_task(uid, timeout: timeout, poll_interval: poll_interval)
    end

    # -- HTTP transport ----------------------------------------------------

    # Builds an `HTTP::Client` bound to this client's URL, with authentication,
    # accept, and user-agent headers injected.
    def build_http_client : HTTP::Client
      http = HTTP::Client.new(@url)
      http.connect_timeout = @timeout
      http.read_timeout = @timeout
      http.before_request do |request|
        api_key = @api_key
        request.headers["Authorization"] = "Bearer #{api_key}" if api_key
        request.headers["Accept"] = "application/json"
        request.headers["User-Agent"] = USER_AGENT
        unless request.method.in?("GET", "HEAD") || request.headers.has_key?("Content-Type")
          request.headers["Content-Type"] = "application/json"
        end
      end
      http
    end

    # Builds an absolute request path from a relative one, preserving query
    # params passed separately.
    private def full_path(path : String, query : HTTP::Params? = nil) : String
      return path unless query
      "#{path}?#{query}"
    end

    # -- request plumbing --------------------------------------------------

    def get(path : String, query : HTTP::Params? = nil) : HTTP::Client::Response
      @http.get(full_path(path, query))
    rescue error : IO::TimeoutError
      raise TimeoutError.new(error.message || "Meilisearch request timed out", cause: error)
    rescue error : IO::Error
      raise CommunicationError.new(error.message || "Could not communicate with Meilisearch", cause: error)
    end

    def post(path : String, body : HTTP::Client::BodyType = nil, headers : HTTP::Headers? = nil) : HTTP::Client::Response
      @http.post(full_path(path), headers, body)
    rescue error : IO::TimeoutError
      raise TimeoutError.new(error.message || "Meilisearch request timed out", cause: error)
    rescue error : IO::Error
      raise CommunicationError.new(error.message || "Could not communicate with Meilisearch", cause: error)
    end

    def put(path : String, body : HTTP::Client::BodyType = nil, headers : HTTP::Headers? = nil) : HTTP::Client::Response
      @http.put(full_path(path), headers, body)
    rescue error : IO::TimeoutError
      raise TimeoutError.new(error.message || "Meilisearch request timed out", cause: error)
    rescue error : IO::Error
      raise CommunicationError.new(error.message || "Could not communicate with Meilisearch", cause: error)
    end

    def patch(path : String, body : String = "", headers : HTTP::Headers? = nil) : HTTP::Client::Response
      @http.patch(full_path(path), headers, body)
    rescue error : IO::TimeoutError
      raise TimeoutError.new(error.message || "Meilisearch request timed out", cause: error)
    rescue error : IO::Error
      raise CommunicationError.new(error.message || "Could not communicate with Meilisearch", cause: error)
    end

    def delete(path : String, query : HTTP::Params? = nil) : HTTP::Client::Response
      @http.delete(full_path(path, query))
    rescue error : IO::TimeoutError
      raise TimeoutError.new(error.message || "Meilisearch request timed out", cause: error)
    rescue error : IO::Error
      raise CommunicationError.new(error.message || "Could not communicate with Meilisearch", cause: error)
    end

    # Closes the underlying persistent HTTP connection.
    def close : Nil
      @http.close
    end

    def self.resolve_url(url : String | URI) : URI
      uri = url.is_a?(URI) ? url : URI.parse(url)
      unless uri.scheme && uri.host
        raise ArgumentError.new("Meilisearch URL must include a scheme and host (e.g. http://localhost:7700)")
      end
      uri
    end
  end
end
