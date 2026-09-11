defmodule App.Recitations do
  @moduledoc "Student assignments, audio submissions, and tutor reviews."

  import Ecto.Query
  alias App.Accounts.{Scope, User}
  alias App.Notifications
  alias App.Recitations.{Assignment, Submission}
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

  def list_students(%Scope{user: %User{role: :tutor}}) do
    Repo.all(from user in User, where: user.role == :student, order_by: user.email)
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
         %User{} <- Repo.get_by(User, id: student_id, role: :student) do
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
    case get_assignment(scope, assignment_id) do
      %Assignment{status: status} = assignment when status in [:assigned, :repeat_required] ->
        %Submission{assignment_id: assignment.id, student_id: student_id}
        |> Submission.submission_changeset(attrs)
        |> Repo.insert()
        |> update_assignment_after_submission(assignment)

      %Assignment{} ->
        {:error,
         %Submission{}
         |> Submission.submission_changeset(attrs)
         |> Ecto.Changeset.add_error(:audio_path, "this portion is already awaiting review")}

      nil ->
        {:error,
         %Submission{}
         |> Submission.submission_changeset(attrs)
         |> Ecto.Changeset.add_error(:audio_path, "assignment was not found")}
    end
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

  defp update_assignment_after_submission({:ok, submission}, assignment) do
    Repo.update(Ecto.Changeset.change(assignment, status: :submitted))

    Notifications.notify_submission(
      assignment.tutor.email,
      get_user!(submission.student_id).email,
      assignment.title
    )

    broadcast_tutor(
      assignment.tutor_id,
      {:recitation_changed, :submission_received, assignment.id}
    )

    {:ok, submission}
  end

  defp update_assignment_after_submission(error, _assignment), do: error

  defp get_user!(id), do: Repo.get!(User, id)

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
