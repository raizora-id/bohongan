defmodule Bohongan.Application do
  @moduledoc """
  The Bohongan Application Service.

  This is the main entry point for the application when started
  through the supervision tree.
  """
  use Application

  @impl true
  def start(_type, _args) do
    port = Application.get_env(:bohongan, :port, 3000)

    children = [
      {Bohongan.Store, []},
      {Plug.Cowboy, scheme: :http, plug: Bohongan.Router, options: [port: port]}
    ]

    opts = [strategy: :one_for_one, name: Bohongan.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
