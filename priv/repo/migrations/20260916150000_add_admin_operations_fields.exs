defmodule App.Repo.Migrations.AddAdminOperationsFields do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :account_status, :string, null: false, default: "active"
      add :tutor_verification_reason, :text
    end

    create constraint(:users, :users_account_status_is_valid,
             check: "account_status IN ('active', 'suspended')"
           )

    create index(:users, [:account_status])

    create table(:admin_audit_events) do
      add :action, :string, null: false
      add :metadata, :map, null: false, default: %{}
      add :actor_id, references(:users, on_delete: :nilify_all)
      add :target_user_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:admin_audit_events, [:inserted_at])
    create index(:admin_audit_events, [:target_user_id, :inserted_at])
  end
end
