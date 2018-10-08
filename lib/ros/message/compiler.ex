defmodule ROS.Message.Compiler do
  use Private

  @moduledoc """
  Message generator for Elixir based messages.

  Converts the `*.msg` files into a module with a struct and typing.
  """

  @doc "Create an Elixir module from a msg body and a name for that msg."
  @spec create_module(binary(), binary(), binary()) :: {atom(), atom() | binary()}
  def create_module(payload, name, md5sum) do
    {parsed, constants} =
      payload
      |> String.trim()
      |> String.split("\n")
      |> Enum.reject(&leading_whitespace?/1)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&comments?/1)
      |> Enum.map(&parse/1)
      |> parse_constants()

    typespec = typespec_guts(parsed)
    types_guts = types_guts(parsed)
    struct_def = struct_guts(parsed)

    {:ok, form_module(name, typespec, types_guts, struct_def, constants, md5sum, payload)}
  end

  @spec underscore(String.t()) :: [String.t()]
  def underscore(name) do
    name
    |> String.split("/")
    |> Enum.map(&Macro.underscore/1)
  end

  private do
    defp form_module(name, typespec, types_guts, struct_def, constants, md5sum, raw) do
      mod_name = modularize(name)
      definition =
        raw
        |> String.trim()
        |> String.split("\n")
        |> Enum.map(fn s -> "    " <> s end )
        |> Enum.join("\n")

      constants = Enum.map(constants, fn c -> "  " <> c end)

      """
      defmodule #{mod_name} do
        @behaviour ROS.Message.Behaviour

        @type t :: %__MODULE__{#{typespec}}

        defstruct [#{struct_def}]

        @impl ROS.Message.Behaviour
        def md5sum, do: "#{String.trim(md5sum)}"

        @impl ROS.Message.Behaviour
        def definition do
          "\""\n#{definition}
          "\""
        end

        @impl ROS.Message.Behaviour
        def types, do: [#{types_guts}]\n\n#{Enum.join(constants, "\n\n")}
      end
      """
    end

    @spec comments?(String.t()) :: boolean()
    defp comments?(""), do: true
    defp comments?("#" <> _), do: true
    defp comments?(_), do: false

    @spec leading_whitespace?(String.t()) :: boolean()
    defp leading_whitespace?(line), do: String.starts_with?(line, " ")

    @spec typespec_guts({binary(), binary(), binary(), binary()}) :: binary()
    defp typespec_guts(parsed_msg) do
      parsed_msg
      |> Enum.map(fn {type, _original_type, name, _default} ->
        "#{name}: #{type}"
      end)
      |> Enum.join(", ")
    end

    @spec types_guts({binary(), binary(), binary(), binary()}) :: binary()
    defp types_guts(parsed_msg) do
      parsed_msg
      |> Enum.map(fn {_type, original_type, name, _default} ->
        "#{name}: :\"#{original_type}\""
      end)
      |> Enum.join(", ")
    end

    @spec struct_guts({binary(), binary(), binary(), binary()}) :: binary()
    defp struct_guts(parsed_msg) do
      parsed_msg
      |> Enum.map(fn {_type, _original_type, name, default} ->
        "#{name}: #{default}"
      end)
      |> Enum.join(", ")
    end

    defp parse_constants(parsed) do
      {constants, others} =
        Enum.split_with(parsed, fn {_type, _original_type, name, _default} ->
          String.contains?(name, "=")
        end)

      constant_funs =
        Enum.map(constants, fn
          {_t, "string", name} ->
            [fun_name, value] = String.split(name, "=")

            "def #{String.downcase(fun_name)}, do: \"#{value}\""
          {_t, _ot, name, _} ->
            [fun_name, value] = String.split(name, "=")

            "def #{String.downcase(fun_name)}, do: #{value}"
        end)

      {others, constant_funs}
    end

    # match / replace the angular brackets of a list / array
    @list_regex ~r/\[.*\]/

    # parse a line from a msg file into its components / values and defaults
    @spec parse(binary()) :: {binary(), binary(), binary(), binary()}
    defp parse(entity) do
      parse(entity, Regex.match?(@list_regex, entity))
    end

    # parse based on whether or not its a list type
    @spec parse(binary(), boolean()) :: {binary(), binary(), binary(), binary()}
    defp parse(entity, true) do
      # parse like a non-list type
      {type, original_type, name, _default} =
        @list_regex
        |> Regex.replace(entity, "")
        |> parse(false)

      # become a list type
      {"list(#{type})", original_type, name, "[]"}
    end

    # not a list (a regular type)
    defp parse(entity, false) do
      [original_type, name] =
        entity
        |> String.trim()
        |> String.split(~r/\s+/)
        |> Enum.take(2)

      {type, default} = spec(original_type)

      {type, original_type, name, default}
    end

    # parse out the erlang type and the default value for that type from the
    # ROS built-in type.
    @spec spec(binary()) :: {binary(), binary()}
    defp spec("string"), do: {"binary()", ~s("")}
    defp spec("bool"), do: {"atom()", "false"}
    defp spec("int" <> _byte_size), do: {"integer()", "0"}
    defp spec("uint" <> _byte_size), do: {"non_neg_integer()", "0"}
    defp spec("float" <> _byte_size), do: {"float()", "0.0"}
    @times ["time", "duration"]
    defp spec(t) when t in @times do
      {:ok, time} = Time.new(0, 0, 0)

      # TODO conform to ROS time

      {"Time.t()", "#{inspect(time)}"}
    end

    def spec("Header"), do: {"StdMsgs.Header.t()", "%StdMsgs.Header{}"}

    def spec(t) when is_binary(t) do
      module = modularize(t)

      {"#{module}.t()", "%#{module}{}"}
    end

    # make things like `sensor_msgs/Image` safe to be module names
    @spec modularize(binary()) :: binary()
    defp modularize(unsafe_string) do
      unsafe_string
      |> String.split("/")
      |> Enum.map(&Macro.camelize/1)
      |> Enum.join(".")
    end
  end
end
