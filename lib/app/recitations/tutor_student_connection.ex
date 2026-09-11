defmodule App.Recitations.TutorStudentConnection do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tutor_student_connections" do
    field :status, Ecto.Enum, values: [:pending, :active], default: :pending
    belongs_to :tutor, App.Accounts.User
    belongs_to :student, App.Accounts.User
    timestamps(type: :utc_datetime)
  end

  def changeset(connection, attrs) do
    connection
    |> cast(attrs, [:status])
    |> validate_required([:status])
  end
end
