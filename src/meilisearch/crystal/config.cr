# Module-level configuration.
#
# Provides a hand-rolled substitute for a Habitat-style settings block: the
# library stays dependency-free and the settings act purely as *defaults* for
# `Client.new`. The library is usable entirely without this module-level
# configuration (construct `Client.new` explicitly) — see `Meilisearch::Crystal::Client`.
module Meilisearch::Crystal
  # Defaults consumed by `Meilisearch::Crystal.client`.
  #
  # ```
  # Meilisearch::Crystal.configure do |settings|
  #   settings.url = "http://localhost:7700"
  #   settings.api_key = "masterKey"
  #   settings.timeout = 10.seconds
  # end
  # ```
  class Settings
    property url : String?
    property api_key : String?
    property timeout : Time::Span?
  end

  private macro def_settings
    @@settings = Settings.new
    @@client : Client?

    def self.settings
      @@settings
    end

    # Yields the module-level settings; any subsequent `client` call is rebuilt
    # from the updated defaults.
    def self.configure(&) : Settings
      yield @@settings
      @@client = nil
      @@settings
    end

    # Lazily-built client from the configured defaults (or environment
    # variables / library defaults when unset).
    def self.client : Client
      @@client ||= Client.new(
        url: @@settings.url,
        api_key: @@settings.api_key,
        timeout: @@settings.timeout
      )
    end
  end

  def_settings
end
