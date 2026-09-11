defmodule App.Repo.Migrations.AddRegistrationProfileAndConsentFields do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :terms_accepted_at, :utc_datetime
      add :tutor_qualification, :text
      add :tutor_experience_years, :integer
      add :tutor_languages, :string
      add :tutor_teaching_format, :string
      add :tutor_availability, :text
      add :tutor_bio, :text
    end
  end
end
