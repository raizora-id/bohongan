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
        port: :integer,
        help: :boolean
      ],
      aliases: [
        d: :data,
        p: :port,
        h: :help
      ]
    )

    cond do
      Keyword.has_key?(options, :help) ->
        print_help()
      Keyword.has_key?(options, :data) ->
        data_file = Keyword.get(options, :data)
        port = Keyword.get(options, :port, 3000)
        start_server(data_file, port)
      true ->
        IO.puts("Error: Missing required option --data")
        print_help()
    end
  end

  defp print_help do
    IO.puts """
    Usage: bohongan --data=FILE [options]

    Options:
      -d, --data FILE     JSON file to use as data source (required)
      -p, --port PORT     Port to use (default: 3000)
      -h, --help          Show this help message
    """
  end

  defp start_server(data_file, port) do
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
end
