defmodule App.Repo.Migrations.AddStudentProfileFields do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :first_name, :string
      add :last_name, :string
      add :gender, :string
      add :location, :string
      add :phone_number, :string
    end
  end
end
