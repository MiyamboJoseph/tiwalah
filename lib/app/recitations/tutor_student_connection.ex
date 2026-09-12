defmodule App.Recitations.TutorStudentConnection do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tutor_student_connections" do
    field :status, Ecto.Enum, values: [:pending, :active], default: :pending
    field :requested_by, Ecto.Enum, values: [:student, :tutor], default: :student
    belongs_to :tutor, App.Accounts.User
    belongs_to :student, App.Accounts.User
    timestamps(type: :utc_datetime)
  end

  def changeset(connection, attrs) do
    connection
    |> cast(attrs, [:status, :requested_by])
    |> validate_required([:status, :requested_by])
    |> unique_constraint(:student_id,
      name: :tutor_student_connections_tutor_id_student_id_index,
      message: "already has a connection request for this tutor"
    )
  end
end
