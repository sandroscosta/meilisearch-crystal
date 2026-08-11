require "./spec_helper"
require "webmock"

module Meilisearch::Crystal
  private class PassthroughAPI < API
    pass get
  end

  describe Client do
    after_each { WebMock.reset }

    describe "#initialize" do
      it "uses explicit url / api_key / timeout" do
        client = Client.new(url: "http://localhost:7700", api_key: "masterKey", timeout: 10.seconds)
        client.url.to_s.should eq("http://localhost:7700")
        client.api_key.should eq("masterKey")
        client.timeout.should eq(10.seconds)
      end

      it "accepts a URI" do
        client = Client.new(url: URI.parse("http://localhost:7700"))
        client.url.to_s.should eq("http://localhost:7700")
      end

      it "resolves environment defaults" do
        with_env({"MEILISEARCH_URL" => "http://env.example:7700", "MEILISEARCH_API_KEY" => "env-key"}) do
          client = Client.new
          client.url.to_s.should eq("http://env.example:7700")
          client.api_key.should eq("env-key")
        end
      end

      it "defaults timeout to 5 seconds" do
        Client.new(url: "http://localhost:7700").timeout.should eq(5.seconds)
      end

      it "raises ArgumentError for a URL without scheme/host" do
        expect_raises(ArgumentError, /scheme and host/) do
          Client.new(url: "localhost:7700")
        end
      end
    end

    describe "module-level configuration" do
      it "configure block feeds the lazy client" do
        Meilisearch::Crystal.configure do |settings|
          settings.url = "http://config.example:7700"
          settings.api_key = "config-key"
        end
        client = Meilisearch::Crystal.client
        client.url.to_s.should eq("http://config.example:7700")
        client.api_key.should eq("config-key")
      ensure
        Meilisearch::Crystal.configure do |settings|
          settings.url = nil
          settings.api_key = nil
          settings.timeout = nil
        end
      end
    end

    describe "HTTP transport" do
      it "injects Authorization, Accept, User-Agent, and Content-Type on writes" do
        expected_headers = HTTP::Headers{
          "Authorization" => "Bearer secret",
          "Accept"        => "application/json",
          "User-Agent"    => "meilisearch-crystal/0.1.0",
          "Content-Type"  => "application/json",
        }
        WebMock.stub(:post, "http://localhost:7700/indexes")
          .with(headers: expected_headers)
          .to_return(status: 202, body: %({"taskUid": 1}))

        client = Client.new(url: "http://localhost:7700", api_key: "secret")
        response = client.post("/indexes", %({"uid":"movies"}))
        response.status_code.should eq(202)
      end

      it "does not set Content-Type on GET" do
        WebMock.stub(:get, "http://localhost:7700/indexes")
          .to_return(status: 200, body: %([]))

        client = Client.new(url: "http://localhost:7700", api_key: "secret")
        response = client.get("/indexes")
        response.status_code.should eq(200)
      end

      it "encodes query parameters into the path" do
        WebMock.stub(:get, "http://localhost:7700/indexes?limit=3&offset=1")
          .to_return(status: 200, body: %([]))

        params = HTTP::Params.encode({"limit" => "3", "offset" => "1"})
        client = Client.new(url: "http://localhost:7700")
        response = client.get("/indexes", HTTP::Params.parse(params))
        response.status_code.should eq(200)
      end
    end

    describe "API response handling" do
      it "exposes the client's HTTP transport and forwards passed methods" do
        WebMock.stub(:get, "http://localhost:7700/health")
          .to_return(status: 200, body: %({"status":"available"}))

        client = Client.new(url: "http://localhost:7700")
        api = PassthroughAPI.new(client)
        api.http.should be(client.http)
        api.get("/health").status_code.should eq(200)
      end

      it "raises a typed Error from a non-2xx body" do
        WebMock.stub(:get, "http://localhost:7700/tasks/42")
          .to_return(status: 404, body: %({"message":"Task `42` not found.","code":"task_not_found","type":"invalid_request","link":"https://docs.meilisearch.com/errors#task_not_found"}))

        client = Client.new(url: "http://localhost:7700")
        expect_raises(ApiError, "Task `42` not found.") do
          Tasks.new(client).get(42)
        end
      end

      it "deserializes a 2xx body into the requested type" do
        body = %({"uid":42,"indexUid":"movies","status":"succeeded","type":"documentAdditionOrUpdate","enqueuedAt":1700000000000,"startedAt":1700000001000,"finishedAt":1700000002000})
        WebMock.stub(:get, "http://localhost:7700/tasks/42")
          .to_return(status: 200, body: body)

        client = Client.new(url: "http://localhost:7700")
        task = Tasks.new(client).get(42)
        task.uid.should eq(42_i64)
        task.status.should eq(BasicTask::Status::Succeeded)
        task.type.should eq(BasicTask::Type::DocumentAdditionOrUpdate)
      end
    end

    describe "#wait_for_task" do
      it "accepts a TaskResult" do
        WebMock.stub(:get, "http://localhost:7700/tasks/7")
          .to_return(body: %({"uid":7,"indexUid":"movies","status":"succeeded","type":"documentAdditionOrUpdate","enqueuedAt":1700000000000}))

        client = Client.new(url: "http://localhost:7700")
        result = TaskResult.from_json(%({"taskUid":7}))
        client.wait_for_task(result).uid.should eq(7)
      end

      it "polls until the task reaches a terminal status" do
        pending_body = %({"uid":1,"indexUid":"movies","status":"enqueued","type":"documentAdditionOrUpdate","enqueuedAt":1700000000000})
        done_body = %({"uid":1,"indexUid":"movies","status":"succeeded","type":"documentAdditionOrUpdate","enqueuedAt":1700000000000,"startedAt":1700000001000,"finishedAt":1700000002000})

        calls = 0
        stub = WebMock.stub(:get, "http://localhost:7700/tasks/1").to_return do |_request|
          calls += 1
          HTTP::Client::Response.new(200, body: calls == 1 ? pending_body : done_body)
        end

        client = Client.new(url: "http://localhost:7700", timeout: 1.second)
        task = client.wait_for_task(1, poll_interval: 5.milliseconds)
        task.status.should eq(BasicTask::Status::Succeeded)
        stub.calls.should eq(2)
      end

      it "raises TimeoutError when the task never completes" do
        WebMock.stub(:get, "http://localhost:7700/tasks/1")
          .to_return(body: %({"uid":1,"indexUid":"movies","status":"processing","type":"documentAdditionOrUpdate","enqueuedAt":1700000000000,"startedAt":1700000001000}))

        client = Client.new(url: "http://localhost:7700", timeout: 20.milliseconds)
        expect_raises(TimeoutError, /timed out waiting for task 1/) do
          client.wait_for_task(1, poll_interval: 5.milliseconds)
        end
      end
    end
  end
end
