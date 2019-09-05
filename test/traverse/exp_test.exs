defmodule Traverse.ExpTest do
  use ExUnit.Case

  alias Traverse.Document
  import Traverse.Matcher

  test "descendants" do
    # Trying to come up with the equivalent of
    # document.querySelector("div .thing")
    #
    # So first do a query all on "div" and then a query all on ".thing"
    document =
      Traverse.parse("""
        <html>
        <body>
          <div></div>
          <div class="thing"><span id="correct" class="thing"></div>
          <div><span id="incorrect"></div>
          <span id="incorrect" class="thing">
        </body>
      """)

    assert document
           |> stream(element_name_is("div"))
           |> Stream.flat_map(&stream_children(&1, "class" |> attribute_is("thing")))
           |> Enum.to_list() ===
             [{"span", [{"id", "correct"}, {"class", "thing"}], []}]
  end

  test "query children" do
    # given a Stream that produces Streams, iterate through
    result =
      """
        <html>
          <head><title>Hello World</title></head>
          <body>
            <div><span>1<span>x<span>y</span></span></span></div>
            <div><span>2</span></div>
            <div><span>3</span></div>
            <div><span>4</span></div>
            <span>5</span>
          </body>
      """
      |> Traverse.parse()
      |> stream(element_name_is("div"))
      |> Stream.flat_map(&stream_children(&1, element_name_is("span")))
      |> Stream.flat_map(&stream_children(&1, element_name_is("span")))
      |> Enum.to_list()

    assert result === [
             {"span", [],
              [
                "x",
                {"span", [], ["y"]}
              ]},
             {"span", [], ["y"]},
             {"span", [], ["y"]}
           ]
  end

  test "mf" do
    Ingest.DateTime.parse("2019-09-02 13:23:43-07:00")
    |> case do
      {result, _} -> assert result === :ok
    end

    assert "2019-08-13 21:38Z"
           |> Ingest.DateTime.parse() ===
             {:ok, ~U[2019-08-13 21:38:00Z]}
  end
end

defmodule Ingest.DateTime do
  @formats [
    {17, "{YYYY}-{0M}-{0D} {h24}:{0m}Z"},
    {20, "{YYYY}-{0M}-{0D} {h24}:{0m}{0s}Z"},
    {25, "{YYYY}-{0M}-{0D} {h24}:{0m}:{0s}{Z:}"}
  ]

  def parse(date) do
    @formats
    |> Enum.reduce(nil, fn
      _, {:ok, _} = result ->
        result

      {len, format}, _ ->
        String.slice(date, 0, len)
        |> Timex.parse(format)
        |> case do
          {:ok, d = %NaiveDateTime{}} = result ->
            case DateTime.from_naive(d, "Etc/UTC") do
              {:ok, _} = success ->
                success

              _ ->
                result
            end

          result ->
            result
        end
    end)
  end
end
