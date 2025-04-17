defmodule Bohongan.ProtoLoaderTest do
  use ExUnit.Case

  alias Bohongan.ProtoLoader

  # Helper function to create a temporary proto file for testing
  defp with_temp_proto_file(content, fun) do
    # Create a temp file
    {:ok, path} = Temp.open("bohongan-proto-test", &IO.write(&1, content))

    try do
      # Call the function with the path
      fun.(path)
    after
      # Ensure we clean up
      File.rm(path)
    end
  end

  test "load_proto_file returns error for non-existent file" do
    # Use a path that definitely doesn't exist
    non_existent_path = "/path/to/nowhere/that/doesnt/exist.proto"

    result = ProtoLoader.load_proto_file(non_existent_path)
    assert {:error, _} = result
  end

  test "parse_proto extracts message definitions" do
    proto_content = """
    syntax = "proto3";

    message User {
      int32 id = 1;
      string name = 2;
      string email = 3;
    }
    """

    {:ok, schema} = ProtoLoader.parse_proto(proto_content)

    # Verify the schema structure
    assert is_map(schema)
    assert Map.has_key?(schema, "User")
    assert is_list(schema["User"])

    # Verify the sample data
    user = hd(schema["User"])
    assert user["id"] == 1
    assert is_binary(user["name"])
    assert is_binary(user["email"])
  end

  test "parse_proto handles multiple messages" do
    proto_content = """
    syntax = "proto3";

    message User {
      int32 id = 1;
      string name = 2;
    }

    message Post {
      int32 id = 1;
      string title = 2;
      string content = 3;
    }
    """

    {:ok, schema} = ProtoLoader.parse_proto(proto_content)

    # Verify both messages are in the schema
    assert Map.has_key?(schema, "User")
    assert Map.has_key?(schema, "Post")

    # Verify the Post sample data
    post = hd(schema["Post"])
    assert post["id"] == 1
    assert is_binary(post["title"])
    assert is_binary(post["content"])
  end

  test "parse_proto handles repeated fields" do
    proto_content = """
    syntax = "proto3";

    message User {
      int32 id = 1;
      string name = 2;
      repeated string tags = 3;
    }
    """

    {:ok, schema} = ProtoLoader.parse_proto(proto_content)

    # Verify the repeated field is an array
    user = hd(schema["User"])
    assert is_list(user["tags"])
  end

  test "parse_proto handles nested messages" do
    proto_content = """
    syntax = "proto3";

    message User {
      int32 id = 1;
      string name = 2;
      Address address = 3;
    }

    message Address {
      string street = 1;
      string city = 2;
    }
    """

    {:ok, schema} = ProtoLoader.parse_proto(proto_content)

    # Verify both messages are in the schema
    assert Map.has_key?(schema, "User")
    assert Map.has_key?(schema, "Address")

    # Verify the nested field is an object
    user = hd(schema["User"])
    assert is_map(user["address"])
  end

  test "parse_proto handles different field types" do
    proto_content = """
    syntax = "proto3";

    message AllTypes {
      int32 int_field = 1;
      string string_field = 2;
      bool bool_field = 3;
      float float_field = 4;
      double double_field = 5;
    }
    """

    {:ok, schema} = ProtoLoader.parse_proto(proto_content)

    # Verify all types are converted correctly
    all_types = hd(schema["AllTypes"])
    assert is_number(all_types["int_field"])
    assert is_binary(all_types["string_field"])
    assert is_boolean(all_types["bool_field"])
    assert is_number(all_types["float_field"])
    assert is_number(all_types["double_field"])
  end

  test "load_proto_file loads and parses a proto file" do
    proto_content = """
    syntax = "proto3";

    message User {
      int32 id = 1;
      string name = 2;
    }
    """

    with_temp_proto_file(proto_content, fn path ->
      {:ok, schema} = ProtoLoader.load_proto_file(path)

      # Verify the schema was loaded correctly
      assert Map.has_key?(schema, "User")
      user = hd(schema["User"])
      assert user["id"] == 1
      assert is_binary(user["name"])
    end)
  end

  test "integration with complex proto definition" do
    proto_content = """
    syntax = "proto3";

    package example;

    message User {
      int32 id = 1;
      string name = 2;
      string email = 3;
      UserRole role = 4;
      repeated string interests = 5;
      Address address = 6;
    }

    enum UserRole {
      GUEST = 0;
      USER = 1;
      ADMIN = 2;
    }

    message Address {
      string street = 1;
      string city = 2;
      string country = 3;
    }

    message Order {
      int32 id = 1;
      int32 userId = 2;
      repeated OrderItem items = 3;
      double totalAmount = 4;
    }

    message OrderItem {
      int32 productId = 1;
      int32 quantity = 2;
      double unitPrice = 3;
    }
    """

    with_temp_proto_file(proto_content, fn path ->
      {:ok, schema} = ProtoLoader.load_proto_file(path)

      # Verify all messages are in the schema
      assert Map.has_key?(schema, "User")
      assert Map.has_key?(schema, "Address")
      assert Map.has_key?(schema, "Order")
      assert Map.has_key?(schema, "OrderItem")

      # Verify specific fields
      user = hd(schema["User"])
      assert is_binary(user["email"])
      assert is_list(user["interests"])

      order = hd(schema["Order"])
      assert is_number(order["totalAmount"])
    end)
  end
end
