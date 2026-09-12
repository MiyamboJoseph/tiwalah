defmodule App.Repo.Migrations.AddTutorStudentLimit do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :tutor_student_limit, :integer, null: false, default: 20
    end

    create constraint(:users, :users_tutor_student_limit_positive,
             check: "tutor_student_limit >= 1 AND tutor_student_limit <= 500"
           )
  end
end
