defmodule App.Recitations.Assignment do
  use Ecto.Schema
  import Ecto.Changeset
  alias App.Quran

  schema "recitation_assignments" do
    field :juz_number, :integer
    field :surah_name, :string
    field :ayah_from, :integer
    field :ayah_to, :integer
    field :title, :string
    field :due_date, :date
    field :reminder_sent_on, :date

    field :status, Ecto.Enum,
      values: [:assigned, :submitted, :reviewed, :repeat_required],
      default: :assigned

    belongs_to :tutor, App.Accounts.User
    belongs_to :student, App.Accounts.User
    has_many :submissions, App.Recitations.Submission, preload_order: [desc: :inserted_at]

    timestamps(type: :utc_datetime)
  end

  def changeset(assignment, attrs) do
    assignment
    |> cast(attrs, [:juz_number, :surah_name, :ayah_from, :ayah_to, :title, :due_date])
    |> validate_required([:juz_number, :surah_name, :ayah_from, :ayah_to, :title])
    |> validate_number(:juz_number, greater_than_or_equal_to: 1, less_than_or_equal_to: 30)
    |> validate_number(:ayah_from, greater_than_or_equal_to: 1)
    |> validate_number(:ayah_to, greater_than_or_equal_to: 1)
    |> validate_ayah_range()
    |> validate_juz()
    |> check_constraint(:ayah_to, name: :assignment_ayah_range_is_valid)
  end

  defp validate_ayah_range(changeset) do
    ayah_from = get_field(changeset, :ayah_from)
    ayah_to = get_field(changeset, :ayah_to)

    if is_integer(ayah_from) && is_integer(ayah_to) && ayah_to < ayah_from do
      add_error(changeset, :ayah_to, "must be after the first ayah")
    else
      changeset
    end
  end

  defp validate_juz(changeset) do
    surah = get_field(changeset, :surah_name)
    first_ayah = get_field(changeset, :ayah_from)
    last_ayah = get_field(changeset, :ayah_to)
    juz = get_field(changeset, :juz_number)

    changeset =
      if is_binary(surah) and is_integer(first_ayah) and is_integer(last_ayah) and
           not Quran.valid_ayah_range?(surah, first_ayah, last_ayah) do
        add_error(changeset, :ayah_to, "must be within the selected surah")
      else
        changeset
      end

    if is_binary(surah) and is_integer(first_ayah) and is_integer(juz) and
         Quran.juz_for(surah, first_ayah) != juz do
      add_error(changeset, :juz_number, "does not match the first selected ayah")
    else
      changeset
    end
  end
end
