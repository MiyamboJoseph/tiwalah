defmodule App.Repo.Migrations.AddAdminRoleAndTutorVerifier do
  use Ecto.Migration

  def change do
    drop constraint(:users, :users_role_must_be_valid)

    create constraint(:users, :users_role_must_be_valid,
             check: "role IN ('student', 'tutor', 'admin')"
           )

    alter table(:users) do
      add :tutor_verified_by_id, references(:users, on_delete: :nilify_all)
    end

    create index(:users, [:tutor_verified_by_id])
  end
end
