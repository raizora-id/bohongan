defmodule Bohongan.CLITest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  alias Bohongan.CLI

  # Helper function to create a temporary JSON file for testing
  defp with_temp_file(content, fun) do
    # Create a temp file
    {:ok, path} = Temp.open("bohongan-test", &IO.write(&1, content))

    try do
      # Call the function with the path
      fun.(path)
    after
      # Ensure we clean up
      File.rm(path)
    end
  end

  test "prints help when --help option is provided" do
    output = capture_io(fn ->
      CLI.main(["--help"])
    end)

    assert output =~ "Usage: bohongan --data=FILE"
    assert output =~ "--data FILE"
    assert output =~ "--port PORT"
    assert output =~ "--help"
  end

  test "prints help when no options are provided" do
    output = capture_io(fn ->
      CLI.main([])
    end)

    assert output =~ "Error: Missing required option --data"
    assert output =~ "Usage: bohongan --data=FILE"
  end

  test "prints error for non-existent file" do
    # Use a path that definitely doesn't exist
    non_existent_path = "/path/to/nowhere/that/doesnt/exist.json"

    output = capture_io(fn ->
      # Trap the exit to prevent test from stopping
      try do
        CLI.main(["--data=#{non_existent_path}"])
      catch
        :exit, _ -> :ok
      end
    end)

    assert output =~ "Error: File '#{non_existent_path}' not found"
  end

  # This test checks that the CLI can parse valid options
  # We don't actually start the server to avoid test hanging
  test "parses data and port options" do
    json_content = ~s({"test": []})

    with_temp_file(json_content, fn path ->
      # Mock the start_server function to verify arguments
      # We'll use process dictionary as a simple way to verify the function was called
      # with expected arguments
      original_start_server = :erlang.fun_to_list(&CLI.start_server/2)

      try do
        :meck.new(CLI, [:passthrough])
        :meck.expect(CLI, :start_server, fn file, port ->
          # Store the args for verification
          Process.put(:cli_test_file, file)
          Process.put(:cli_test_port, port)
          # Return something to avoid hanging
          :ok
        end)

        # Call with both data and port
        CLI.main(["--data=#{path}", "--port=4000"])

        # Verify the arguments were passed correctly
        assert Process.get(:cli_test_file) == path
        assert Process.get(:cli_test_port) == 4000

        # Reset process dictionary
        Process.delete(:cli_test_file)
        Process.delete(:cli_test_port)

        # Call with just data (should use default port)
        CLI.main(["--data=#{path}"])

        # Verify the arguments were passed correctly
        assert Process.get(:cli_test_file) == path
        assert Process.get(:cli_test_port) == 3000
      after
        :meck.unload(CLI)
      end
    end)
  end

  # This test is more of an integration test and requires the temp package
  # It verifies that a valid JSON file can be loaded
  test "loads valid JSON file" do
    json_content = ~s({"posts": [{"id": 1, "title": "Test"}]})

    with_temp_file(json_content, fn path ->
      # Mock functions to avoid actually starting the server
      try do
        :meck.new(Application, [:passthrough])
        :meck.expect(Application, :ensure_all_started, fn _ -> {:ok, []} end)

        :meck.new(Bohongan.Store, [:passthrough])
        :meck.expect(Bohongan.Store, :load_data, fn data ->
          # Store the data for verification
          Process.put(:store_test_data, data)
          :ok
        end)

        :meck.new(Process, [:passthrough])
        :meck.expect(Process, :sleep, fn _ -> :ok end)

        output = capture_io(fn ->
          CLI.main(["--data=#{path}"])
        end)

        # Verify the output
        assert output =~ "Bohongan JSON Server is running"
        assert output =~ "Serving data from: #{path}"

        # Verify the data was parsed correctly
        loaded_data = Process.get(:store_test_data)
        assert is_map(loaded_data)
        assert Map.has_key?(loaded_data, "posts")
        assert is_list(loaded_data["posts"])
        assert length(loaded_data["posts"]) == 1
        assert hd(loaded_data["posts"])["id"] == 1
        assert hd(loaded_data["posts"])["title"] == "Test"
      after
        :meck.unload(Application)
        :meck.unload(Bohongan.Store)
        :meck.unload(Process)
      end
    end)
  end
end
