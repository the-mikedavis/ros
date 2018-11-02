defmodule Mix.Tasks.Genmsg do
  use Mix.Task

  alias ROS.Compiler

  @shortdoc "Compiles requested messages"
  @recursive false

  def run(argv), do: Compiler.install(argv, :msg)
end
