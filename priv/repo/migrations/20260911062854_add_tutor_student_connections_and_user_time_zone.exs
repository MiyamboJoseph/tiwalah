defmodule App.Repo.Migrations.AddTutorStudentConnectionsAndUserTimeZone do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :time_zone, :string, null: false, default: "Africa/Lusaka"
    end

    create table(:tutor_student_connections) do
      add :tutor_id, references(:users, on_delete: :delete_all), null: false
      add :student_id, references(:users, on_delete: :delete_all), null: false
      add :status, :string, null: false, default: "pending"
      timestamps(type: :utc_datetime)
    end

    create unique_index(:tutor_student_connections, [:tutor_id, :student_id])
    create index(:tutor_student_connections, [:student_id, :status])

    create constraint(:tutor_student_connections, :connection_status_is_valid,
             check: "status IN ('pending', 'active')"
           )

    execute("""
    INSERT INTO tutor_student_connections (tutor_id, student_id, status, inserted_at, updated_at)
    SELECT DISTINCT tutor_id, student_id, 'active', NOW(), NOW()
    FROM recitation_assignments
    ON CONFLICT (tutor_id, student_id) DO NOTHING
    """)
  end
end
