defmodule App.UmmahApi.Quran do
  @moduledoc "Safe server-side access to UmmahAPI Qur'an passages."

  alias App.Quran
  alias App.Recitations.Assignment
  alias App.UmmahApi.PassageCache

  @request_timeout 8_000

  def assigned_passage(%Assignment{} = assignment) do
    with {:ok, surah_number} <- Quran.surah_number(assignment.surah_name),
         {:ok, verses} <- fetch_surah(surah_number),
         selected when selected != [] <-
           select_range(verses, assignment.ayah_from, assignment.ayah_to) do
      {:ok,
       %{
         source: "UmmahAPI · Qur'an text from Tanzil.net",
         verses: selected
       }}
    else
      _ -> {:error, :unavailable}
    end
  end

  defp surah_url(surah_number) do
    base_url = Application.fetch_env!(:app, :ummah_api) |> Keyword.fetch!(:base_url)
    "#{String.trim_trailing(base_url, "/")}/api/quran/surah/#{surah_number}"
  end

  defp fetch_surah(surah_number) do
    PassageCache.fetch(surah_number, fn ->
      with {:ok, response} <-
             Req.get(
               url: surah_url(surah_number),
               params: [script: "uthmani", translation: "sahih_international"],
               headers: api_key_header(),
               receive_timeout: @request_timeout
             ),
           true <- response.status in 200..299,
           verses when is_list(verses) and verses != [] <- extract_verses(response.body) do
        {:ok, verses}
      else
        _ -> {:error, :unavailable}
      end
    end)
  end

  defp extract_verses(%{"data" => data}), do: extract_verses(data)
  defp extract_verses(%{"verses" => verses}) when is_list(verses), do: normalize_verses(verses)
  defp extract_verses(%{"ayahs" => verses}) when is_list(verses), do: normalize_verses(verses)

  defp extract_verses(%{"surah" => surah}) when is_map(surah), do: extract_verses(surah)
  defp extract_verses(_body), do: []

  defp normalize_verses(verses) do
    verses
    |> Enum.map(&normalize_verse/1)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_verse(verse) when is_map(verse) do
    with number when is_integer(number) <- number(verse),
         arabic when is_binary(arabic) and arabic != "" <-
           text(verse, ["text", "arabic", "arabic_text", "text_uthmani", "uthmani"]) do
      %{number: number, arabic: arabic, translation: translation(verse)}
    else
      _ -> nil
    end
  end

  defp normalize_verse(_verse), do: nil

  defp number(verse) do
    verse
    |> value(["number_in_surah", "ayah_number", "ayah", "number"])
    |> parse_integer()
  end

  defp text(verse, keys), do: value(verse, keys)

  defp translation(verse) do
    value(verse, ["translation", "translation_en", "english"])
    |> case do
      text when is_binary(text) ->
        clean_translation(text)

      %{} = translations ->
        translations
        |> value(["sahih_international", "en", "text"])
        |> clean_translation()

      _ ->
        nil
    end
  end

  # Some translations include inline source footnote markers such as "Merciful,1".
  # They have no corresponding notes in this focused recitation interface.
  defp clean_translation(text) when is_binary(text),
    do: String.replace(text, ~r/(?<=[[:alpha:],.;:!?])\d+(?=\s|$)/u, "")

  defp clean_translation(_text), do: nil

  defp value(map, keys) do
    Enum.find_value(keys, fn key ->
      case Map.get(map, key) do
        nil -> nil
        value -> value
      end
    end)
  end

  defp parse_integer(number) when is_integer(number), do: number

  defp parse_integer(number) when is_binary(number) do
    case Integer.parse(number) do
      {value, ""} -> value
      _ -> nil
    end
  end

  defp parse_integer(_number), do: nil

  defp select_range(verses, from, to) do
    Enum.filter(verses, fn verse -> verse.number >= from and verse.number <= to end)
  end

  defp api_key_header do
    case Application.fetch_env!(:app, :ummah_api) |> Keyword.get(:api_key) do
      key when is_binary(key) and key != "" -> [{"x-api-key", key}]
      _ -> []
    end
  end
end
