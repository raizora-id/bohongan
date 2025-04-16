defmodule Bohongan.Router do
  @moduledoc """
  HTTP Router for the Bohongan JSON server.

  This module defines the HTTP endpoints using Plug.Router
  and handles routing requests to the appropriate Store functions.
  """
  use Plug.Router

  plug Plug.Logger
  plug :match
  plug Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Jason
  plug :dispatch

  # Root endpoint - list available resources
  get "/" do
    resources = Bohongan.Store.get_resources()
    routes = resources
             |> Enum.map(fn resource ->
               %{
                 resource: resource,
                 endpoints: [
                   %{method: "GET", url: "/#{resource}"},
                   %{method: "GET", url: "/#{resource}/:id"},
                   %{method: "POST", url: "/#{resource}"},
                   %{method: "PUT", url: "/#{resource}/:id"},
                   %{method: "PATCH", url: "/#{resource}/:id"},
                   %{method: "DELETE", url: "/#{resource}/:id"}
                 ]
               }
             end)

    send_json(conn, 200, %{
      resources: resources,
      routes: routes
    })
  end

  # Get all items from a collection
  get "/:resource" do
    collection = Bohongan.Store.get_collection(resource)
    send_json(conn, 200, collection)
  end

  # Get a specific item
  get "/:resource/:id" do
    case Bohongan.Store.get_item(resource, id) do
      nil -> send_json(conn, 404, %{error: "Item not found"})
      item -> send_json(conn, 200, item)
    end
  end

  # Create a new item
  post "/:resource" do
    item = Bohongan.Store.create_item(resource, conn.body_params)
    send_json(conn, 201, item)
  end

  # Update an item (full replace)
  put "/:resource/:id" do
    case Bohongan.Store.update_item(resource, id, conn.body_params) do
      {:ok, item} -> send_json(conn, 200, item)
      {:error, :not_found} -> send_json(conn, 404, %{error: "Item not found"})
    end
  end

  # Update an item (partial update)
  patch "/:resource/:id" do
    case Bohongan.Store.update_item(resource, id, conn.body_params) do
      {:ok, item} -> send_json(conn, 200, item)
      {:error, :not_found} -> send_json(conn, 404, %{error: "Item not found"})
    end
  end

  # Delete an item
  delete "/:resource/:id" do
    case Bohongan.Store.delete_item(resource, id) do
      :ok -> send_resp(conn, 204, "")
      {:error, :not_found} -> send_json(conn, 404, %{error: "Item not found"})
    end
  end

  # Catch-all for non-existent routes
  match _ do
    send_json(conn, 404, %{error: "Not found"})
  end

  defp send_json(conn, status, data) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(data))
  end
end
