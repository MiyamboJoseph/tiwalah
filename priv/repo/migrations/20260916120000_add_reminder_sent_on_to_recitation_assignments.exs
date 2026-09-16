defmodule App.Repo.Migrations.AddReminderSentOnToRecitationAssignments do
  use Ecto.Migration

  def change do
    alter table(:recitation_assignments) do
      add :reminder_sent_on, :date
    end

    create index(:recitation_assignments, [:reminder_sent_on])
  end
end
