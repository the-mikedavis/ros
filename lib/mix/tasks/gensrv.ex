defmodule Mix.Tasks.Gensrv do
  use Mix.Task

  alias ROS.Compiler

  @shortdoc "Compiles requested srvs"
  @recursive false

  def run(argv), do: Compiler.install(argv, :srv)
end
