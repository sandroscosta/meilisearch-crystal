# Base class for typed resource endpoints.
#
# A resource wraps the `Client` and exposes the shared response handling:
# 2xx bodies deserialize into the requested type, non-2xx bodies raise a
# typed `Error` parsed from the Meilisearch error envelope.
module Meilisearch::Crystal
  # Base class shared by all endpoint-specific API clients.
  abstract class API
    getter client : Client
    delegate http, to: @client

    def initialize(@client : Client)
    end

    # Deserializes a response into `T`, raising a typed `ApiError` (carrying
    # the parsed `Error` envelope) for non-2xx responses.
    private def response(response : HTTP::Client::Response, as type : T.class) forall T
      body = response.body
      unless response.success?
        raise ApiError.new(Error.from_json(body))
      end

      if body.empty?
        return T.from_json("null")
      end

      T.from_json(body)
    end

    # The default headers for JSON request bodies.
    private def json_headers
      HTTP::Headers{"Content-Type" => "application/json"}
    end

    # Defines thin forwarding methods to the underlying client.
    macro pass(*methods)
      {% for method in methods %}
        def {{ method.id }}(*args, **options)
          client.{{ method.id }}(*args, **options)
        end
      {% end %}
    end
  end
end
