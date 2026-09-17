defmodule App.RecitationsTest do
  use App.DataCase

  alias App.Recitations
  alias App.Recitations.{Assignment, AssignmentTemplate, Submission}
  alias App.{Accounts, Repo}

  import App.AccountsFixtures

  test "a tutor can assign only after the student accepts a connection request" do
    tutor = verified_tutor()
    student = user_fixture(%{role: :student, email: unique_user_email()})
    tutor_scope = user_scope_fixture(tutor)
    student_scope = user_scope_fixture(student)

    assert {:error, changeset} =
             Recitations.create_assignment(tutor_scope, student.id, assignment_attrs())

    assert "must be an active student account" in errors_on(changeset).student_id

    assert {:ok, _request} = Recitations.request_student_connection(tutor_scope, student.id)
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
    tutor = verified_tutor()
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

  test "assignments and repeat plans reject past deadlines" do
    yesterday = Date.utc_today() |> Date.add(-1) |> Date.to_iso8601()

    assignment_changeset =
      Assignment.changeset(%Assignment{}, Map.put(assignment_attrs(), "due_date", yesterday))

    refute assignment_changeset.valid?
    assert "must be today or later" in errors_on(assignment_changeset).due_date

    repeat_changeset =
      Submission.review_changeset(%Submission{}, %{
        "status" => "repeat_required",
        "feedback" => "Please revise this passage.",
        "repeat_ayah_from" => "1",
        "repeat_ayah_to" => "2",
        "repeat_instruction" => "Listen carefully, then record again.",
        "repeat_due_date" => yesterday
      })

    refute repeat_changeset.valid?
    assert "must be today or later" in errors_on(repeat_changeset).repeat_due_date
  end

  test "repeat guidance flags each ayah outside the assignment range" do
    assignment = %Assignment{ayah_from: 20, ayah_to: 35}

    changeset =
      Submission.review_changeset(
        %Submission{},
        %{
          "status" => "repeat_required",
          "feedback" => "Please revise this passage.",
          "repeat_ayah_from" => "10",
          "repeat_ayah_to" => "55",
          "repeat_instruction" => "Listen carefully, then record again."
        },
        assignment
      )

    refute changeset.valid?
    assert "must be within the assigned ayah range" in errors_on(changeset).repeat_ayah_from
    assert "must be within the assigned ayah range" in errors_on(changeset).repeat_ayah_to
  end

  test "a student can request a verified tutor by selected tutor id" do
    tutor = verified_tutor(%{email: "Teacher@Example.com"})
    student = user_fixture(%{role: :student, email: unique_user_email()})
    tutor_scope = user_scope_fixture(tutor)
    student_scope = user_scope_fixture(student)

    assert {:ok, request} = Recitations.request_tutor_connection(student_scope, tutor.id)

    assert [pending] = Recitations.list_pending_student_requests(tutor_scope)
    assert pending.id == request.id
    assert {:ok, _connection} = Recitations.accept_student_request(tutor_scope, request.id)

    assert {:ok, _assignment} =
             Recitations.create_assignment(tutor_scope, student.id, assignment_attrs())
  end

  test "the tutor directory exposes only verified tutors without an existing connection" do
    verified = verified_tutor(%{email: unique_user_email()})
    _unverified = user_fixture(%{role: :tutor, email: unique_user_email()})
    student = user_fixture(%{role: :student, email: unique_user_email()})

    assert [%{id: tutor_id}] = Recitations.list_tutor_directory(user_scope_fixture(student))
    assert tutor_id == verified.id
  end

  test "the student directory excludes students already connected to the tutor" do
    tutor = verified_tutor()
    available_student = user_fixture(%{role: :student, email: unique_user_email()})
    connected_student = user_fixture(%{role: :student, email: unique_user_email()})
    tutor_scope = user_scope_fixture(tutor)

    assert {:ok, request} =
             Recitations.request_student_connection(tutor_scope, connected_student.id)

    assert {:ok, _connection} =
             Recitations.accept_tutor_request(user_scope_fixture(connected_student), request.id)

    assert [%{id: student_id}] = Recitations.list_student_directory(tutor_scope)
    assert student_id == available_student.id
  end

  test "a tutor cannot accept beyond their student capacity" do
    tutor = verified_tutor()
    {:ok, tutor} = Repo.update(Ecto.Changeset.change(tutor, tutor_student_limit: 1))
    tutor_scope = user_scope_fixture(tutor)
    first_student = user_fixture(%{role: :student, email: unique_user_email()})
    second_student = user_fixture(%{role: :student, email: unique_user_email()})

    assert {:ok, first_request} =
             Recitations.request_tutor_connection(user_scope_fixture(first_student), tutor.email)

    assert {:ok, _connection} = Recitations.accept_student_request(tutor_scope, first_request.id)

    assert {:ok, second_request} =
             Recitations.request_tutor_connection(user_scope_fixture(second_student), tutor.email)

    assert {:error, :tutor_capacity_reached} =
             Recitations.accept_student_request(tutor_scope, second_request.id)
  end

  test "students cannot request a tutor whose verification is not approved" do
    tutor = user_fixture(%{role: :tutor, email: unique_user_email()})
    student = user_fixture(%{role: :student, email: unique_user_email()})

    assert {:error, :tutor_unavailable} =
             Recitations.request_tutor_connection(user_scope_fixture(student), tutor.email)
  end

  defp verified_tutor(attrs \\ %{}) do
    tutor = user_fixture(Map.merge(%{role: :tutor, email: unique_user_email()}, attrs))
    {:ok, tutor} = Accounts.set_tutor_verification(tutor, :verified)
    tutor
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
