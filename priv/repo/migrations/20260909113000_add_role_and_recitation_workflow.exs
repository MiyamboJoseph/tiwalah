defmodule App.Repo.Migrations.AddRoleAndRecitationWorkflow do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :role, :string, null: false, default: "student"
    end

    create constraint(:users, :users_role_must_be_valid, check: "role IN ('student', 'tutor')")

    create table(:recitation_assignments) do
      add :tutor_id, references(:users, on_delete: :delete_all), null: false
      add :student_id, references(:users, on_delete: :delete_all), null: false
      add :juz_number, :integer, null: false
      add :surah_name, :string, null: false
      add :ayah_from, :integer, null: false
      add :ayah_to, :integer, null: false
      add :title, :string, null: false
      add :due_date, :date
      add :status, :string, null: false, default: "assigned"

      timestamps(type: :utc_datetime)
    end

    create index(:recitation_assignments, [:tutor_id])
    create index(:recitation_assignments, [:student_id])

    create table(:recitation_submissions) do
      add :assignment_id, references(:recitation_assignments, on_delete: :delete_all), null: false
      add :student_id, references(:users, on_delete: :delete_all), null: false
      add :audio_path, :string, null: false
      add :note, :text
      add :status, :string, null: false, default: "submitted"
      add :feedback, :text

      timestamps(type: :utc_datetime)
    end

    create index(:recitation_submissions, [:assignment_id])
    create index(:recitation_submissions, [:student_id])
  end
end
