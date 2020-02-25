defmodule Ingest.SanitizeTest do
  use ExUnit.Case, async: true

  doctest Ingest.Sanitize

  test "sanitizes with inline elements" do
    sanitized =
      ~s[<p><em>Hello there</em><strong> </strong> Not sure.</p>]
      |> Ingest.Sanitize.sanitize_html()

    assert sanitized === ~s[<p><em>Hello there</em><strong></strong> Not sure.</p>]
  end

  test "parsed HTML" do
    parsed = ~s[<p><em>Hello there</em><strong>  </strong> Not sure.</p>] |> Traverse.parse()

    assert parsed ===
             {"p", [],
              [
                {"em", [], ["Hello there"]},
                {"strong", [], []},
                " Not sure."
              ]}
  end
end
