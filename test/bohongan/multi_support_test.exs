defmodule Bohongan.MultiSupportTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  alias Bohongan.CLI

  # Helper function to create multiple temporary files for testing
  defp with_temp_files(contents_map, fun) do
    # Create temp files
    paths_map = Enum.map(contents_map, fn {name, content} ->
      {:ok, path} = Temp.open("bohongan-#{name}", &IO.write(&1, content))
      {name, path}
    end)
    |> Map.new()

    try do
      # Call the function with the paths
      fun.(paths_map)
    after
      # Ensure we clean up
      Enum.each(paths_map, fn {_, path} -> File.rm(path) end)
    end
  end

  test "merge_json_data combines data from multiple files" do
    # Test data
    file1_data = %{
      "users" => [
        %{"id" => 1, "name" => "User 1"},
        %{"id" => 2, "name" => "User 2"}
      ]
    }

    file2_data = %{
      "posts" => [
        %{"id" => 1, "title" => "Post 1"}
      ]
    }

    # Test the merge function
    merged = CLI.merge_json_data([{"file1.json", file1_data}, {"file2.json", file2_data}])

    # Verify the result
    assert Map.has_key?(merged, "users")
    assert Map.has_key?(merged, "posts")
    assert length(merged["users"]) == 2
    assert length(merged["posts"]) == 1
  end

  test "merge_json_data handles conflicts by merging collections" do
    # Test data with overlapping collections
    file1_data = %{
      "users" => [
        %{"id" => 1, "name" => "User 1"},
        %{"id" => 2, "name" => "User 2"}
      ]
    }

    file2_data = %{
      "users" => [
        %{"id" => 2, "name" => "Updated User 2"},
        %{"id" => 3, "name" => "User 3"}
      ]
    }

    # Test the merge function
    merged = CLI.merge_json_data([{"file1.json", file1_data}, {"file2.json", file2_data}])

    # Verify the result
    assert Map.has_key?(merged, "users")
    assert length(merged["users"]) == 3

    # Check that user 2 was updated, not duplicated
    user2 = Enum.find(merged["users"], fn user -> user["id"] == 2 end)
    assert user2["name"] == "Updated User 2"

    # Check that other users are preserved
    assert Enum.any?(merged["users"], fn user -> user["id"] == 1 end)
    assert Enum.any?(merged["users"], fn user -> user["id"] == 3 end)
  end

  test "merge_collections properly merges arrays of items" do
    existing = [
      %{"id" => 1, "name" => "Item 1"},
      %{"id" => 2, "name" => "Item 2"},
      "non-map item"
    ]

    new = [
      %{"id" => 2, "name" => "Updated Item 2"},
      %{"id" => 3, "name" => "Item 3"},
      %{"no_id" => true}
    ]

    # Test the merge function
    merged = CLI.merge_collections(existing, new)

    # Verify the result
    assert length(merged) == 6  # 3 items with IDs + 3 without IDs

    # Check that item 2 was updated
    item2 = Enum.find(merged, fn item ->
      is_map(item) and Map.has_key?(item, "id") and item["id"] == 2
    end)
    assert item2["name"] == "Updated Item 2"

    # Check that other items are preserved
    assert Enum.any?(merged, fn item ->
      is_map(item) and Map.has_key?(item, "id") and item["id"] == 1
    end)
    assert Enum.any?(merged, fn item ->
      is_map(item) and Map.has_key?(item, "id") and item["id"] == 3
    end)

    # Check that non-map items are preserved
    assert Enum.any?(merged, fn item -> item == "non-map item" end)
    assert Enum.any?(merged, fn item ->
      is_map(item) and Map.has_key?(item, "no_id")
    end)
  end

  test "CLI can handle multiple JSON files" do
    # Setup test files
    files = %{
      "users" => ~s({"users": [{"id": 1, "name": "User 1"}]}),
      "posts" => ~s({"posts": [{"id": 1, "title": "Post 1"}]})
    }

    with_temp_files(files, fn paths ->
      users_path = Map.get(paths, "users")
      posts_path = Map.get(paths, "posts")

      # Mock the start_server function to verify arguments
      try do
        :meck.new(CLI, [:passthrough])
        :meck.expect(CLI, :start_server_with_json_files, fn files, port ->
          # Store the args for verification
          Process.put(:cli_test_files, files)
          Process.put(:cli_test_port, port)
          :ok
        end)

        output = capture_io(fn ->
          CLI.main(["--data=#{users_path}", "--data=#{posts_path}", "--port=4000"])
        end)

        # Verify the arguments were passed correctly
        files = Process.get(:cli_test_files)
        assert length(files) == 2
        assert users_path in files
        assert posts_path in files
        assert Process.get(:cli_test_port) == 4000
      after
        :meck.unload(CLI)
      end
    end)
  end

  test "CLI can handle multiple Proto files" do
    # Setup test files
    files = %{
      "users" => ~s(message User { int32 id = 1; string name = 2; }),
      "posts" => ~s(message Post { int32 id = 1; string title = 2; })
    }

    with_temp_files(files, fn paths ->
      users_path = Map.get(paths, "users")
      posts_path = Map.get(paths, "posts")

      # Mock the start_server function to verify arguments
      try do
        :meck.new(CLI, [:passthrough])
        :meck.expect(CLI, :start_server_with_proto_files, fn files, port ->
          # Store the args for verification
          Process.put(:cli_test_files, files)
          Process.put(:cli_test_port, port)
          :ok
        end)

        output = capture_io(fn ->
          CLI.main(["--proto=#{users_path}", "--proto=#{posts_path}", "--port=4000"])
        end)

        # Verify the arguments were passed correctly
        files = Process.get(:cli_test_files)
        assert length(files) == 2
        assert users_path in files
        assert posts_path in files
        assert Process.get(:cli_test_port) == 4000
      after
        :meck.unload(CLI)
      end
    end)
  end
end
