defmodule App.QuranTest do
  use ExUnit.Case, async: true

  alias App.Quran
  alias App.Recitations.Assignment

  test "rejects ayah ranges outside the selected surah" do
    changeset =
      Assignment.changeset(%Assignment{}, %{
        "title" => "Revision",
        "juz_number" => "1",
        "surah_name" => "Al-Fatihah",
        "ayah_from" => "1",
        "ayah_to" => "8"
      })

    refute changeset.valid?
    assert {"must be within the selected surah", _} = changeset.errors[:ayah_to]
  end

  test "maps an assigned ayah to its correct juz" do
    assert Quran.juz_for("Al-Baqarah", 255) == 3
    assert Quran.valid_ayah_range?("Al-Fatihah", 1, 7)
  end
end
