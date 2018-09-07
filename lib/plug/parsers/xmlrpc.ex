defmodule Plug.Parsers.XMLRPC do
  @behaviour Plug.Parsers
  import Plug.Conn

  def init(opts), do: opts

  def parse(conn, _type, "xml", _headers, opts) do
    decoder =
      Keyword.get(opts, :xmlrpc_decoder) ||
        raise ArgumentError, "XMLRPC parser expects a :xmlrpc_decoder option"

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
        {:ok, parsed, conn}

      {:error, reason} ->
        raise "Could not parse XMLRPC call: #{reason}"
    end
  rescue
    e -> raise Plug.Parsers.ParseError, exception: e
  end
end
