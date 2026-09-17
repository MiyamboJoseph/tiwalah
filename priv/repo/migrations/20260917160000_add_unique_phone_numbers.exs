defmodule App.Repo.Migrations.AddUniquePhoneNumbers do
  use Ecto.Migration

  def change do
    create unique_index(:users, [:phone_number], where: "phone_number IS NOT NULL")
  end
end
