defmodule Bohongan.CLI do
  @moduledoc """
  Command-line interface for Bohongan.

  This module handles parsing command-line arguments and
  starting the application with the appropriate settings.
  """

  @doc """
  The main entry point for the escript.

  Parses command-line arguments and starts the server.
  """
  def main(args) do
    {options, _, _} = OptionParser.parse(args,
      strict: [
        data: :keep,
        proto: :keep,
        port: :integer,
        help: :boolean
      ],
      aliases: [
        d: :data,
        p: :proto,
        P: :port,
        h: :help
      ]
    )

    # Group options by key
    grouped_options = Enum.group_by(options, fn {k, _} -> k end, fn {_, v} -> v end)

    cond do
      Keyword.has_key?(options, :help) ->
        print_help()

      # Check for data files
      Map.has_key?(grouped_options, :data) ->
        data_files = Map.get(grouped_options, :data, [])
        port = List.first(Map.get(grouped_options, :port, [3000]))
        start_server_with_json_files(data_files, port)

      # Check for proto files
      Map.has_key?(grouped_options, :proto) ->
        proto_files = Map.get(grouped_options, :proto, [])
        port = List.first(Map.get(grouped_options, :port, [3000]))
        start_server_with_proto_files(proto_files, port)

      true ->
        IO.puts("Error: Missing required option --data or --proto")
        print_help()
    end
  end

  defp print_help do
    IO.puts """
    Usage: bohongan [options]

    Options:
      -d, --data FILE     JSON file to use as data source (can be specified multiple times)
      -p, --proto FILE    Protocol Buffer file to use for API generation (can be specified multiple times)
      -P, --port PORT     Port to use (default: 3000)
      -h, --help          Show this help message

    Examples:
      bohongan --data=db.json
      bohongan --data=users.json --data=posts.json --port=4000
      bohongan --proto=api.proto
      bohongan --proto=users.proto --proto=products.proto

    You must specify either --data or --proto.
    """
  end

  defp start_server_with_json_files(data_files, port) do
    # Validate all JSON files exist
    missing_files = Enum.filter(data_files, fn file -> not File.exists?(file) end)

    if not Enum.empty?(missing_files) do
      IO.puts("Error: The following files were not found:")
      Enum.each(missing_files, fn file -> IO.puts("  - #{file}") end)
      System.halt(1)
    end

    # Update application environment with the specified port
    Application.put_env(:bohongan, :port, port)

    # Initialize the application
    {:ok, _} = Application.ensure_all_started(:bohongan)

    # Load and merge all JSON files
    merged_data = data_files
                  |> Enum.map(fn file ->
                    {file, file |> File.read!() |> Jason.decode!()}
                  end)
                  |> merge_json_data()

    # Load the merged data into the store
    Bohongan.Store.load_data(merged_data)

    # Start the server
    IO.puts("Bohongan JSON Server is running at http://localhost:#{port}")
    IO.puts("  Serving data from #{length(data_files)} files:")
    Enum.each(data_files, fn file -> IO.puts("    - #{file}") end)
    IO.puts("  Press Ctrl+C to stop")

    # This keeps the application running
    Process.sleep(:infinity)
  end

  defp start_server_with_proto_files(proto_files, port) do
    # Validate all Proto files exist
    missing_files = Enum.filter(proto_files, fn file -> not File.exists?(file) end)

    if not Enum.empty?(missing_files) do
      IO.puts("Error: The following files were not found:")
      Enum.each(missing_files, fn file -> IO.puts("  - #{file}") end)
      System.halt(1)
    end

    # Update application environment with the specified port
    Application.put_env(:bohongan, :port, port)

    # Initialize the application
    {:ok, _} = Application.ensure_all_started(:bohongan)

    # Load and convert all Proto files, then merge
    results = proto_files
              |> Enum.map(fn file ->
                case Bohongan.ProtoLoader.load_proto_file(file) do
                  {:ok, schema} -> {:ok, file, schema}
                  {:error, reason} -> {:error, file, reason}
                end
              end)

    # Check if there were any errors
    errors = Enum.filter(results, fn
      {:error, _, _} -> true
      _ -> false
    end)

    if not Enum.empty?(errors) do
      IO.puts("Error: Failed to load the following Proto files:")
      Enum.each(errors, fn {:error, file, reason} ->
        IO.puts("  - #{file}: #{reason}")
      end)
      System.halt(1)
    end

    # Merge all schemas
    merged_data = results
                  |> Enum.map(fn {:ok, file, schema} -> {file, schema} end)
                  |> merge_json_data()

    # Load the merged data into the store
    Bohongan.Store.load_data(merged_data)

    # Start the server
    IO.puts("Bohongan JSON Server is running at http://localhost:#{port}")
    IO.puts("  Serving API generated from #{length(proto_files)} files:")
    Enum.each(proto_files, fn file -> IO.puts("    - #{file}") end)
    IO.puts("  Press Ctrl+C to stop")

    # This keeps the application running
    Process.sleep(:infinity)
  end

  @doc """
  Merges JSON data from multiple files, with resolution for conflicts.

  When the same resource exists in multiple files, the data from later
  files takes precedence, but attempts to preserve all records by merging
  arrays rather than replacing them completely.
  """
  def merge_json_data(files_with_data) do
    Enum.reduce(files_with_data, %{}, fn {file, data}, acc ->
      # For each file's data, merge into the accumulator
      Map.merge(acc, data, fn _key, acc_value, new_value ->
        # If both values are lists (collections), combine them
        if is_list(acc_value) and is_list(new_value) do
          # For arrays, use a smart merge strategy to avoid duplicates by ID
          merge_collections(acc_value, new_value)
        else
          # For non-array values (like singleton objects), prefer the newer value
          IO.puts("Warning: Resource conflict in file #{file}, using newer definition")
          new_value
        end
      end)
    end)
  end

  @doc """
  Merges two collections of items, avoiding duplicates by ID.

  If an item with the same ID exists in both collections, the one from
  the new collection is preferred.
  """
  def merge_collections(existing, new) do
    # Convert to a map with ID as key for efficient lookup
    existing_map = existing
                   |> Enum.filter(&(is_map(&1) and Map.has_key?(&1, "id")))
                   |> Enum.map(fn item -> {to_string(item["id"]), item} end)
                   |> Map.new()

    # Process each item in the new collection
    new_processed = Enum.reduce(new, existing_map, fn item, acc ->
      # Only process map items with an ID
      if is_map(item) and Map.has_key?(item, "id") do
        # Add/replace the item in our accumulator
        Map.put(acc, to_string(item["id"]), item)
      else
        # For items without an ID, just add to accumulator as-is
        acc
      end
    end)

    # Get non-map items or items without IDs from both collections
    non_id_items = (existing ++ new)
                   |> Enum.filter(fn item ->
                     not (is_map(item) and Map.has_key?(item, "id"))
                   end)

    # Return the combined collection
    Map.values(new_processed) ++ non_id_items
  end
end
