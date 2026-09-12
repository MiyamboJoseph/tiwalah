defmodule App.Repo.Migrations.AddConnectionRequestDirection do
  use Ecto.Migration

  def change do
    alter table(:tutor_student_connections) do
      add :requested_by, :string, null: false, default: "tutor"
    end

    create index(:tutor_student_connections, [:tutor_id, :requested_by, :status])

    create constraint(:tutor_student_connections, :tutor_student_connections_requested_by_check,
             check: "requested_by IN ('student', 'tutor')"
           )
  end
end
