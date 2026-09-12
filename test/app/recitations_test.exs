defmodule App.RecitationsTest do
  use App.DataCase

  alias App.Recitations
  alias App.Recitations.AssignmentTemplate

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
    assert %{active: 1, reviewed: 0} = Recitations.assignment_counts(tutor_scope)

    assert {:ok, submission} =
             Recitations.create_submission(student_scope, assignment.id, %{
               "audio_path" => "test-recording.webm"
             })

    assert {:ok, _reviewed} =
             Recitations.review_submission(tutor_scope, submission.id, %{
               "status" => "reviewed"
             })

    assert %{active: 0, reviewed: 1, total: 1} = Recitations.assignment_counts(tutor_scope)
  end

  test "a student can decline a request or end an accepted tutor connection" do
    tutor = user_fixture(%{role: :tutor, email: unique_user_email()})
    student = user_fixture(%{role: :student, email: unique_user_email()})
    tutor_scope = user_scope_fixture(tutor)
    student_scope = user_scope_fixture(student)

    assert {:ok, request} = Recitations.request_student_connection(tutor_scope, student.email)
    assert {:ok, _} = Recitations.decline_tutor_request(student_scope, request.id)
    assert [] == Recitations.list_pending_tutor_requests(student_scope)

    assert {:ok, request} = Recitations.request_student_connection(tutor_scope, student.email)
    assert {:ok, connection} = Recitations.accept_tutor_request(student_scope, request.id)
    assert {:ok, _} = Recitations.disconnect_tutor_student(student_scope, connection.id)

    assert {:error, changeset} =
             Recitations.create_assignment(tutor_scope, student.id, assignment_attrs())

    assert "must be an active student account" in errors_on(changeset).student_id
  end

  test "assignment templates reject a Juz that does not match the first ayah" do
    changeset =
      AssignmentTemplate.changeset(%AssignmentTemplate{}, %{
        "title" => "Incorrect template",
        "juz_number" => "2",
        "surah_name" => "Al-Fatihah",
        "ayah_from" => "1",
        "ayah_to" => "7"
      })

    refute changeset.valid?
    assert "does not match the first selected ayah" in errors_on(changeset).juz_number
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
