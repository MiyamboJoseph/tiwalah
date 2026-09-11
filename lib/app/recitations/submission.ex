defmodule App.Recitations.Submission do
  use Ecto.Schema
  import Ecto.Changeset

  schema "recitation_submissions" do
    field :audio_path, :string
    field :note, :string
    field :feedback, :string
    field :feedback_categories, {:array, :string}, default: []
    field :repeat_ayah_from, :integer
    field :repeat_ayah_to, :integer
    field :repeat_instruction, :string
    field :repeat_due_date, :date
    field :tutor_audio_path, :string

    field :status, Ecto.Enum,
      values: [:submitted, :reviewed, :repeat_required],
      default: :submitted

    belongs_to :assignment, App.Recitations.Assignment
    belongs_to :student, App.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def submission_changeset(submission, attrs) do
    submission
    |> cast(attrs, [:audio_path, :note])
    |> validate_required([:audio_path])
    |> check_constraint(:status, name: :submission_status_is_valid)
  end

  def review_changeset(submission, attrs, assignment \\ nil) do
    submission
    |> cast(attrs, [
      :status,
      :feedback,
      :feedback_categories,
      :repeat_ayah_from,
      :repeat_ayah_to,
      :repeat_instruction,
      :repeat_due_date,
      :tutor_audio_path
    ])
    |> validate_required([:status])
    |> validate_inclusion(:status, [:reviewed, :repeat_required])
    |> validate_subset(:feedback_categories, App.Recitations.feedback_categories())
    |> validate_repeat_guidance()
    |> validate_repeat_focus(assignment)
    |> check_constraint(:status, name: :submission_status_is_valid)
    |> check_constraint(:repeat_ayah_to, name: :repeat_ayah_range_is_valid)
  end

  defp validate_repeat_guidance(changeset) do
    if get_field(changeset, :status) == :repeat_required do
      changeset
      |> validate_required([:feedback, :repeat_ayah_from, :repeat_ayah_to, :repeat_instruction])
      |> validate_number(:repeat_ayah_from, greater_than_or_equal_to: 1)
      |> validate_number(:repeat_ayah_to, greater_than_or_equal_to: 1)
      |> validate_repeat_ayah_range()
    else
      changeset
    end
  end

  defp validate_repeat_ayah_range(changeset) do
    first_ayah = get_field(changeset, :repeat_ayah_from)
    last_ayah = get_field(changeset, :repeat_ayah_to)

    if is_integer(first_ayah) and is_integer(last_ayah) and last_ayah < first_ayah do
      add_error(changeset, :repeat_ayah_to, "must be after the first ayah")
    else
      changeset
    end
  end

  defp validate_repeat_focus(changeset, assignment) when not is_nil(assignment) do
    first_ayah = get_field(changeset, :repeat_ayah_from)
    last_ayah = get_field(changeset, :repeat_ayah_to)

    if get_field(changeset, :status) == :repeat_required and is_integer(first_ayah) and
         is_integer(last_ayah) and
         (first_ayah < assignment.ayah_from or last_ayah > assignment.ayah_to) do
      add_error(changeset, :repeat_ayah_to, "must be within the assigned ayah range")
    else
      changeset
    end
  end

  defp validate_repeat_focus(changeset, _assignment), do: changeset
end
