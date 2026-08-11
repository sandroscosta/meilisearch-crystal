# Library-level exception hierarchy.
#
# These exceptions represent failures *of the client itself* (transport,
# waiting, value access) and are deliberately distinct from
# `Meilisearch::Crystal::Error`, which models a typed error returned by the
# server in a non-2xx response body.
module Meilisearch::Crystal
  # Base class for all client-raised exceptions.
  class Exception < ::Exception
  end

  # Raised when the Meilisearch instance is unreachable (connection refused,
  # DNS failure, socket error).
  class CommunicationError < Exception
  end

  # Raised when a request or task wait exceeds the configured timeout.
  class TimeoutError < Exception
  end

  # Raised when a task being awaited reaches a terminal failed/canceled state.
  class TaskUnsuccessful < Exception
  end

  # Raised when accessing a nilable field that is absent.
  class MissingValue < Exception
  end
end
