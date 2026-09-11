defmodule App.Repo.Migrations.AddRepeatGuidanceToRecitationSubmissions do
  use Ecto.Migration

  def change do
    alter table(:recitation_submissions) do
      add :repeat_ayah_from, :integer
      add :repeat_ayah_to, :integer
      add :repeat_instruction, :text
      add :repeat_due_date, :date
      add :tutor_audio_path, :string
    end

    create constraint(:recitation_submissions, :repeat_ayah_range_is_valid,
             check:
               "repeat_ayah_from IS NULL OR repeat_ayah_to IS NULL OR repeat_ayah_to >= repeat_ayah_from"
           )
  end
end
