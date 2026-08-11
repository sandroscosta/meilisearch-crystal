require "./spec_helper"
require "webmock"

module Meilisearch::Crystal
  struct MovieDocument
    include JSON::Serializable

    getter id : Int32
    getter title : String
  end

  describe Documents do
    after_each { WebMock.reset }

    it "upserts arrays as JSON and lazy enumerables as NDJSON" do
      task = %({"taskUid":1})
      WebMock.stub(:post, "http://localhost:7700/indexes/movies/documents?primaryKey=id")
        .with(body: %([{"id":1,"title":"Alien"}]))
        .to_return(status: 202, body: task)
      WebMock.stub(:post, "http://localhost:7700/indexes/books/documents")
        .with(body: "{\"id\":1}\n{\"id\":2}\n", headers: {"Content-Type" => "application/x-ndjson"})
        .to_return(status: 202, body: task)

      documents = Client.new.index("movies").documents
      documents.upsert("movies", [{id: 1, title: "Alien"}], "id").task_uid.should eq(1)
      documents.upsert("books", (1..2).each.map { |id| {id: id} }).task_uid.should eq(1)
    end

    it "patches arrays using PUT" do
      WebMock.stub(:put, "http://localhost:7700/indexes/movies/documents")
        .with(body: %([{"id":1,"title":"Aliens"}]))
        .to_return(status: 202, body: %({"taskUid":2}))
      WebMock.stub(:put, "http://localhost:7700/indexes/books/documents")
        .with(body: "{\"id\":1}\n", headers: {"Content-Type" => "application/x-ndjson"})
        .to_return(status: 202, body: %({"taskUid":2}))

      documents = Documents.new(Client.new)
      documents.upsert_patch("movies", [{id: 1, title: "Aliens"}]).task_uid.should eq(2)
      documents.upsert_patch("books", [1].each.map { |id| {id: id} }).task_uid.should eq(2)
    end

    it "waits for blocking upserts and returns the successful task" do
      WebMock.stub(:post, "http://localhost:7700/indexes/movies/documents")
        .to_return(status: 202, body: %({"taskUid":8}))
      WebMock.stub(:get, "http://localhost:7700/tasks/8")
        .to_return(body: %({"uid":8,"indexUid":"movies","status":"succeeded","type":"documentAdditionOrUpdate","enqueuedAt":1700000000000}))

      task = Documents.new(Client.new).upsert!("movies", [{id: 1}])
      task.succeeded?.should be_true
    end

    it "fetches raw and typed documents" do
      request_body = %({"offset":0,"limit":20,"fields":["id","title"],"filter":"id > 0","sort":["title:asc"]})
      response_body = %({"results":[{"id":1,"title":"Alien"}],"offset":0,"limit":20,"total":1})
      WebMock.stub(:post, "http://localhost:7700/indexes/movies/documents/fetch")
        .with(body: request_body)
        .to_return(body: response_body)

      result = Documents.new(Client.new).fetch(
        "movies",
        offset: 0,
        limit: 20,
        fields: ["id", "title"],
        filter: "id > 0",
        sort: ["title:asc"],
        as: MovieDocument
      )
      result.first.title.should eq("Alien")
    end

    it "deletes one, many, filtered, or all documents" do
      task = %({"taskUid":3})
      WebMock.stub(:delete, "http://localhost:7700/indexes/movies/documents/1").to_return(status: 202, body: task)
      WebMock.stub(:post, "http://localhost:7700/indexes/movies/documents/delete-batch").with(body: %([1,2])).to_return(status: 202, body: task)
      WebMock.stub(:post, "http://localhost:7700/indexes/movies/documents/delete").with(body: %({"filter":"year < 1980"})).to_return(status: 202, body: task)
      WebMock.stub(:delete, "http://localhost:7700/indexes/movies/documents").to_return(status: 202, body: task)

      documents = Documents.new(Client.new)
      documents.delete("movies", 1).task_uid.should eq(3)
      documents.delete("movies", [1, 2]).task_uid.should eq(3)
      documents.delete("movies", filter: "year < 1980").task_uid.should eq(3)
      documents.delete_all("movies").task_uid.should eq(3)
    end
  end
end
