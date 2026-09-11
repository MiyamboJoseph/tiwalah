defmodule App.RecitationsTest do
  use App.DataCase

  alias App.Recitations

  import App.AccountsFixtures

  test "a tutor can assign only after the student accepts a connection request" do
    tutor = user_fixture(%{role: :tutor, email: unique_user_email()})
    student = user_fixture(%{role: :student, email: unique_user_email()})
    tutor_scope = user_scope_fixture(tutor)
    student_scope = user_scope_fixture(student)

    assert {:error, changeset} =
             Recitations.create_assignment(tutor_scope, student.id, assignment_attrs())

    assert "must be an active student account" in errors_on(changeset).student_id

    assert {:ok, _request} = Recitations.request_student_connection(tutor_scope, student.email)
    [request] = Recitations.list_pending_tutor_requests(student_scope)
    assert {:ok, _connection} = Recitations.accept_tutor_request(student_scope, request.id)

    assert {:ok, assignment} =
             Recitations.create_assignment(tutor_scope, student.id, assignment_attrs())

    assert assignment.student_id == student.id
  end

  defp assignment_attrs do
    %{
      "title" => "Al-Fatihah revision",
      "juz_number" => "1",
      "surah_name" => "Al-Fatihah",
      "ayah_from" => "1",
      "ayah_to" => "7"
    }
  end
end
