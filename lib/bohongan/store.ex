defmodule Bohongan.Store do
  @moduledoc """
  A GenServer that stores and manages the JSON data.

  This module provides the data store for the JSON server and
  implements functions for manipulating collections and items.
  """
  use GenServer

  # Client API

  @doc """
  Starts the store process.
  """
  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Loads data from a parsed JSON object into the store.
  """
  def load_data(json_data) do
    GenServer.call(__MODULE__, {:load_data, json_data})
  end

  @doc """
  Gets a list of all available resources.
  """
  def get_resources do
    GenServer.call(__MODULE__, :get_resources)
  end

  @doc """
  Gets all items from a collection.
  """
  def get_collection(resource) do
    GenServer.call(__MODULE__, {:get_collection, resource})
  end

  @doc """
  Gets a specific item by ID.
  """
  def get_item(resource, id) do
    GenServer.call(__MODULE__, {:get_item, resource, id})
  end

  @doc """
  Creates a new item in a collection.
  """
  def create_item(resource, item) do
    GenServer.call(__MODULE__, {:create_item, resource, item})
  end

  @doc """
  Updates an item by ID.
  """
  def update_item(resource, id, item) do
    GenServer.call(__MODULE__, {:update_item, resource, id, item})
  end

  @doc """
  Deletes an item by ID.
  """
  def delete_item(resource, id) do
    GenServer.call(__MODULE__, {:delete_item, resource, id})
  end

  # Server Callbacks

  @impl true
  def init(_) do
    {:ok, %{data: %{}, id_counters: %{}}}
  end

  @impl true
  def handle_call({:load_data, json_data}, _from, _state) do
    # Initialize id counters for each resource
    id_counters = json_data
                  |> Map.keys()
                  |> Enum.map(fn resource ->
                    items = Map.get(json_data, resource, [])
                    # Handle both array resources and singular object resources
                    max_id = if is_list(items) do
                      items
                      |> Enum.map(fn item -> Map.get(item, "id", 0) end)
                      |> Enum.max(fn -> 0 end)
                    else
                      Map.get(items, "id", 0)
                    end
                    {resource, max_id + 1}
                  end)
                  |> Map.new()

    {:reply, :ok, %{data: json_data, id_counters: id_counters}}
  end

  @impl true
  def handle_call(:get_resources, _from, state) do
    resources = Map.keys(state.data)
    {:reply, resources, state}
  end

  @impl true
  def handle_call({:get_collection, resource}, _from, state) do
    collection = Map.get(state.data, resource, [])
    {:reply, collection, state}
  end

  @impl true
  def handle_call({:get_item, resource, id}, _from, state) do
    collection = Map.get(state.data, resource, [])

    # Handle both array resources and singular object resources
    item = if is_list(collection) do
      Enum.find(collection, fn item ->
        to_string(Map.get(item, "id")) == to_string(id)
      end)
    else
      # If the resource is a singular object with matching ID, return it
      if to_string(Map.get(collection, "id", "")) == to_string(id) do
        collection
      else
        nil
      end
    end

    {:reply, item, state}
  end

  @impl true
  def handle_call({:create_item, resource, item}, _from, state) do
    # Get the next ID for this resource
    next_id = Map.get(state.id_counters, resource, 1)

    # Add ID to the item
    item_with_id = Map.put(item, "id", next_id)

    # Update the collection
    collection = Map.get(state.data, resource, [])
    updated_collection = if is_list(collection) do
      [item_with_id | collection]
    else
      # If the resource was previously a singular object, convert to array
      [item_with_id, collection]
    end

    # Update the state
    updated_data = Map.put(state.data, resource, updated_collection)
    updated_counters = Map.put(state.id_counters, resource, next_id + 1)

    {:reply, item_with_id, %{data: updated_data, id_counters: updated_counters}}
  end

  @impl true
  def handle_call({:update_item, resource, id, updates}, _from, state) do
    collection = Map.get(state.data, resource, [])

    if is_list(collection) do
      # Handle array resources
      {item, remaining} = collection
                          |> Enum.split_with(fn item ->
                            to_string(Map.get(item, "id")) == to_string(id)
                          end)

      case item do
        [found | _] ->
          # Update the item
          updated_item = Map.merge(found, updates)
          updated_item = Map.put(updated_item, "id", Map.get(found, "id"))

          # Update the collection
          updated_collection = [updated_item | remaining]
          updated_data = Map.put(state.data, resource, updated_collection)

          {:reply, {:ok, updated_item}, %{state | data: updated_data}}

        [] ->
          {:reply, {:error, :not_found}, state}
      end
    else
      # Handle singleton object resources
      if to_string(Map.get(collection, "id", "")) == to_string(id) do
        # Update the singleton object
        updated_item = Map.merge(collection, updates)
        updated_item = Map.put(updated_item, "id", Map.get(collection, "id"))

        # Update the data
        updated_data = Map.put(state.data, resource, updated_item)

        {:reply, {:ok, updated_item}, %{state | data: updated_data}}
      else
        {:reply, {:error, :not_found}, state}
      end
    end
  end

  @impl true
  def handle_call({:delete_item, resource, id}, _from, state) do
    collection = Map.get(state.data, resource, [])

    if is_list(collection) do
      # Handle array resources
      {to_delete, remaining} = collection
                              |> Enum.split_with(fn item ->
                                to_string(Map.get(item, "id")) == to_string(id)
                              end)

      case to_delete do
        [_found | _] ->
          # Update the collection
          updated_data = Map.put(state.data, resource, remaining)
          {:reply, :ok, %{state | data: updated_data}}

        [] ->
          {:reply, {:error, :not_found}, state}
      end
    else
      # Handle singleton object resources
      if to_string(Map.get(collection, "id", "")) == to_string(id) do
        # Remove the singleton object (set to empty map)
        updated_data = Map.put(state.data, resource, %{})
        {:reply, :ok, %{state | data: updated_data}}
      else
        {:reply, {:error, :not_found}, state}
      end
    end
  end
end
