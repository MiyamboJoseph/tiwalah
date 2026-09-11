defmodule App.Repo.Migrations.AddRecitationDataIntegrityConstraints do
  use Ecto.Migration

  def change do
    create constraint(:recitation_assignments, :assignment_ayah_range_is_valid,
             check: "juz_number BETWEEN 1 AND 30 AND ayah_from >= 1 AND ayah_to >= ayah_from"
           )

    create constraint(:recitation_assignments, :assignment_status_is_valid,
             check: "status IN ('assigned', 'submitted', 'reviewed', 'repeat_required')"
           )

    create constraint(:recitation_submissions, :submission_status_is_valid,
             check: "status IN ('submitted', 'reviewed', 'repeat_required')"
           )
  end
end
