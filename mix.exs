
# mix.exs
defmodule Bohongan.MixProject do
  use Mix.Project

  def project do
    [
      app: :bohongan,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: escript()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Bohongan.Application, []}
    ]
  end

  defp deps do
    [
      {:plug_cowboy, "~> 2.6"},
      {:jason, "~> 1.4"}
    ]
  end

  defp escript do
    [
      main_module: Bohongan.CLI,
      name: "bohongan"
    ]
  end
end