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

  test "mochiweb_html failure" do
    html =
      "<br/><br/><p><small><bad><a href=\"#\"><br/>1</a> | <a href=\"#\">2</a> | <a href=\"#\">3</a> | <a href=\"#\">4</a> | <a href=\"#\">5</a> | <a href=\"#\">6</a></bad></small><br/></p></blockquote>"

    document = Ingest.Sanitize.sanitize_html(html)

    assert document ===
             "<br /><br /><p><small><a href=\"#\"><br />1</a> | <a href=\"#\">2</a> | <a href=\"#\">3</a> | <a href=\"#\">4</a> | <a href=\"#\">5</a> | <a href=\"#\">6</a></small><br /></p>"
  end
end
