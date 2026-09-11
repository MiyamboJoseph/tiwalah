defmodule App.Quran do
  @moduledoc "Canonical surah names used when assigning recitation portions."

  @surahs ~w(
    Al-Fatihah Al-Baqarah Aal-Imran An-Nisa Al-Ma'idah Al-An'am Al-A'raf Al-Anfal At-Tawbah
    Yunus Hud Yusuf Ar-Ra'd Ibrahim Al-Hijr An-Nahl Al-Isra Al-Kahf Maryam Ta-Ha Al-Anbiya
    Al-Hajj Al-Mu'minun An-Nur Al-Furqan Ash-Shu'ara An-Naml Al-Qasas Al-Ankabut Ar-Rum
    Luqman As-Sajdah Al-Ahzab Saba Fatir Ya-Sin As-Saffat Sad Az-Zumar Ghafir Fussilat
    Ash-Shura Az-Zukhruf Ad-Dukhan Al-Jathiyah Al-Ahqaf Muhammad Al-Fath Al-Hujurat Qaf
    Adh-Dhariyat At-Tur An-Najm Al-Qamar Ar-Rahman Al-Waqi'ah Al-Hadid Al-Mujadila Al-Hashr
    Al-Mumtahanah As-Saff Al-Jumu'ah Al-Munafiqun At-Taghabun At-Talaq At-Tahrim Al-Mulk
    Al-Qalam Al-Haqqah Al-Ma'arij Nuh Al-Jinn Al-Muzzammil Al-Muddaththir Al-Qiyamah
    Al-Insan Al-Mursalat An-Naba An-Nazi'at Abasa At-Takwir Al-Infitar Al-Mutaffifin
    Al-Inshiqaq Al-Buruj At-Tariq Al-A'la Al-Ghashiyah Al-Fajr Al-Balad Ash-Shams Al-Layl
    Ad-Duha Ash-Sharh At-Tin Al-Alaq Al-Qadr Al-Bayyinah Az-Zalzalah Al-Adiyat Al-Qari'ah
    At-Takathur Al-Asr Al-Humazah Al-Fil Quraysh Al-Ma'un Al-Kawthar Al-Kafirun An-Nasr
    Al-Masad Al-Ikhlas Al-Falaq An-Nas
  )

  @ayah_counts [
    7,
    286,
    200,
    176,
    120,
    165,
    206,
    75,
    129,
    109,
    123,
    111,
    43,
    52,
    99,
    128,
    111,
    110,
    98,
    135,
    112,
    78,
    118,
    64,
    77,
    227,
    93,
    88,
    69,
    60,
    34,
    30,
    73,
    54,
    45,
    83,
    182,
    88,
    75,
    85,
    54,
    53,
    89,
    59,
    37,
    35,
    38,
    29,
    18,
    45,
    60,
    49,
    62,
    55,
    78,
    96,
    29,
    22,
    24,
    13,
    14,
    11,
    11,
    18,
    12,
    12,
    30,
    52,
    52,
    44,
    28,
    28,
    20,
    56,
    40,
    31,
    50,
    40,
    46,
    42,
    29,
    19,
    36,
    25,
    22,
    17,
    19,
    26,
    30,
    20,
    15,
    21,
    11,
    8,
    8,
    19,
    5,
    8,
    8,
    11,
    11,
    8,
    3,
    9,
    5,
    4,
    7,
    3,
    6,
    3,
    5,
    4,
    5,
    6
  ]

  @juz_starts [
    {1, 1},
    {2, 142},
    {2, 253},
    {3, 93},
    {4, 24},
    {4, 148},
    {5, 82},
    {6, 111},
    {7, 88},
    {8, 41},
    {9, 94},
    {11, 6},
    {12, 53},
    {15, 1},
    {17, 1},
    {18, 75},
    {21, 1},
    {23, 1},
    {25, 21},
    {27, 56},
    {29, 46},
    {33, 31},
    {36, 28},
    {39, 32},
    {41, 47},
    {46, 1},
    {51, 31},
    {58, 1},
    {67, 1},
    {78, 1}
  ]

  def surah_options do
    Enum.with_index(@surahs, 1)
    |> Enum.map(fn {name, number} -> {"#{number}. #{name}", name} end)
  end

  def surah_number(name) do
    case Enum.find_index(@surahs, &(&1 == name)) do
      nil -> :error
      index -> {:ok, index + 1}
    end
  end

  def valid_ayah_range?(surah_name, first_ayah, last_ayah)
      when is_integer(first_ayah) and is_integer(last_ayah) do
    with {:ok, surah_number} <- surah_number(surah_name),
         max_ayah <- Enum.at(@ayah_counts, surah_number - 1) do
      first_ayah >= 1 and last_ayah >= first_ayah and last_ayah <= max_ayah
    else
      _ -> false
    end
  end

  def juz_for(surah_name, ayah) when is_integer(ayah) do
    with {:ok, surah_number} <- surah_number(surah_name) do
      @juz_starts
      |> Enum.with_index(1)
      |> Enum.reduce(1, fn {{start_surah, start_ayah}, juz}, current_juz ->
        if {surah_number, ayah} >= {start_surah, start_ayah}, do: juz, else: current_juz
      end)
    else
      _ -> nil
    end
  end
end
