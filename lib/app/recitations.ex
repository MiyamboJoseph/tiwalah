defmodule App.Recitations do
  @moduledoc "Student assignments, audio submissions, and tutor reviews."

  import Ecto.Query
  alias App.Accounts.{Scope, User}
  alias App.Notifications
  alias App.Recitations.{Assignment, Submission, TutorStudentConnection}
  alias App.Repo

  @feedback_categories [
    "Tajwīd rules",
    "Makharij",
    "Fluency",
    "Memorisation",
    "Stopping and starting"
  ]

  def feedback_categories, do: @feedback_categories

  def subscribe_tutor(tutor_id), do: Phoenix.PubSub.subscribe(App.PubSub, tutor_topic(tutor_id))

  def subscribe_student(student_id),
    do: Phoenix.PubSub.subscribe(App.PubSub, student_topic(student_id))

  def list_students(%Scope{user: %User{role: :tutor}} = scope) do
    Repo.all(
      from connection in TutorStudentConnection,
        join: student in assoc(connection, :student),
        where: connection.tutor_id == ^scope.user.id and connection.status == :active,
        order_by: student.email,
        select: student
    )
  end

  def list_pending_tutor_requests(%Scope{user: %User{id: student_id, role: :student}}) do
    Repo.all(
      from connection in TutorStudentConnection,
        join: tutor in assoc(connection, :tutor),
        where: connection.student_id == ^student_id and connection.status == :pending,
        order_by: [desc: connection.inserted_at],
        preload: [tutor: tutor]
    )
  end

  def request_student_connection(%Scope{user: %User{id: tutor_id, role: :tutor}}, email) do
    case Repo.get_by(User, email: String.trim(email), role: :student) do
      nil ->
        {:error, :student_not_found}

      %User{id: student_id} ->
        %TutorStudentConnection{tutor_id: tutor_id, student_id: student_id}
        |> TutorStudentConnection.changeset(%{status: :pending})
        |> Repo.insert(on_conflict: :nothing, conflict_target: [:tutor_id, :student_id])
        |> case do
          {:ok, connection} ->
            broadcast_student(student_id, {:recitation_changed, :tutor_request, connection.id})
            {:ok, connection}

          error ->
            error
        end
    end
  end

  def accept_tutor_request(%Scope{user: %User{id: student_id, role: :student}}, connection_id) do
    case Repo.get_by(TutorStudentConnection,
           id: connection_id,
           student_id: student_id,
           status: :pending
         ) do
      nil ->
        {:error, :not_found}

      connection ->
        case Repo.update(TutorStudentConnection.changeset(connection, %{status: :active})) do
          {:ok, active_connection} ->
            broadcast_tutor(
              active_connection.tutor_id,
              {:recitation_changed, :student_connected, nil}
            )

            {:ok, active_connection}

          error ->
            error
        end
    end
  end

  def list_assignments(scope) do
    scope
    |> assignments_list_query()
    |> Repo.all()
  end

  def paginate_assignments(scope, page, per_page \\ 6) do
    per_page = min(max(per_page, 1), 50)
    total_entries = Repo.aggregate(assignments_base_query(scope), :count, :id)
    total_pages = max(1, div(total_entries + per_page - 1, per_page))
    page = page |> normalize_page() |> min(total_pages)

    entries =
      scope
      |> assignments_list_query()
      |> limit(^per_page)
      |> offset(^(per_page * (page - 1)))
      |> Repo.all()

    %{
      entries: entries,
      page: page,
      per_page: per_page,
      total_entries: total_entries,
      total_pages: total_pages
    }
  end

  def assignment_counts(scope) do
    counts =
      scope
      |> assignments_base_query()
      |> group_by([assignment], assignment.status)
      |> select([assignment], {assignment.status, count(assignment.id)})
      |> Repo.all()
      |> Map.new()

    %{
      total: Enum.sum(Map.values(counts)),
      assigned: Map.get(counts, :assigned, 0),
      submitted: Map.get(counts, :submitted, 0),
      reviewed: Map.get(counts, :reviewed, 0),
      repeat_required: Map.get(counts, :repeat_required, 0)
    }
  end

  def get_assignment!(%Scope{user: %User{id: user_id, role: :student}}, id) do
    Repo.one!(
      from assignment in Assignment,
        where: assignment.id == ^id and assignment.student_id == ^user_id,
        preload: [:tutor, submissions: :student]
    )
  end

  def get_assignment!(%Scope{user: %User{id: user_id, role: :tutor}}, id) do
    Repo.one!(
      from assignment in Assignment,
        where: assignment.id == ^id and assignment.tutor_id == ^user_id,
        preload: [:student, submissions: :student]
    )
  end

  def get_assignment(%Scope{user: %User{id: user_id, role: :student}}, id) do
    case Ecto.Type.cast(:id, id) do
      {:ok, id} ->
        Repo.one(
          from assignment in Assignment,
            where: assignment.id == ^id and assignment.student_id == ^user_id,
            preload: [:tutor, submissions: :student]
        )

      :error ->
        nil
    end
  end

  def get_assignment(%Scope{user: %User{id: user_id, role: :tutor}}, id) do
    case Ecto.Type.cast(:id, id) do
      {:ok, id} ->
        Repo.one(
          from assignment in Assignment,
            where: assignment.id == ^id and assignment.tutor_id == ^user_id,
            preload: [:student, submissions: :student]
        )

      :error ->
        nil
    end
  end

  def create_assignment(%Scope{user: %User{id: tutor_id, role: :tutor}}, student_id, attrs) do
    with {:ok, student_id} <- Ecto.Type.cast(:id, student_id),
         %TutorStudentConnection{status: :active} <-
           Repo.get_by(TutorStudentConnection,
             tutor_id: tutor_id,
             student_id: student_id,
             status: :active
           ) do
      case %Assignment{tutor_id: tutor_id, student_id: student_id}
           |> Assignment.changeset(attrs)
           |> Repo.insert() do
        {:ok, assignment} ->
          broadcast_student(
            student_id,
            {:recitation_changed, :assignment_assigned, assignment.id}
          )

          {:ok, assignment}

        error ->
          error
      end
    else
      _ ->
        changeset =
          %Assignment{}
          |> Assignment.changeset(attrs)
          |> Ecto.Changeset.add_error(:student_id, "must be an active student account")

        {:error, changeset}
    end
  end

  def create_submission(
        %Scope{user: %User{id: student_id, role: :student}} = scope,
        assignment_id,
        attrs
      ) do
    result =
      Repo.transact(fn ->
        assignment =
          Repo.one(
            from assignment in Assignment,
              where: assignment.id == ^assignment_id and assignment.student_id == ^student_id,
              lock: "FOR UPDATE",
              preload: [:tutor]
          )

        case assignment do
          %Assignment{status: status} when status in [:assigned, :repeat_required] ->
            with {:ok, submission} <-
                   %Submission{assignment_id: assignment.id, student_id: student_id}
                   |> Submission.submission_changeset(attrs)
                   |> Repo.insert(),
                 {:ok, _assignment} <-
                   Repo.update(Ecto.Changeset.change(assignment, status: :submitted)) do
              {submission, assignment}
            else
              {:error, changeset} -> Repo.rollback(changeset)
            end

          %Assignment{} ->
            Repo.rollback(submission_error(attrs, "this portion is already awaiting review"))

          nil ->
            Repo.rollback(submission_error(attrs, "assignment was not found"))
        end
      end)

    case result do
      {:ok, {submission, assignment}} ->
        Notifications.notify_submission(
          assignment.tutor.email,
          scope.user.email,
          assignment.title
        )

        broadcast_tutor(
          assignment.tutor_id,
          {:recitation_changed, :submission_received, assignment.id}
        )

        {:ok, submission}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def get_submission_audio(%Scope{user: %User{id: user_id, role: :student}}, id) do
    get_submission_audio_query(
      id,
      dynamic([submission, assignment], assignment.student_id == ^user_id)
    )
  end

  def get_submission_audio(%Scope{user: %User{id: user_id, role: :tutor}}, id) do
    get_submission_audio_query(
      id,
      dynamic([submission, assignment], assignment.tutor_id == ^user_id)
    )
  end

  def review_submission(%Scope{user: %User{role: :tutor}} = scope, submission_id, attrs) do
    submission =
      Repo.one(
        from submission in Submission,
          join: assignment in assoc(submission, :assignment),
          where:
            submission.id == ^submission_id and assignment.tutor_id == ^scope.user.id and
              submission.status == :submitted,
          preload: [:assignment, :student]
      )

    if submission do
      case Repo.transact(fn ->
             with {:ok, reviewed} <- Repo.update(Submission.review_changeset(submission, attrs)),
                  {:ok, _assignment} <-
                    Repo.update(
                      Ecto.Changeset.change(submission.assignment, status: reviewed.status)
                    ) do
               {:ok, reviewed}
             else
               {:error, changeset} -> Repo.rollback(changeset)
             end
           end) do
        {:ok, reviewed} ->
          Notifications.notify_feedback(
            submission.student.email,
            submission.assignment.title,
            reviewed.status,
            reviewed.feedback
          )

          broadcast_student(
            submission.student_id,
            {:recitation_changed, :feedback_sent, submission.assignment_id}
          )

          broadcast_tutor(
            scope.user.id,
            {:recitation_changed, :review_saved, submission.assignment_id}
          )

          {:ok, reviewed}

        error ->
          error
      end
    else
      {:error, :not_found}
    end
  end

  defp submission_error(attrs, message) do
    %Submission{}
    |> Submission.submission_changeset(attrs)
    |> Ecto.Changeset.add_error(:audio_path, message)
  end

  defp get_submission_audio_query(id, ownership_filter) do
    case Ecto.Type.cast(:id, id) do
      {:ok, id} ->
        case Repo.one(
               from submission in Submission,
                 join: assignment in assoc(submission, :assignment),
                 where: submission.id == ^id and ^ownership_filter,
                 select: submission
             ) do
          nil -> :error
          submission -> {:ok, submission}
        end

      :error ->
        :error
    end
  end

  defp assignments_base_query(%Scope{user: %User{id: user_id, role: :student}}) do
    from assignment in Assignment, where: assignment.student_id == ^user_id
  end

  defp assignments_base_query(%Scope{user: %User{id: user_id, role: :tutor}}) do
    from assignment in Assignment, where: assignment.tutor_id == ^user_id
  end

  defp assignments_list_query(%Scope{user: %User{role: :student}} = scope) do
    scope
    |> assignments_base_query()
    |> preload([:tutor, :submissions])
    |> order_by([assignment], desc: assignment.inserted_at)
  end

  defp assignments_list_query(%Scope{user: %User{role: :tutor}} = scope) do
    scope
    |> assignments_base_query()
    |> preload([:student, submissions: :student])
    |> order_by([assignment], desc: assignment.inserted_at)
  end

  defp normalize_page(page) when is_integer(page), do: max(page, 1)

  defp normalize_page(page) when is_binary(page) do
    case Integer.parse(page) do
      {number, ""} -> max(number, 1)
      _ -> 1
    end
  end

  defp normalize_page(_page), do: 1

  defp broadcast_tutor(tutor_id, message),
    do: Phoenix.PubSub.broadcast(App.PubSub, tutor_topic(tutor_id), message)

  defp broadcast_student(student_id, message),
    do: Phoenix.PubSub.broadcast(App.PubSub, student_topic(student_id), message)

  defp tutor_topic(tutor_id), do: "recitations:tutor:#{tutor_id}"
  defp student_topic(student_id), do: "recitations:student:#{student_id}"
end
