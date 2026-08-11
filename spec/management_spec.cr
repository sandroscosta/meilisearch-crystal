require "./spec_helper"
require "webmock"

module Meilisearch::Crystal
  describe "management APIs" do
    after_each { WebMock.reset }

    it "manages typed API keys" do
      key_json = %({"uid":"11111111-1111-4111-8111-111111111111","name":"search","description":null,"key":"secret","actions":["search"],"indexes":["movies"],"expiresAt":null,"createdAt":"2026-08-11T00:00:00Z","updatedAt":"2026-08-11T00:00:00Z"})
      WebMock.stub(:post, "http://localhost:7700/keys").to_return(status: 201, body: key_json)
      WebMock.stub(:get, "http://localhost:7700/keys/11111111-1111-4111-8111-111111111111").to_return(body: key_json)
      WebMock.stub(:delete, "http://localhost:7700/keys/11111111-1111-4111-8111-111111111111").to_return(status: 204)

      keys = Client.new.keys
      key = keys.create(["search"], ["movies"], name: "search")
      key.actions.should eq(["search"])
      keys.get(key.uid).key.should eq("secret")
      keys.delete(key.uid).should be_nil
    end

    it "gets health/version/stats and creates backups" do
      WebMock.stub(:get, "http://localhost:7700/health").to_return(body: %({"status":"available"}))
      WebMock.stub(:get, "http://localhost:7700/version").to_return(body: %({"commitSha":"abc","commitDate":"2026-08-11","pkgVersion":"1.53.0"}))
      WebMock.stub(:get, "http://localhost:7700/stats").to_return(body: %({"databaseSize":0,"usedDatabaseSize":0,"lastUpdate":null,"indexes":{}}))
      WebMock.stub(:post, "http://localhost:7700/dumps").to_return(status: 202, body: %({"taskUid":1}))
      WebMock.stub(:post, "http://localhost:7700/snapshots").to_return(status: 202, body: %({"taskUid":2}))

      client = Client.new
      client.health.status.should eq("available")
      client.version.pkg_version.should eq("1.53.0")
      client.stats.database_size.should eq(0)
      client.create_dump.task_uid.should eq(1)
      client.create_snapshot.task_uid.should eq(2)
    end

    it "generates a verifiable HS256 tenant token" do
      token = Client.new(api_key: "search-secret").generate_tenant_token(
        "11111111-1111-4111-8111-111111111111",
        {"movies" => {filter: "tenant_id = 42"}},
        Time.unix(2_000_000_000)
      )
      header, payload, signature = token.split('.')
      JSON.parse(String.new(Base64.decode(header)))["alg"].as_s.should eq("HS256")
      decoded = JSON.parse(String.new(Base64.decode(payload)))
      decoded["apiKeyUid"].as_s.should eq("11111111-1111-4111-8111-111111111111")
      decoded["exp"].as_i64.should eq(2_000_000_000)
      expected = OpenSSL::HMAC.digest(OpenSSL::Algorithm::SHA256, "search-secret", "#{header}.#{payload}")
      Base64.decode(signature).should eq(expected)
    end
  end
end
