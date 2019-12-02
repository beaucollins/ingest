defmodule Traverse.TransformerTest do
  use ExUnit.Case, async: true

  doctest Traverse.Transformer

  test "trasform_all" do
    transformer =
      Traverse.Transformer.transform_all_elements do
        fn
          {element, atts, children} ->
            updated =
              for child <- children do
                case child do
                  text when is_binary(text) ->
                    String.upcase(text)

                  other ->
                    other
                end
              end

            {element, atts, updated}
        end
      end

    fragment =
      {"div", [{"id", "stuff"}],
       [
         [comment: " testing "],
         "hello",
         {"p", [], ["Paragraph"]},
         "there"
       ]}

    transformed =
      transformer.(fragment)
      |> Traverse.Document.to_string()

    assert transformed === ~s[<div id="stuff"><!-- testing -->HELLO<p>Paragraph</p>THERE</div>]

    assert fragment
           |> Traverse.Transformer.map(transformer)
           |> Traverse.Document.to_string() ===
             ~s[<div id="stuff"><!-- testing -->HELLO<p>PARAGRAPH</p>THERE</div>]
  end
end
