# Shared typed-resource primitives.
require "json"

module Meilisearch::Crystal
  # Base value type for stable Meilisearch response schemas.
  abstract struct Resource
    include JSON::Serializable

    # Defines a required JSON field and maps snake_case Crystal names to the
    # lower-camel-case keys used by Meilisearch.
    macro field(declaration)
      {% name = declaration.var %}
      @[JSON::Field(key: {{name.stringify.camelcase(lower: true)}})]
      getter {{declaration}}
    end

    # Defines a boolean JSON field with an idiomatic predicate getter.
    macro field?(declaration)
      {% name = declaration.var %}
      @[JSON::Field(key: {{name.stringify.camelcase(lower: true)}})]
      getter? {{declaration}}
    end

    # Defines a field that may be absent in JSON but exposes a non-nil bang
    # accessor. Accessing a missing value raises the library's `MissingValue`.
    macro field!(declaration)
      {% name = declaration.var %}
      @[JSON::Field(key: {{name.stringify.camelcase(lower: true)}})]
      @{{name}} : {{declaration.type}}?

      def {{name}}? : {{declaration.type}}?
        @{{name}}
      end

      def {{name}}! : {{declaration.type}}
        value = @{{name}}
        return value unless value.nil?

        raise MissingValue.new("Missing value: {{name}}")
      end
    end

    # Declares a named resource without repeating the base type and JSON mixin.
    macro define(name, &block)
      struct {{name}} < ::Meilisearch::Crystal::Resource
        {{block.body}}
      end
    end
  end

  # A paginated Meilisearch collection.
  struct List(T) < Resource
    include Enumerable(T)

    field results : Array(T)
    field offset : Int32
    field limit : Int32
    field total : Int32

    def each(& : T ->) : Nil
      results.each { |result| yield result }
    end
  end

  # Converts numeric millisecond values to `Time::Span`.
  module SpanMillisecondsConverter
    extend self

    def from_json(pull : JSON::PullParser) : Time::Span
      pull.read_float.milliseconds
    end

    def to_json(value : Time::Span, json : JSON::Builder) : Nil
      json.number(value.total_milliseconds)
    end
  end

  # Converts the ISO 8601 duration shape used by task responses to `Time::Span`.
  module DurationConverter
    extend self

    PATTERN = /\A(?<sign>-)?P(?:(?<days>\d+(?:\.\d+)?)D)?(?:T(?:(?<hours>\d+(?:\.\d+)?)H)?(?:(?<minutes>\d+(?:\.\d+)?)M)?(?:(?<seconds>\d+(?:\.\d+)?)S)?)?\z/

    def from_json(pull : JSON::PullParser) : Time::Span
      parse(pull.read_string)
    end

    def to_json(value : Time::Span, json : JSON::Builder) : Nil
      seconds = value.total_seconds
      json.string("PT#{seconds}S")
    end

    def parse(value : String) : Time::Span
      match = PATTERN.match(value) || raise ArgumentError.new("Invalid ISO 8601 duration: #{value}")
      span = capture(match, "days").days +
             capture(match, "hours").hours +
             capture(match, "minutes").minutes +
             capture(match, "seconds").seconds
      match["sign"]? ? -span : span
    end

    private def capture(match : Regex::MatchData, name : String) : Float64
      match[name]?.try(&.to_f64) || 0.0
    end
  end

  # JSON converter for enums represented by lower-camel-case strings.
  module LowerCamelEnumConverter(T)
    extend self

    def from_json(pull : JSON::PullParser) : T
      value = pull.read_string
      T.parse?(value.camelcase) || raise ArgumentError.new("Unknown #{T} value: #{value}")
    end

    def to_json(value : T, json : JSON::Builder) : Nil
      json.string(value.to_s.camelcase(lower: true))
    end
  end
end
