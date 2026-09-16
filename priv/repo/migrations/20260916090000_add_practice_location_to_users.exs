defmodule App.Repo.Migrations.AddPracticeLocationToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :latitude, :float
      add :longitude, :float
    end
  end
end
