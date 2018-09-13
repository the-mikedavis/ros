defmodule ROS.MixProject do
  use Mix.Project

  def project do
    [
      app: :ros,
      version: "0.1.0",
      elixir: "~> 1.5",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.html": :test,
        credo: :test,
        bless: :test
      ],
      test_coverage: [tool: ExCoveralls],
      aliases: aliases()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {ROS.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      # Upstream
      {:phoenix, github: "phoenixframework/phoenix", override: true},
      {:phoenix_pubsub, "~> 1.1"},
      {:phoenix_html, "~> 2.11"},
      {:phoenix_live_reload, "~> 1.0", only: :dev},
      {:gettext, "~> 0.11"},
      {:jason, "~> 1.0"},
      {:cowboy, "~> 2.4", override: true},
      {:xenium, git: "https://github.com/the-mikedavis/xenium.git"},
      {:bite, git: "https://github.com/the-mikedavis/bite.git"},
      # Testing and code cleanliness
      {:private, "~> 0.1.1"},
      {:excoveralls, "~> 0.7", only: :test},
      {:credo, "~> 0.9", only: :test, runtime: false},
      {:dialyxir, "~> 0.5", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      bless: [&bless/1]
    ]
  end

  defp bless(_) do
    [
      {"format", ["--check-formatted"]},
      {"compile", ["--warnings-as-errors", "--force"]},
      {"coveralls.html", []},
      {"credo", []},
      {"dialyzer", []}
    ]
    |> Enum.each(fn {task, args} ->
      IO.ANSI.format([:cyan, "Running #{task} with args #{inspect(args)}"])
      |> IO.puts()

      Mix.Task.run(task, args)
    end)
  end
end
