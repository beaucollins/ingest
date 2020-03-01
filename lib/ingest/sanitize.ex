defmodule Ingest.Sanitize do
  import Traverse.Matcher, only: [element_is_one_of: 1, element_name_is: 1]

  import Traverse.Transformer,
    only: [
      transform: 2,
      transform: 3,
      transform_first: 1,
      remove_content: 0,
      select_children: 0,
      unchanged: 0
    ]

  @doc """
  Sanitizes HTML for feed summaries and content.

      iex> ~s[<p class="cls" id="id">Hello. <script type="text/javascript">alert("🧨");</script> World.</p><p>🚀.</p>]
      ...> |> Ingest.Sanitize.sanitize_html
      ~s[<p class="cls" id="id">Hello.  World.</p><p>🚀.</p>]
  """
  def sanitize_html(content) do
    sanitize(content)
    |> Enum.map(fn
      node when is_binary(node) ->
        node

      node ->
        :mochiweb_html.to_html(node)
      end)
    |> to_string()
  end

  def parse(content) do
    ("<Fragment>" <> content)
    |> Traverse.parse()

  end

  def sanitize(content) do
    parse(content)
    |> Traverse.map(
      transform_first([
        transform(
          element_is_one_of(~w[script]),
          remove_content()
        ),
        transform(
          element_name_is("fragment"),
          select_children()
        ),
        transform(
          element_is_one_of(~w(
            a
            b bdi bdo blockquote br
            cite code
            data dd dfn div dl dt
            em
            figcaption figure
            h1 h2 h3 h4 h5 h6 hr
            i iframe img
            li
            mark
            ol
            p pre
            q
            s small span strong sub sup
            table tbody td tfoot thead time tr
            u ul
            var
            wbr
          )),
          unchanged(),
          select_children()
        )
      ])
    )
  end
end
