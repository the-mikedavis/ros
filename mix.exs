defmodule ROS.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :ros,
      version: @version,
      elixir: "~> 1.5",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.html": :test,
        credo: :test,
        bless: :test
      ],
      test_coverage: [tool: ExCoveralls],
      aliases: aliases(),
      name: "ROS",
      package: package(),
      source_url: "https://github.com/the-mikedavis/ros.git",
      description: "An Actor Model client library for ROS.",
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # upstream
      {:cowboy, "~> 2.4"},
      {:xenium, git: "https://github.com/the-mikedavis/xenium.git"},
      {:bite, git: "https://github.com/the-mikedavis/bite.git"},
      {:satchel, git: "https://github.com/the-mikedavis/satchel.git"},

      # testing
      {:mox, "~> 0.4.0"},
      {:private, "~> 0.1.1"},
      {:excoveralls, "~> 0.7", only: :test},
      {:credo, "~> 0.9", only: :test, runtime: false},
      {:dialyxir, "~> 0.5", only: [:dev, :test], runtime: false},

      # docs
      {:ex_doc, "~> 0.19.1"}
    ]
  end

  defp package do
    [
      maintainers: ["Michael Davis"],
      licenses: ["BSD3"],
      links: %{github: "https://github.com/the-mikedavis/ros.git"},
      files: ~w(lib LICENSE mix.exs README.md .formatter.exs)
    ]
  end

  defp docs do
    [
      source_ref: "v#{@version}",
      extras: extras()
    ]
  end

  defp extras do
    [
      "guides/getting_started.md"
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
      [:cyan, "Running #{task} with args #{inspect(args)}"]
      |> IO.ANSI.format()
      |> IO.puts()

      Mix.Task.run(task, args)
    end)
  end
end
