defmodule Simperium.BucketTest do
  use ExUnit.Case, async: true

  alias Simperium.Bucket
  alias Simperium.Change
  alias Simperium.Ghost

  describe "new bucket with index" do
    setup do
      %{
        registry: start_supervised!({Registry, [keys: :duplicate, name: Simperium.BucketTest]}),
        bucket:
          start_supervised!(
            {Bucket,
             [
               registry: Simperium.BucketTest,
               channel: %Bucket.Channel{},
               state: %{index_complete?: true}
             ]}
          )
      }
    end

    test "get cv", %{bucket: bucket} do
      assert :new == Bucket.cv(bucket)
    end

    test "get a ghost", %{bucket: bucket} do
      assert nil == Bucket.get(bucket, "object-id")
    end

    test "init command", %{bucket: bucket} do
      assert :noop = Bucket.create_init_command(bucket)
    end

    test "perform change", %{bucket: bucket} do
      command = %Simperium.Message.RemoteChanges{
        changes: [
          Change.create(
            "mock-client",
            "mock-cv",
            "an-object",
            0,
            1,
            "M",
            %{"note" => %{"o" => "+", "v" => "hello"}},
            ["ccid-one"]
          )
        ]
      }

      result = Bucket.apply_command(bucket, command)

      ghost = Ghost.create_version(1, %{"note" => "hello"})
      assert {:ok, [{"mock-cv", ghost}]} == result
      assert "mock-cv" == Bucket.cv(bucket)
      assert ghost.value == Bucket.get(bucket, "an-object")
    end
  end

  describe "bucket unindexed" do
    setup do
      %{
        registry: start_supervised!({Registry, [keys: :duplicate, name: Simperium.BucketTest]}),
        bucket:
          start_supervised!(
            {Bucket, [registry: Simperium.BucketTest, channel: %Bucket.Channel{}]}
          )
      }
    end

    test "remote changes require an index", %{bucket: bucket} do
      command = %Simperium.Message.RemoteChanges{}
      result = Bucket.apply_command(bucket, command)

      assert {:error, :noindex} = result
    end

    test "build init message?", %{bucket: bucket} do
      assert %Simperium.Message.IndexRequest{} = Bucket.create_init_command(bucket)
    end
  end

  describe "bucket indexed with ghosts" do
    setup do
      registry = start_supervised!({Registry, [keys: :duplicate, name: Simperium.BucketTest]})

      bucket =
        start_supervised!(
          {Bucket,
           [
             registry: Simperium.BucketTest,
             channel: %Bucket.Channel{},
             state: %{
               cv: "existing-cv",
               ghosts: %{"thing" => Ghost.create_version(1, %{"name" => "mock"})},
               index_complete?: true
             }
           ]}
        )

      %{bucket: bucket, registry: registry}
    end

    test "init command", %{bucket: bucket} do
      assert %Simperium.Message.ChangeVersion{cv: "existing-cv"} =
               Bucket.create_init_command(bucket)
    end

    test "delete ghost", %{bucket: bucket} do
      changes = %Simperium.Message.RemoteChanges{
        changes: [Change.create("client", "abcd", "thing", 1, 0, "-", %{}, ["mock-ccid"])]
      }

      assert {:ok, [{"abcd", %Ghost{version: 1, value: %{"name" => "mock"}}}]} =
               Bucket.apply_command(bucket, changes)

      assert nil == Bucket.get(bucket, "thing")
    end
  end
end
