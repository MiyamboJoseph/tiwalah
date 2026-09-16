defmodule AppWeb.PageController do
  use AppWeb, :controller

  def home(%{assigns: %{current_scope: %{user: %{role: :tutor}}}} = conn, _params),
    do: redirect(conn, to: ~p"/tutor")

  def home(%{assigns: %{current_scope: %{user: %{role: :student}}}} = conn, _params),
    do: redirect(conn, to: ~p"/dashboard")

  def home(%{assigns: %{current_scope: %{user: %{role: :admin}}}} = conn, _params),
    do: redirect(conn, to: ~p"/admin/tutors")

  def home(conn, _params), do: render(conn, :home)

  def terms(conn, _params),
    do: render(conn, :legal, title: "Terms of Service", sections: terms_sections())

  def privacy(conn, _params),
    do: render(conn, :legal, title: "Privacy Notice", sections: privacy_sections())

  defp terms_sections do
    [
      {"Purpose",
       "Tilawah supports Qur’an recitation assignments, recordings, and respectful tutor feedback."},
      {"Respectful use",
       "Use the platform only for lawful, respectful learning and teaching. Tutors and students must communicate with ihsān."},
      {"Account responsibility",
       "Keep your password private and provide accurate profile information."}
    ]
  end

  defp privacy_sections do
    [
      {"Information we use",
       "Tilawah stores your account profile, assigned portions, recordings, and feedback needed for your learning circle."},
      {"Who can access it",
       "Recordings are available only to the student who submitted them and the connected tutor responsible for the assignment."},
      {"Contact details",
       "Your email and profile details are used to operate the service and approved learning relationships, not sold to third parties."},
      {"Prayer reminder location",
       "If you choose to enable prayer-aware reminders, Tilawah stores only an approximate latitude and longitude, not a location history. It sends those coordinates and your time zone to UmmahAPI only to calculate local prayer times. You can update or remove this location at any time in Account Settings."}
    ]
  end
end
