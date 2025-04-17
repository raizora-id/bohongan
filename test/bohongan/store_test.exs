defmodule Bohongan.StoreTest do
  use ExUnit.Case

  alias Bohongan.Store

  setup do
    # Start the Store process
    start_supervised!(Store)

    # Sample data for testing
    test_data = %{
      "posts" => [
        %{"id" => 1, "title" => "Test Post 1", "author" => "Test Author 1"},
        %{"id" => 2, "title" => "Test Post 2", "author" => "Test Author 2"}
      ],
      "comments" => [
        %{"id" => 1, "postId" => 1, "body" => "Test Comment 1", "author" => "Test Commenter 1"},
        %{"id" => 2, "postId" => 1, "body" => "Test Comment 2", "author" => "Test Commenter 2"}
      ],
      "profile" => %{"id" => 1, "name" => "Test Profile", "bio" => "Test Bio"}
    }

    # Load data into the store
    Store.load_data(test_data)

    # Return the test data for use in tests
    %{data: test_data}
  end

  test "get_resources returns list of resources", %{data: data} do
    resources = Store.get_resources()
    assert is_list(resources)
    assert length(resources) == 3
    assert "posts" in resources
    assert "comments" in resources
    assert "profile" in resources
  end

  test "get_collection returns all items in a collection", %{data: data} do
    posts = Store.get_collection("posts")
    assert is_list(posts)
    assert length(posts) == 2
    assert %{"id" => 1, "title" => "Test Post 1", "author" => "Test Author 1"} in posts
    assert %{"id" => 2, "title" => "Test Post 2", "author" => "Test Author 2"} in posts
  end

  test "get_item returns specific item by id", %{data: data} do
    post = Store.get_item("posts", 1)
    assert post == %{"id" => 1, "title" => "Test Post 1", "author" => "Test Author 1"}
  end

  test "get_item returns nil for non-existent id", %{data: data} do
    post = Store.get_item("posts", 999)
    assert post == nil
  end

  test "create_item adds a new item to a collection", %{data: data} do
    new_post = %{"title" => "New Post", "author" => "New Author"}
    created_post = Store.create_item("posts", new_post)

    # Check id was assigned
    assert Map.has_key?(created_post, "id")
    assert created_post["title"] == "New Post"

    # Verify it was actually added to the collection
    posts = Store.get_collection("posts")
    assert length(posts) == 3
    assert Enum.any?(posts, fn post -> post["title"] == "New Post" end)
  end

  test "update_item updates an existing item", %{data: data} do
    update = %{"title" => "Updated Post"}
    {:ok, updated_post} = Store.update_item("posts", 1, update)

    # Check the item was updated correctly
    assert updated_post["id"] == 1
    assert updated_post["title"] == "Updated Post"
    assert updated_post["author"] == "Test Author 1" # Original field retained

    # Verify the update is reflected in the collection
    post = Store.get_item("posts", 1)
    assert post["title"] == "Updated Post"
  end

  test "update_item returns error for non-existent id", %{data: data} do
    result = Store.update_item("posts", 999, %{"title" => "Won't Work"})
    assert result == {:error, :not_found}
  end

  test "delete_item removes an item from a collection", %{data: data} do
    # Delete a post
    result = Store.delete_item("posts", 1)
    assert result == :ok

    # Verify it was deleted
    post = Store.get_item("posts", 1)
    assert post == nil

    # Check the collection size decreased
    posts = Store.get_collection("posts")
    assert length(posts) == 1
  end

  test "delete_item returns error for non-existent id", %{data: data} do
    result = Store.delete_item("posts", 999)
    assert result == {:error, :not_found}
  end
end
