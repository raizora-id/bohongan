defmodule Bohongan.ProtoLoader do
  @moduledoc """
  Module for loading and processing Protocol Buffer files.

  This module converts Protocol Buffer definitions into a JSON schema
  that can be used by Bohongan to create RESTful endpoints.
  """
  require Logger

  @doc """
  Loads a Protocol Buffer file and converts it to a JSON data structure.

  ## Parameters
    - proto_file: Path to the .proto file

  ## Returns
    - {:ok, json_data} - Successfully loaded and converted proto file
    - {:error, reason} - Failed to load or convert proto file
  """
  def load_proto_file(proto_file) do
    with {:ok, proto_content} <- File.read(proto_file),
         {:ok, schema} <- parse_proto(proto_content) do
      {:ok, schema}
    else
      {:error, reason} ->
        Logger.error("Failed to load proto file: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Parses Protocol Buffer content and converts it to a JSON structure.

  ## Parameters
    - content: String content of the proto file

  ## Returns
    - {:ok, json_data} - Successfully parsed proto content
    - {:error, reason} - Failed to parse proto content
  """
  def parse_proto(content) do
    try do
      # Extract all message definitions
      messages = extract_messages(content)

      # Convert messages to JSON schema
      schema = messages_to_json_schema(messages)

      {:ok, schema}
    rescue
      e ->
        Logger.error("Error parsing proto file: #{inspect(e)}")
        {:error, "Failed to parse proto content: #{inspect(e)}"}
    end
  end

  # Extract message definitions from proto content
  defp extract_messages(content) do
    # Regular expression to match message definitions
    # This is a simplified version and might need enhancement for complex protos
    message_regex = ~r/message\s+([A-Za-z][A-Za-z0-9_]*)\s*{([^}]*)}/

    # Find all matches
    Regex.scan(message_regex, content, capture: :all_but_first)
    |> Enum.map(fn [name, fields_text] ->
      # Extract fields for each message
      fields = extract_fields(fields_text)
      {name, fields}
    end)
    |> Map.new()
  end

  # Extract field definitions from message content
  defp extract_fields(fields_text) do
    # Regular expression to match field definitions
    # This is simplified and handles basic field types
    field_regex = ~r/\s*(optional|required|repeated)?\s*([A-Za-z][A-Za-z0-9_\.]*)\s+([A-Za-z][A-Za-z0-9_]*)\s*=\s*(\d+)/

    # Find all fields
    Regex.scan(field_regex, fields_text, capture: :all_but_first)
    |> Enum.map(fn field_parts ->
      parse_field(field_parts)
    end)
    |> Enum.filter(&(&1 != nil))
  end

  # Parse a single field definition
  defp parse_field([modifier, type, name, _number]) do
    # Handle modifiers (optional, required, repeated)
    is_array = modifier == "repeated"

    # Convert proto types to JSON types
    json_type = case type do
      "string" -> "string"
      "int32" | "int64" | "uint32" | "uint64" | "sint32" | "sint64" |
      "fixed32" | "fixed64" | "sfixed32" | "sfixed64" -> "number"
      "float" | "double" -> "number"
      "bool" -> "boolean"
      "bytes" -> "string"
      _ ->
        if String.contains?(type, "."), do: "object", else: "object"
    end

    %{
      "name" => name,
      "type" => json_type,
      "is_array" => is_array
    }
  end

  defp parse_field(_) do
    nil
  end

  # Convert message definitions to JSON schema
  defp messages_to_json_schema(messages) do
    # Create empty collections for each message
    messages
    |> Enum.map(fn {name, fields} ->
      # Create sample items based on the fields
      sample_items = [create_sample_item(fields)]

      # Return collection name and sample items
      {name, sample_items}
    end)
    |> Map.new()
  end

  # Create a sample item based on field definitions
  defp create_sample_item(fields) do
    # Start with an ID field
    base_item = %{"id" => 1}

    # Add fields based on their types
    fields
    |> Enum.reduce(base_item, fn field, acc ->
      name = field["name"]
      value = default_value_for_type(field["type"], field["is_array"])
      Map.put(acc, name, value)
    end)
  end

  # Generate default values based on JSON types
  defp default_value_for_type(type, is_array) do
    base_value = case type do
      "string" -> "Sample text"
      "number" -> 42
      "boolean" -> true
      "object" -> %{"sample_field" => "Sample value"}
      _ -> nil
    end

    if is_array, do: [base_value], else: base_value
  end
end
