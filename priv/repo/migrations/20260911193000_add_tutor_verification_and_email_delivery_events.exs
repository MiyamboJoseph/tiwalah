defmodule App.Repo.Migrations.AddTutorVerificationAndEmailDeliveryEvents do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :tutor_verification_status, :string, null: false, default: "not_applicable"
      add :tutor_verified_at, :utc_datetime
    end

    create constraint(:users, :tutor_verification_status_is_valid,
             check:
               "tutor_verification_status IN ('not_applicable', 'pending', 'verified', 'rejected')"
           )

    create table(:email_delivery_events) do
      add :oban_job_id, :bigint, null: false
      add :user_id, references(:users, on_delete: :nilify_all)
      add :event_type, :string, null: false
      add :recipient, :string, null: false
      add :status, :string, null: false
      add :last_error, :text
      add :sent_at, :utc_datetime
      timestamps(type: :utc_datetime)
    end

    create unique_index(:email_delivery_events, [:oban_job_id])
    create index(:email_delivery_events, [:user_id, :inserted_at])
  end
end
