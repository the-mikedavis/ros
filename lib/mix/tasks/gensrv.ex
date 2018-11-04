defmodule Mix.Tasks.Gensrv do
  use Mix.Task

  alias ROS.Compiler

  @shortdoc "Compiles requested srvs"
  @recursive false

  @moduledoc """
  A task for compiling ROS srv types into Elixir structs.

  Add the messages that you want to your `mix.exs`:

  ```
  # mix.exs
  ...
  def project do
    [
      srv: srvs()
      ...
    ]
  end

  def srvs do
    [
      {:pattern, "rospy_tutorials"}
    ]
  end
  ```

  Running `mix gensrv` after this will produce structs for all the srvs
  available that contain `rospy_tutorials` under `lib/generated_srvs/`. It is
  recommended to put this directory in your `.gitignore`. You can also use
  plain strings in this list. The compiler will try to create a struct for
  that exact srv name.
  """

  def run(argv), do: Compiler.install(argv, :srv)
end
