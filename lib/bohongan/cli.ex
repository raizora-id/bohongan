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
        data: :string,
        proto: :string,
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

    cond do
      Keyword.has_key?(options, :help) ->
        print_help()
      Keyword.has_key?(options, :data) ->
        data_file = Keyword.get(options, :data)
        port = Keyword.get(options, :port, 3000)
        start_server_with_json(data_file, port)
      Keyword.has_key?(options, :proto) ->
        proto_file = Keyword.get(options, :proto)
        port = Keyword.get(options, :port, 3000)
        start_server_with_proto(proto_file, port)
      true ->
        IO.puts("Error: Missing required option --data or --proto")
        print_help()
    end
  end

  defp print_help do
    IO.puts """
    Usage: bohongan [options]

    Options:
      -d, --data FILE     JSON file to use as data source
      -p, --proto FILE    Protocol Buffer file to use for API generation
      -P, --port PORT     Port to use (default: 3000)
      -h, --help          Show this help message

    You must specify either --data or --proto.
    """
  end

  defp start_server_with_json(data_file, port) do
    # Validate JSON file exists
    unless File.exists?(data_file) do
      IO.puts("Error: File '#{data_file}' not found")
      System.halt(1)
    end

    # Update application environment with the specified port
    Application.put_env(:bohongan, :port, port)

    # Initialize the application
    {:ok, _} = Application.ensure_all_started(:bohongan)

    # Load the JSON data and pass it to the store
    json_data = data_file
                |> File.read!()
                |> Jason.decode!()

    Bohongan.Store.load_data(json_data)

    # Start the server
    IO.puts("Bohongan JSON Server is running at http://localhost:#{port}")
    IO.puts("  Serving data from: #{data_file}")
    IO.puts("  Press Ctrl+C to stop")

    # This keeps the application running
    Process.sleep(:infinity)
  end

  defp start_server_with_proto(proto_file, port) do
    # Validate Proto file exists
    unless File.exists?(proto_file) do
      IO.puts("Error: File '#{proto_file}' not found")
      System.halt(1)
    end

    # Update application environment with the specified port
    Application.put_env(:bohongan, :port, port)

    # Initialize the application
    {:ok, _} = Application.ensure_all_started(:bohongan)

    # Load the Proto file and convert to JSON schema
    case Bohongan.ProtoLoader.load_proto_file(proto_file) do
      {:ok, json_data} ->
        # Load the converted data into the store
        Bohongan.Store.load_data(json_data)

        # Start the server
        IO.puts("Bohongan JSON Server is running at http://localhost:#{port}")
        IO.puts("  Serving API generated from: #{proto_file}")
        IO.puts("  Press Ctrl+C to stop")

        # This keeps the application running
        Process.sleep(:infinity)

      {:error, reason} ->
        IO.puts("Error: Failed to load Proto file: #{reason}")
        System.halt(1)
    end
  end
end
