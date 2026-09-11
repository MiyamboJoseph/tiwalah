defmodule App.Repo.Migrations.AddLearningHubFeatures do
  use Ecto.Migration

  def change do
    create table(:user_notifications) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :kind, :string, null: false
      add :title, :string, null: false
      add :body, :text
      add :path, :string
      add :read_at, :utc_datetime
      timestamps(type: :utc_datetime)
    end

    create index(:user_notifications, [:user_id, :read_at, :inserted_at])

    create table(:assignment_templates) do
      add :tutor_id, references(:users, on_delete: :delete_all), null: false
      add :title, :string, null: false
      add :juz_number, :integer, null: false
      add :surah_name, :string, null: false
      add :ayah_from, :integer, null: false
      add :ayah_to, :integer, null: false
      add :due_in_days, :integer
      timestamps(type: :utc_datetime)
    end

    create index(:assignment_templates, [:tutor_id, :inserted_at])
  end
end
