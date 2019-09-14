defmodule Requestor do
  import ExUnit.Assertions

  defmacro test_request(plug, plug_options, method, path, do: contents) do
    contents = Macro.escape(contents)

    quote bind_quoted: [
            method: method,
            path: path,
            plug: plug,
            plug_options: plug_options,
            contents: contents
          ] do
      test "#{method} #{path}" do
        conn = conn(unquote(method), unquote(path))
        conn = unquote(plug).call(conn, unquote(plug_options))
        var!(conn) = conn
        unquote(contents)
      end
    end
  end

  defmacro test_request(plug, plug_options, method, path) do
    quote bind_quoted: [method: method, path: path, plug: plug, plug_options: plug_options] do
      test "#{method} #{path}" do
        conn = conn(unquote(method), unquote(path))
        conn = unquote(plug).call(conn, unquote(plug_options))
        assert conn.status == 200
      end
    end
  end
end
