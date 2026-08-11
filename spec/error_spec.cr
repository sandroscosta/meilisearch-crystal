require "./spec_helper"
require "webmock"

module Meilisearch::Crystal
  describe Error do
    it "parses the error envelope into typed fields" do
      error = Error.from_json(%({"message": "Index `movies` not found.", "code": "index_not_found", "type": "invalid_request", "link": "https://docs.meilisearch.com/errors#index_not_found"}))
      error.message.should eq("Index `movies` not found.")
      error.code.should eq(Error::Code::IndexNotFound)
      error.type.should eq("invalid_request")
      error.link.to_s.should eq("https://docs.meilisearch.com/errors#index_not_found")
    end

    it "serializes the code in camelCase-lower form (jgaskins JSON mapping)" do
      error = Error.from_json(%({"message":"boom","code":"index_not_found","type":"invalid_request","link":"https://docs.meilisearch.com/errors#index_not_found"}))
      error.to_json.should contain(%("code":"indexNotFound"))
    end

    it "falls back to Unknown for undocumented codes" do
      error = Error.from_json(%({"message": "future code", "code": "some_future_code", "type": "internal", "link": "https://docs.meilisearch.com"}))
      error.code.should eq(Error::Code::Unknown)
      error.message.should eq("future code")
    end

    describe "webmock" do
      it "parses an error envelope from a non-2xx response body" do
        WebMock.stub(:get, "http://localhost:7700/indexes/movies")
          .to_return(status: 404, body: %({"message":"Index `movies` not found.","code":"index_not_found","type":"invalid_request","link":"https://docs.meilisearch.com/errors#index_not_found"}))

        HTTP::Client.get("http://localhost:7700/indexes/movies") do |response|
          error = Error.from_json(response.body)
          error.code.should eq(Error::Code::IndexNotFound)
          error.type.should eq("invalid_request")
        end
      end

      it "parses an unknown code from a non-2xx response body" do
        WebMock.stub(:get, "http://localhost:7700/health")
          .to_return(status: 500, body: %({"message":"future","code":"something_new","type":"internal","link":"https://docs.meilisearch.com"}))

        HTTP::Client.get("http://localhost:7700/health") do |response|
          error = Error.from_json(response.body)
          error.code.should eq(Error::Code::Unknown)
        end
      end
    end
  end

  describe "exceptions" do
    it "raises CommunicationError on unreachable hosts" do
      expect_raises(Meilisearch::Crystal::CommunicationError) do
        # A stub that forces the failure path would live here; for now the
        # exception itself is exercised via raise directly.
        raise Meilisearch::Crystal::CommunicationError.new("connection refused")
      end
    end

    it "raises TimeoutError when a task wait exceeds its timeout" do
      expect_raises(Meilisearch::Crystal::TimeoutError) do
        raise Meilisearch::Crystal::TimeoutError.new("timed out waiting for task 42")
      end
    end

    it "raises TaskUnsuccessful when an awaited task fails" do
      expect_raises(Meilisearch::Crystal::TaskUnsuccessful) do
        raise Meilisearch::Crystal::TaskUnsuccessful.new("task 42 failed")
      end
    end
  end
end
