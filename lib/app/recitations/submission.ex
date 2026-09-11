defmodule App.Recitations.Submission do
  use Ecto.Schema
  import Ecto.Changeset

  schema "recitation_submissions" do
    field :audio_path, :string
    field :note, :string
    field :feedback, :string
    field :feedback_categories, {:array, :string}, default: []

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

  def review_changeset(submission, attrs) do
    submission
    |> cast(attrs, [:status, :feedback, :feedback_categories])
    |> validate_required([:status])
    |> validate_inclusion(:status, [:reviewed, :repeat_required])
    |> validate_subset(:feedback_categories, App.Recitations.feedback_categories())
    |> check_constraint(:status, name: :submission_status_is_valid)
  end
end
