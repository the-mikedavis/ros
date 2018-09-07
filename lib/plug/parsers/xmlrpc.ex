defmodule Plug.Parsers.XMLRPC do
  @behaviour Plug.Parsers
  import Plug.Conn

  @moduledoc """
  A plug for decoding HTTP requests as XMLRPC calls.
  """

  def init(opts) do
    IO.inspect(opts)
    {decoder, opts} = Keyword.pop(opts, :xmlrpc_decoder)

    unless decoder do
      raise ArgumentError, "XMLRPC parser expects a :xmlrpc_decoder option"
    end

    {decoder, opts}
    |> IO.inspect
  end

  def parse(conn, _type, "xml", _headers, {decoder, opts}) do
    IO.puts("In the right parse block")
    conn
    |> read_body(opts)
    |> decode(decoder)
  end

  def parse(conn, _type, _subtype, _headers, _opts) do
    {:next, conn}
  end

  defp decode({:ok, body, conn}, decoder) do
    case decoder.decode(body) do
      {:ok, parsed} ->
        {:ok, Map.from_struct(parsed), conn}

      {:error, reason} ->
        raise "Could not parse XMLRPC call: #{reason}"
    end
  rescue
    e -> reraise Plug.Parsers.ParseError, exception: e
  end
end
