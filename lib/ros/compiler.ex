defmodule ROS.Compiler do
  use Private
  alias ROS.Helpers

  @moduledoc false

  # This module is just full of common functions for compiling msgs and srvs
  # from `*.msg` and `*.srv` files into Elixir structs

  # a single field from a definition
  # once parsed, contains a tuple of
  #
  # - erlang type (for the dialyzer) i.e. integer(), binary(), String.t(), ...
  # - ros type i.e. int8, uint32, float64, ...
  # - name of the field i.e. "data", "a", "b", "my_custom_name", ...
  # - default value in the struct i.e. 0, 0.0, "", %StdMsgs.Header{}, ...
  @type parsed_field :: {binary(), binary(), binary(), binary()}

  # parse a *msg* definition into its information:
  # - types
  # - typespec definition
  # - struct definition
  # - constants
  #
  # this only works on msg definitions, so additional preprocessing will need
  # to be done for structs
  @spec parse(String.t()) :: {String.t(), String.t(), String.t(), [String.t()]}
  def parse(definition) do
    {parsed, constant_definitions} =
      definition
      |> prepare_definition()
      |> Enum.map(&parse_line/1)
      |> Enum.map(&cleanse/1)
      |> parse_constants()

    {types_guts(parsed), typespec_guts(parsed), struct_guts(parsed), constant_definitions}
  end

  @spec prefix(String.t(), String.t()) :: String.t()
  def prefix(str, spaces), do: spaces <> str

  @spec prefix_all([String.t()], String.t()) :: [String.t()]
  def prefix_all(raw, spaces) do
    raw
    |> String.trim()
    |> String.split("\n")
    |> Enum.map(&prefix(&1, spaces))
    |> Enum.join("\n")
  end

  private do
    # removes whitespace, comments, etc. and splits on newlines
    @spec prepare_definition(String.t()) :: [String.t()]
    defp prepare_definition(definition) do
      definition
      |> String.trim()
      |> String.split("\n")
      # remove nested definitions, which are uninteresting for creating structs
      # because the nested structs are separate modules/structs
      |> Enum.reject(&leading_whitespace?/1)
      |> Enum.map(&String.trim/1)
      # get rid of uninteresting lines
      |> Enum.reject(&empty?/1)
    end

    # does a string start with a space?
    @spec leading_whitespace?(String.t()) :: boolean()
    defp leading_whitespace?(line), do: String.starts_with?(line, " ")

    # is this an line empty? i.e. it has no characters or starts with an
    # octothorpe [#] (denotes a comment)
    @spec empty?(String.t()) :: boolean()
    defp empty?(""), do: true
    defp empty?("#" <> _), do: true
    defp empty?(_), do: false

    # match / replace the angular brackets of a list / array
    @list_regex ~r/\[.*\]/

    # parse a line from a msg file into its components / values and defaults
    @spec parse_line(binary()) :: parsed_field()
    defp parse_line(entity) do
      parse(entity, Regex.match?(@list_regex, entity))
    end

    # gets rid of deprecated ros types `char` and `byte`
    @spec cleanse(parsed_field()) :: parsed_field()
    defp cleanse({_type, "char", name, default}) do
      {"non_neg_integer()", "uint8", name, default}
    end

    defp cleanse({_type, "byte", name, default}) do
      {"integer()", "int8", name, default}
    end

    defp cleanse(parsed), do: parsed

    # parse a list type into the `parsed_field` four-tuple
    # calls the `parse/2` for regular types underneath and then dresses
    # the result up with what's necessary to become a list.
    @spec parse(binary(), boolean()) :: parsed_field()
    defp parse(entity, true) do
      # parse like a non-list type
      {type, original_type, name, _default} =
        @list_regex
        |> Regex.replace(entity, "")
        |> parse(false)

      # become a list type
      {"list(#{type})", original_type <> "[]", name, "[]"}
    end

    # parse a regular type (not a list) into the `parsed_field` four-tuple
    defp parse(entity, false) do
      [original_type, name] =
        entity
        |> String.trim()
        |> String.split(~r/\s+/)
        |> Enum.take(2)

      {type, default} = spec(original_type)

      {type, original_type, name, default}
    end

    # uses the information from the parsing to create the definition of the
    # typespec of a module (what would be in `@type t :: %__MODULE{<here>}`).
    # only relies on the erlang typespec type and the name of the field
    @spec typespec_guts([parsed_field()]) :: String.t()
    defp typespec_guts(parsed_msg) do
      parsed_msg
      |> Enum.map(fn {type, _original_type, name, _default} ->
        "#{name}: #{type}"
      end)
      |> Enum.join(", ")
    end

    # uses the information from the parsing to create the definition of the
    # types, which are used in the serialization and deserialization of the
    # structs. this only relies on the ros type and the name of each field.
    # the resulting keyword list is created in order of the definition, which
    # is very important because serialized messages don't give any indication
    # of the order the fields are in.
    @spec types_guts([parsed_field()]) :: String.t()
    defp types_guts(parsed_msg) do
      parsed_msg
      |> Enum.map(fn {_type, original_type, name, _default} ->
        "#{name}: :\"#{original_type}\""
      end)
      |> Enum.join(", ")
    end

    # uses the information from the parsing to create the definition of the
    # struct (without `defstruct`). essentially just creates the inside of
    # a keyword list using the name of the field and the default value.
    @spec struct_guts([parsed_field()]) :: String.t()
    defp struct_guts(parsed_msg) do
      parsed_msg
      |> Enum.map(fn {_type, _original_type, name, default} ->
        "#{name}: #{default}"
      end)
      |> Enum.join(", ")
    end

    # it's possible (and common in ActionLib) to have constants in message
    # definitions (i.e. "uint8 DONE=1"). these are represented in the Elixir
    # structs as functions (i.e. MyModule.done). the names for the constant
    # functions are passed through `String.downcase/1`.
    @spec parse_constants([parsed_field()]) :: {[parsed_field()], [String.t()]}
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

    # for the sake of backwards compatibility
    def spec("Header"), do: {"StdMsgs.Header.t()", "%StdMsgs.Header{}"}

    def spec(t) when is_binary(t) do
      # convert from string type into module type
      module = Helpers.module(t)

      {"#{module}.t()", "%#{module}{}"}
    end
  end
end
