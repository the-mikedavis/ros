defmodule Mix.Tasks.Genmsg do
  use Mix.Task
  use Private

  alias ROS.Message.Compiler

  @shortdoc "Compiles all available messages"
  @recursive false

  # compile all messages
  def run([]) do
    {all, 0} = System.cmd("rosmsg", ["list"])

    all
    |> String.split()
    |> install_all()
  end

  # compile specific messages
  def run(args) do
    install_all(args)
  end

  private do
    defp install_all(all) do
      all
      |> Enum.chunk_every(20)
      |> Enum.each(fn chunk ->
        pmap(chunk, &install/1)
      end)
    end

    defp install(name) do
      {definition, 0} = System.cmd("rosmsg", ["show", name])
      {md5sum, 0} = System.cmd("rosmsg", ["md5", name])
      underscored = Compiler.underscore(name)
      make_project_directory(underscored)
      path = path_for(underscored)

      with false <- File.exists?(path),
           {:ok, module} <- Compiler.create_module(definition, name, md5sum) do#,
           #formatted <- Code.format_string!(module) do
        IO.puts("Compile successful. Installing #{name} to #{path}.")

        path
        |> File.open!([:write, :utf8])
        |> IO.binwrite(module)
        # |> IO.binwrite(formatted)
      else
        {:error, reason} -> IO.puts("Skipping #{name}: #{reason}")
      end
    end

    defp make_project_directory(underscored) do
      [_filename | dirs] =
        Enum.reverse(["lib", "generated_messages" | underscored])

      dirs
      |> Enum.reverse()
      |> Path.join()
      |> File.mkdir_p!()
    end

    defp path_for(underscored) do
      Path.join(["lib", "generated_messages" | underscored]) <> ".ex"
    end

    defp pmap(enum, func) do
      enum
      |> Enum.map(&Task.async(fn -> func.(&1) end))
      |> Enum.map(&Task.await/1)
    end
  end
end
