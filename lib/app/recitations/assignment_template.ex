defmodule App.Recitations.AssignmentTemplate do
  use Ecto.Schema
  import Ecto.Changeset
  alias App.Quran

  schema "assignment_templates" do
    field :title, :string
    field :juz_number, :integer
    field :surah_name, :string
    field :ayah_from, :integer
    field :ayah_to, :integer
    field :due_in_days, :integer
    belongs_to :tutor, App.Accounts.User
    timestamps(type: :utc_datetime)
  end

  def changeset(template, attrs) do
    template
    |> cast(attrs, [:title, :juz_number, :surah_name, :ayah_from, :ayah_to, :due_in_days])
    |> validate_required([:title, :juz_number, :surah_name, :ayah_from, :ayah_to])
    |> validate_number(:juz_number, greater_than_or_equal_to: 1, less_than_or_equal_to: 30)
    |> validate_number(:ayah_from, greater_than_or_equal_to: 1)
    |> validate_number(:ayah_to, greater_than_or_equal_to: 1)
    |> validate_number(:due_in_days, greater_than_or_equal_to: 0)
    |> validate_ayah_range()
    |> validate_juz()
  end

  defp validate_ayah_range(changeset) do
    surah = get_field(changeset, :surah_name)
    first = get_field(changeset, :ayah_from)
    last = get_field(changeset, :ayah_to)

    if is_binary(surah) and is_integer(first) and is_integer(last) and
         (last < first or not Quran.valid_ayah_range?(surah, first, last)) do
      add_error(changeset, :ayah_to, "must be within the selected surah and after the first ayah")
    else
      changeset
    end
  end

  defp validate_juz(changeset) do
    surah = get_field(changeset, :surah_name)
    first_ayah = get_field(changeset, :ayah_from)
    juz = get_field(changeset, :juz_number)

    if is_binary(surah) and is_integer(first_ayah) and is_integer(juz) and
         Quran.juz_for(surah, first_ayah) != juz do
      add_error(changeset, :juz_number, "does not match the first selected ayah")
    else
      changeset
    end
  end
end
