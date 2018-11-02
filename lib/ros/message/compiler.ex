defmodule ROS.Message.Compiler do
  alias ROS.{Compiler, Helpers}

  @moduledoc """
  Message generator for Elixir based messages.

  Converts the `*.msg` files into a module with a struct and typing.
  """

  @doc "Create an Elixir module from a msg body and a name for that msg."
  @spec create_module(binary(), binary(), binary()) ::
          {atom(), atom() | binary()}
  def create_module(payload, name, md5sum) do
    {types, typespec, struct, constants} = Compiler.parse(payload)

    {:ok,
     form_module(
       name,
       typespec,
       types,
       struct,
       constants,
       md5sum,
       payload
     )}
  end

  defp form_module(name, typespec, types, struct, constants, md5sum, raw) do
    mod_name = Helpers.module(name)

    definition = Compiler.prefix_all(raw, "    ")

    constants =
      constants
      |> Enum.map(&Compiler.prefix(&1, "  "))
      |> Enum.join("\n\n")

    """
    defmodule #{mod_name} do
      @behaviour ROS.Message.Behaviour

      @type t :: %__MODULE__{#{typespec}}

      defstruct [#{struct}]

      @impl ROS.Message.Behaviour
      def md5sum, do: "#{String.trim(md5sum)}"

      @impl ROS.Message.Behaviour
      def definition do
        "\""\n#{definition}
        "\""
      end

      @impl ROS.Message.Behaviour
      def types, do: [#{types}]\n\n#{constants}
    end
    """
  end
end
