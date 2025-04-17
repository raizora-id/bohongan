defmodule Bohongan.RouterTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias Bohongan.Router
  alias Bohongan.Store

  @opts Router.init([])

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
      ]
    }

    # Load data into the store
    Store.load_data(test_data)

    # Return the test data for use in tests
    %{data: test_data}
  end

  test "GET / returns resources and routes", %{data: _data} do
    # Create a test connection
    conn = conn(:get, "/")
           |> Router.call(@opts)

    # Assert the response and status
    assert conn.state == :sent
    assert conn.status == 200

    # Parse the response body
    response = Jason.decode!(conn.resp_body)

    # Check the structure of the response
    assert Map.has_key?(response, "resources")
    assert Map.has_key?(response, "routes")
    assert "posts" in response["resources"]
    assert "comments" in response["resources"]

    # Check that the routes include our test resources
    assert Enum.any?(response["routes"], fn route -> route["resource"] == "posts" end)
    assert Enum.any?(response["routes"], fn route -> route["resource"] == "comments" end)
  end

  test "GET /posts returns all posts", %{data: data} do
    # Create a test connection
    conn = conn(:get, "/posts")
           |> Router.call(@opts)

    # Assert the response and status
    assert conn.state == :sent
    assert conn.status == 200

    # Parse the response body
    posts = Jason.decode!(conn.resp_body)

    # Check we got all the posts
    assert is_list(posts)
    assert length(posts) == 2
    assert Enum.any?(posts, fn post -> post["id"] == 1 end)
    assert Enum.any?(posts, fn post -> post["id"] == 2 end)
  end

  test "GET /posts/:id returns a specific post", %{data: data} do
    # Create a test connection
    conn = conn(:get, "/posts/1")
           |> Router.call(@opts)

    # Assert the response and status
    assert conn.state == :sent
    assert conn.status == 200

    # Parse the response body
    post = Jason.decode!(conn.resp_body)

    # Check the post details
    assert post["id"] == 1
    assert post["title"] == "Test Post 1"
    assert post["author"] == "Test Author 1"
  end

  test "GET /posts/:id returns 404 for non-existent post", %{data: data} do
    # Create a test connection
    conn = conn(:get, "/posts/999")
           |> Router.call(@opts)

    # Assert the response and status
    assert conn.state == :sent
    assert conn.status == 404
  end

  test "POST /posts creates a new post", %{data: data} do
    # Post data
    post_data = %{"title" => "New Post", "author" => "New Author"}

    # Create a test connection
    conn = conn(:post, "/posts", post_data)
           |> put_req_header("content-type", "application/json")
           |> Router.call(@opts)

    # Assert the response and status
    assert conn.state == :sent
    assert conn.status == 201

    # Parse the response body
    created_post = Jason.decode!(conn.resp_body)

    # Check the post details
    assert Map.has_key?(created_post, "id")
    assert created_post["title"] == "New Post"
    assert created_post["author"] == "New Author"

    # Verify the post was actually added
    all_posts = Store.get_collection("posts")
    assert length(all_posts) == 3
  end

  test "PUT /posts/:id updates a post", %{data: data} do
    # Update data
    update_data = %{"title" => "Updated Title"}

    # Create a test connection
    conn = conn(:put, "/posts/1", update_data)
           |> put_req_header("content-type", "application/json")
           |> Router.call(@opts)

    # Assert the response and status
    assert conn.state == :sent
    assert conn.status == 200

    # Parse the response body
    updated_post = Jason.decode!(conn.resp_body)

    # Check the post was updated
    assert updated_post["id"] == 1
    assert updated_post["title"] == "Updated Title"
    assert updated_post["author"] == "Test Author 1" # Original field retained

    # Verify the update in the store
    post = Store.get_item("posts", 1)
    assert post["title"] == "Updated Title"
  end

  test "PATCH /posts/:id partially updates a post", %{data: data} do
    # Update data
    update_data = %{"author" => "Patched Author"}

    # Create a test connection
    conn = conn(:patch, "/posts/1", update_data)
           |> put_req_header("content-type", "application/json")
           |> Router.call(@opts)

    # Assert the response and status
    assert conn.state == :sent
    assert conn.status == 200

    # Parse the response body
    updated_post = Jason.decode!(conn.resp_body)

    # Check the post was updated
    assert updated_post["id"] == 1
    assert updated_post["title"] == "Test Post 1" # Original field retained
    assert updated_post["author"] == "Patched Author"

    # Verify the update in the store
    post = Store.get_item("posts", 1)
    assert post["author"] == "Patched Author"
  end

  test "DELETE /posts/:id removes a post", %{data: data} do
    # Create a test connection
    conn = conn(:delete, "/posts/1")
           |> Router.call(@opts)

    # Assert the response and status
    assert conn.state == :sent
    assert conn.status == 204
    assert conn.resp_body == ""

    # Verify the post was deleted
    post = Store.get_item("posts", 1)
    assert post == nil

    # Check the collection size decreased
    posts = Store.get_collection("posts")
    assert length(posts) == 1
  end

  test "DELETE /posts/:id returns 404 for non-existent post", %{data: data} do
    # Create a test connection
    conn = conn(:delete, "/posts/999")
           |> Router.call(@opts)

    # Assert the response and status
    assert conn.state == :sent
    assert conn.status == 404
  end

  test "Non-existent route returns 404", %{data: data} do
    # Create a test connection
    conn = conn(:get, "/non_existent_path")
           |> Router.call(@opts)

    # Assert the response and status
    assert conn.state == :sent
    assert conn.status == 404
  end
end
