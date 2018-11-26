defmodule ROS.Service.Compiler do
  alias ROS.{Compiler, Helpers}

  @moduledoc false
  # Srv generator for Elixir based services.
  # Converts the `*.srv` files into a module with a struct and typing.

  # Create an Elixir module from a msg body and a name for that msg.
  @spec create_module(binary(), binary(), binary()) ::
          {atom(), atom() | binary()}
  def create_module(payload, name, md5sum) do
    [request, response] =
      payload
      |> String.split("---\n")
      |> Enum.map(&Compiler.parse/1)
      |> Enum.map(&form_submodule/1)
      |> Enum.map(&Compiler.prefix_all(&1, "  "))

    {:ok, form_module(request, response, name, md5sum, payload)}
  end

  defp form_submodule({types, typespec, struct, constants}) do
    constants =
      constants
      |> Enum.map(&Compiler.prefix(&1, "  "))
      |> Enum.join("\n\n")

    """
    @moduledoc false
    @type t :: %__MODULE__{#{typespec}}

    defstruct [#{struct}]

    def types, do: [#{types}]\n\n#{constants}
    """
  end

  defp form_module(request, response, name, md5sum, raw) do
    mod_name = Helpers.module(name)

    definition = Compiler.prefix_all(raw, "    ")

    """
    defmodule #{mod_name} do
      @moduledoc false

      defmodule #{mod_name}.Request do\n#{request}
      end

      defmodule #{mod_name}.Response do\n#{response}
      end

      def md5sum, do: "#{String.trim(md5sum)}"

      def definition do
        "\""\n#{definition}
        "\""
      end
    end
    """
  end
end
