defmodule App.UmmahApi.Learning do
  @moduledoc "Focused learning resources fetched server-side from UmmahAPI."

  @timeout 8_000

  def word_by_word(surah_number, verses) when is_integer(surah_number) and is_list(verses) do
    Enum.reduce(verses, %{}, fn %{number: ayah_number}, resources ->
      case request("/api/quran/words/#{surah_number}/#{ayah_number}") do
        {:ok, %{"words" => words}} when is_list(words) ->
          Map.put(resources, ayah_number, normalize_words(words))

        _ ->
          resources
      end
    end)
  end

  @doc "Returns one reference-reciter audio URL for each requested āyah."
  def reciter_audio(surah_number, verses) when is_integer(surah_number) and is_list(verses) do
    Enum.reduce(verses, %{}, fn %{number: ayah_number}, audio ->
      case request("/api/quran/audio/#{surah_number}/#{ayah_number}") do
        {:ok, data} ->
          case select_reciter_audio(data) do
            nil -> audio
            clip -> Map.put(audio, ayah_number, clip)
          end

        _ ->
          audio
      end
    end)
  end

  def daily_dua do
    with {:ok, data} <- request("/api/duas/random"),
         arabic when is_binary(arabic) and arabic != "" <- data["arabic"] do
      {:ok,
       %{
         title: data["title"] || "A duʿā for today",
         arabic: arabic,
         transliteration: data["transliteration"],
         translation: data["translation"],
         source: data["source"]
       }}
    else
      _ -> {:error, :unavailable}
    end
  end

  def hijri_date(date \\ Date.utc_today()) do
    with {:ok, data} <- request("/api/hijri-date", date: Date.to_iso8601(date)),
         formatted when is_binary(formatted) <- formatted_hijri_date(data) do
      {:ok, formatted}
    else
      _ -> {:error, :unavailable}
    end
  end

  @doc "Returns the local Maghrib time for a precise saved location."
  def maghrib_time(latitude, longitude, time_zone, date \\ Date.utc_today())
      when is_number(latitude) and is_number(longitude) and is_binary(time_zone) do
    with {:ok, times} <- fetch_prayer_times(latitude, longitude, time_zone, date),
         value when is_binary(value) <- Map.get(times, :maghrib),
         {:ok, time} <- parse_time(value) do
      {:ok, time}
    else
      _ -> {:error, :unavailable}
    end
  end

  @doc "Returns the user's local daily prayer times when a reminder location is saved."
  def prayer_times(latitude, longitude, time_zone, date \\ Date.utc_today())
      when is_number(latitude) and is_number(longitude) and is_binary(time_zone) do
    with {:ok, times} <- fetch_prayer_times(latitude, longitude, time_zone, date) do
      visible_times =
        Enum.reduce([:fajr, :sunrise, :dhuhr, :asr, :maghrib, :isha], %{}, fn prayer, result ->
          case Map.get(times, prayer) do
            value when is_binary(value) -> Map.put(result, prayer, display_time(value))
            _ -> result
          end
        end)

      if visible_times == %{}, do: {:error, :unavailable}, else: {:ok, visible_times}
    end
  end

  defp request(path, params \\ []) do
    url = Application.fetch_env!(:app, :ummah_api) |> Keyword.fetch!(:base_url)

    with {:ok, response} <-
           Req.get(
             url: String.trim_trailing(url, "/") <> path,
             params: params,
             headers: api_key_header(),
             receive_timeout: @timeout
           ),
         true <- response.status in 200..299,
         %{} = data <- Map.get(response.body, "data") do
      {:ok, data}
    else
      _ -> {:error, :unavailable}
    end
  end

  defp normalize_words(words) do
    Enum.flat_map(words, fn word ->
      case word do
        %{"arabic" => arabic} when is_binary(arabic) ->
          [
            %{
              arabic: arabic,
              transliteration: get_in(word, ["transliteration", "text"]),
              translation: word["translation"]
            }
          ]

        _ ->
          []
      end
    end)
  end

  defp select_reciter_audio(data) do
    preferred_reciter =
      Application.fetch_env!(:app, :ummah_api)
      |> Keyword.get(:default_reciter, "Mishary Alafasy")
      |> String.downcase()

    data
    |> nested_maps()
    |> Enum.flat_map(&audio_candidates/1)
    |> case do
      [] ->
        nil

      candidates ->
        Enum.find(candidates, fn candidate ->
          candidate.reciter
          |> reciter_label()
          |> String.downcase()
          |> String.contains?(preferred_reciter)
        end) || List.first(candidates)
    end
  end

  defp audio_candidates(map) do
    url = Map.get(map, "url") || Map.get(map, "audio_url") || Map.get(map, "audioUrl")

    if is_binary(url) and String.starts_with?(url, "http") do
      [
        %{
          url: url,
          reciter:
            Map.get(map, "reciter_name") || Map.get(map, "reciter") || Map.get(map, "name") ||
              "Reference reciter"
        }
      ]
    else
      []
    end
  end

  defp nested_maps(map) when is_map(map) do
    [map | Enum.flat_map(Map.values(map), &nested_maps/1)]
  end

  defp nested_maps(values) when is_list(values), do: Enum.flat_map(values, &nested_maps/1)
  defp nested_maps(_value), do: []

  defp reciter_label(value) when is_binary(value), do: value
  defp reciter_label(_value), do: "Reference reciter"

  defp formatted_hijri_date(data) do
    data["formatted"] ||
      get_in(data, ["hijri", "formatted"]) ||
      with day when is_binary(day) or is_integer(day) <- data["day"],
           month when is_binary(month) <- data["month_name"] || get_in(data, ["month", "name"]),
           year when is_binary(year) or is_integer(year) <- data["year"] do
        "#{day} #{month} #{year} AH"
      end
  end

  defp fetch_prayer_times(latitude, longitude, time_zone, date) do
    with {:ok, data} <-
           request("/api/prayer-times",
             lat: latitude,
             lng: longitude,
             date: Date.to_iso8601(date),
             timezone: time_zone
           ) do
      times = prayer_time_map(data)
      if times == %{}, do: {:error, :unavailable}, else: {:ok, times}
    end
  end

  defp prayer_time_map(data) do
    values = data["prayer_times"] || data["prayer_datetimes"] || data

    Enum.reduce([:fajr, :sunrise, :dhuhr, :asr, :maghrib, :isha], %{}, fn prayer, result ->
      case prayer_value(values, prayer) do
        value when is_binary(value) -> Map.put(result, prayer, value)
        _ -> result
      end
    end)
  end

  defp prayer_value(values, prayer) do
    label = prayer |> Atom.to_string() |> String.capitalize()
    values[label] || values[Atom.to_string(prayer)]
  end

  defp display_time(value) do
    case parse_time(value) do
      {:ok, time} -> Calendar.strftime(time, "%H:%M")
      _ -> value
    end
  end

  defp parse_time(value) do
    cond do
      match?({:ok, _time}, Time.from_iso8601(value)) ->
        Time.from_iso8601(value)

      match?({:ok, _datetime, _offset}, DateTime.from_iso8601(value)) ->
        {:ok, datetime, _offset} = DateTime.from_iso8601(value)
        {:ok, DateTime.to_time(datetime)}

      match?({:ok, _datetime}, NaiveDateTime.from_iso8601(value)) ->
        {:ok, datetime} = NaiveDateTime.from_iso8601(value)
        {:ok, NaiveDateTime.to_time(datetime)}

      true ->
        parse_clock_time(value)
    end
  end

  defp parse_clock_time(value) do
    value
    |> String.slice(0, 5)
    |> then(&Time.from_iso8601(&1 <> ":00"))
  end

  defp api_key_header do
    case Application.fetch_env!(:app, :ummah_api) |> Keyword.get(:api_key) do
      key when is_binary(key) and key != "" -> [{"x-api-key", key}]
      _ -> []
    end
  end
end
