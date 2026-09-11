defmodule App.Repo.Migrations.AddFeedbackCategoriesToRecitationSubmissions do
  use Ecto.Migration

  def change do
    alter table(:recitation_submissions) do
      add :feedback_categories, {:array, :string}, null: false, default: []
    end
  end
end
