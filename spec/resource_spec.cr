require "./spec_helper"

module Meilisearch::Crystal
  Resource.define(ExampleResource) do
    field primary_key : String
    field? available : Bool
    field! optional_count : Int32
  end

  enum ExampleMode
    Any
    Last
  end

  struct EnumEnvelope
    include JSON::Serializable

    @[JSON::Field(converter: Meilisearch::Crystal::LowerCamelEnumConverter(Meilisearch::Crystal::ExampleMode))]
    getter mode : ExampleMode
  end

  describe Resource do
    it "maps fields to lower-camel-case JSON keys" do
      resource = ExampleResource.from_json(%({"primaryKey":"id","available":true}))
      resource.primary_key.should eq("id")
      resource.available?.should be_true
      resource.optional_count?.should be_nil
    end

    it "raises MissingValue from a missing bang field" do
      resource = ExampleResource.from_json(%({"primaryKey":"id","available":false}))
      expect_raises(MissingValue, "Missing value: optional_count") do
        resource.optional_count!
      end
    end

    it "provides an enumerable paginated list" do
      list = List(String).from_json(%({"results":["a","b"],"offset":1,"limit":2,"total":4}))
      list.to_a.should eq(["a", "b"])
      list.offset.should eq(1)
    end
  end

  describe SpanMillisecondsConverter do
    it "converts milliseconds in both directions" do
      span = SpanMillisecondsConverter.from_json(JSON::PullParser.new("12.5"))
      span.total_milliseconds.should eq(12.5)

      JSON.build do |builder|
        SpanMillisecondsConverter.to_json(span, builder)
      end.should eq("12.5")
    end
  end

  describe DurationConverter do
    it "parses and serializes ISO 8601 durations" do
      span = DurationConverter.parse("P1DT2H3M4.5S")
      span.total_seconds.should eq(93_784.5)

      JSON.build do |builder|
        DurationConverter.to_json(1.5.seconds, builder)
      end.should eq(%("PT1.5S"))
    end
  end

  describe LowerCamelEnumConverter do
    it "maps enum values to and from lower-camel-case strings" do
      envelope = EnumEnvelope.from_json(%({"mode":"last"}))
      envelope.mode.should eq(ExampleMode::Last)
      envelope.to_json.should eq(%({"mode":"last"}))
    end
  end
end
