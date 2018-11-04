defmodule Mix.Tasks.Genmsg do
  use Mix.Task

  alias ROS.Compiler

  @moduledoc """
  A task for compiling ROS message types into Elixir structs.

  Add the messages that you want to your `mix.exs`:

  ```
  # mix.exs
  ...
  def project do
    [
      msg: messages()
      ...
    ]
  end

  def messages do
    [
      "sensor_msgs/Image",
      {:pattern, "std_msgs"}
    ]
  end
  ```

  Running `mix genmsg` after this will produce structs for `SensorMsgs.Image`
  and `StdMsgs.*` under `lib/generated_msgs/`. It is recommended to put this
  directory in your `.gitignore`.

  Giving the `{:pattern, String.t()}` directive will tell the compiler to
  create structs for all available message types that contain the given
  pattern.
  """

  @shortdoc "Compiles requested messages"
  @recursive false

  def run(argv), do: Compiler.install(argv, :msg)
end
