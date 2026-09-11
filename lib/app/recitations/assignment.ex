defmodule App.Recitations.Assignment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "recitation_assignments" do
    field :juz_number, :integer
    field :surah_name, :string
    field :ayah_from, :integer
    field :ayah_to, :integer
    field :title, :string
    field :due_date, :date

    field :status, Ecto.Enum,
      values: [:assigned, :submitted, :reviewed, :repeat_required],
      default: :assigned

    belongs_to :tutor, App.Accounts.User
    belongs_to :student, App.Accounts.User
    has_many :submissions, App.Recitations.Submission

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
end
