defmodule App.Recitations do
  @moduledoc "Student assignments, audio submissions, and tutor reviews."

  import Ecto.Query
  alias App.Accounts.{Scope, User}
  alias App.Notifications
  alias App.Recitations.{Assignment, AssignmentTemplate, Submission, TutorStudentConnection}
  alias App.Repo

  @feedback_categories [
    "Tajwīd rules",
    "Makharij",
    "Fluency",
    "Memorisation",
    "Stopping and starting"
  ]

  def feedback_categories, do: @feedback_categories

  def list_templates(%Scope{user: %User{id: tutor_id, role: :tutor}}) do
    Repo.all(
      from template in AssignmentTemplate,
        where: template.tutor_id == ^tutor_id,
        order_by: [desc: template.inserted_at]
    )
  end

  def create_template(%Scope{user: %User{id: tutor_id, role: :tutor}}, attrs) do
    %AssignmentTemplate{tutor_id: tutor_id}
    |> AssignmentTemplate.changeset(attrs)
    |> Repo.insert()
  end

  def student_progress(%Scope{user: %User{id: student_id, role: :student}}) do
    submissions = Repo.all(from s in Submission, where: s.student_id == ^student_id)
    reviewed = Enum.count(submissions, &(&1.status == :reviewed))
    repeats = Enum.count(submissions, &(&1.status == :repeat_required))
    total = length(submissions)

    categories =
      submissions
      |> Enum.flat_map(&(&1.feedback_categories || []))
      |> Enum.frequencies()
      |> Enum.sort_by(fn {_category, count} -> -count end)
      |> Enum.take(3)

    %{
      total_submissions: total,
      approved: reviewed,
      repeats: repeats,
      approval_rate: if(total == 0, do: 0, else: round(reviewed * 100 / total)),
      focus_areas: categories
    }
  end

  def student_overview(%Scope{user: %User{id: tutor_id, role: :tutor}}, student_id) do
    with {:ok, student_id} <- Ecto.Type.cast(:id, student_id),
         %TutorStudentConnection{status: :active} <-
           Repo.get_by(TutorStudentConnection,
             tutor_id: tutor_id,
             student_id: student_id,
             status: :active
           ),
         %User{} = student <- Repo.get(User, student_id) do
      assignments =
        Repo.all(
          from a in Assignment,
            where: a.tutor_id == ^tutor_id and a.student_id == ^student_id,
            preload: [:submissions],
            order_by: [desc: a.updated_at]
        )

      submissions = Enum.flat_map(assignments, & &1.submissions)

      trends =
        submissions
        |> Enum.flat_map(&(&1.feedback_categories || []))
        |> Enum.frequencies()
        |> Enum.sort_by(fn {_item, count} -> -count end)

      {:ok,
       %{
         student: student,
         assignments: assignments,
         submissions: submissions,
         correction_trends: trends
       }}
    else
      _ -> {:error, :not_found}
    end
  end

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

  def list_active_connections(%Scope{user: %User{id: tutor_id, role: :tutor}}) do
    Repo.all(
      from connection in TutorStudentConnection,
        where: connection.tutor_id == ^tutor_id and connection.status == :active,
        order_by: [asc: connection.inserted_at],
        preload: [:student]
    )
  end

  def list_active_tutors(%Scope{user: %User{id: student_id, role: :student}}) do
    Repo.all(
      from connection in TutorStudentConnection,
        join: tutor in assoc(connection, :tutor),
        where: connection.student_id == ^student_id and connection.status == :active,
        order_by: tutor.email,
        select: {connection.id, tutor}
    )
  end

  def list_pending_tutor_requests(%Scope{user: %User{id: student_id, role: :student}}) do
    Repo.all(
      from connection in TutorStudentConnection,
        join: tutor in assoc(connection, :tutor),
        where:
          connection.student_id == ^student_id and connection.status == :pending and
            connection.requested_by == :tutor,
        order_by: [desc: connection.inserted_at],
        preload: [tutor: tutor]
    )
  end

  def list_pending_requested_tutors(%Scope{user: %User{id: student_id, role: :student}}) do
    Repo.all(
      from connection in TutorStudentConnection,
        join: tutor in assoc(connection, :tutor),
        where:
          connection.student_id == ^student_id and connection.status == :pending and
            connection.requested_by == :student,
        order_by: [desc: connection.inserted_at],
        preload: [tutor: tutor]
    )
  end

  def list_tutor_directory(%Scope{user: %User{id: student_id, role: :student}}) do
    Repo.all(
      from tutor in User,
        left_join: connection in TutorStudentConnection,
        on: connection.tutor_id == tutor.id and connection.student_id == ^student_id,
        where:
          tutor.role == :tutor and tutor.tutor_verification_status == :verified and
            is_nil(connection.id),
        order_by: [asc: tutor.first_name, asc: tutor.last_name, asc: tutor.email],
        limit: 30
    )
  end

  def list_pending_student_requests(%Scope{user: %User{id: tutor_id, role: :tutor}}) do
    Repo.all(
      from connection in TutorStudentConnection,
        join: student in assoc(connection, :student),
        where:
          connection.tutor_id == ^tutor_id and connection.status == :pending and
            connection.requested_by == :student,
        order_by: [desc: connection.inserted_at],
        preload: [student: student]
    )
  end

  def request_student_connection(%Scope{user: %User{id: tutor_id, role: :tutor}}, email) do
    with :ok <- ensure_tutor_available(tutor_id) do
      request_student_connection_for_tutor(tutor_id, email)
    end
  end

  defp request_student_connection_for_tutor(tutor_id, email) do
    case find_user_by_email_and_role(email, :student) do
      nil ->
        {:error, :student_not_found}

      %User{id: student_id} ->
        case Repo.get_by(TutorStudentConnection, tutor_id: tutor_id, student_id: student_id) do
          %TutorStudentConnection{status: :active} ->
            {:error, :already_connected}

          %TutorStudentConnection{status: :pending} ->
            {:error, :already_requested}

          nil ->
            %TutorStudentConnection{tutor_id: tutor_id, student_id: student_id}
            |> TutorStudentConnection.changeset(%{status: :pending, requested_by: :tutor})
            |> Repo.insert()
            |> case do
              {:ok, connection} ->
                broadcast_student(
                  student_id,
                  {:recitation_changed, :tutor_request, connection.id}
                )

                Notifications.create(student_id, %{
                  kind: "tutor_request",
                  title: "New tutor request",
                  body: "A tutor would like to guide your recitation.",
                  path: "/dashboard"
                })

                {:ok, connection}

              {:error, changeset} ->
                connection_insert_error(changeset)
            end
        end
    end
  end

  def request_tutor_connection(%Scope{user: %User{id: student_id, role: :student}}, tutor_id)
      when is_integer(tutor_id) do
    request_tutor_connection_for_student_id(tutor_id, student_id)
  end

  def request_tutor_connection(%Scope{user: %User{id: student_id, role: :student}}, tutor_id)
      when is_binary(tutor_id) do
    case Integer.parse(tutor_id) do
      {id, ""} -> request_tutor_connection_for_student_id(id, student_id)
      _ -> request_tutor_connection_for_student_email(tutor_id, student_id)
    end
  end

  defp request_tutor_connection_for_student_id(tutor_id, student_id) do
    case Repo.get(User, tutor_id) do
      %User{role: :tutor, tutor_verification_status: :verified} ->
        request_tutor_connection_for_student(tutor_id, student_id)

      _ ->
        {:error, :tutor_not_found}
    end
  end

  defp request_tutor_connection_for_student_email(email, student_id) do
    case find_user_by_email_and_role(email, :tutor) do
      nil ->
        {:error, :tutor_not_found}

      %User{id: tutor_id, tutor_verification_status: :verified} ->
        request_tutor_connection_for_student(tutor_id, student_id)

      %User{} ->
        {:error, :tutor_unavailable}
    end
  end

  defp request_tutor_connection_for_student(tutor_id, student_id) do
    case Repo.get_by(TutorStudentConnection, tutor_id: tutor_id, student_id: student_id) do
      %TutorStudentConnection{status: :active} ->
        {:error, :already_connected}

      %TutorStudentConnection{status: :pending, requested_by: :student} ->
        {:error, :already_requested}

      %TutorStudentConnection{status: :pending, requested_by: :tutor} ->
        {:error, :tutor_invited}

      nil ->
        %TutorStudentConnection{tutor_id: tutor_id, student_id: student_id}
        |> TutorStudentConnection.changeset(%{status: :pending, requested_by: :student})
        |> Repo.insert()
        |> case do
          {:ok, connection} ->
            broadcast_tutor(tutor_id, {:recitation_changed, :student_request, connection.id})

            Notifications.create(tutor_id, %{
              kind: "student_request",
              title: "New student learning request",
              body: "A student would like to join your recitation circle.",
              path: "/tutor"
            })

            {:ok, connection}

          {:error, changeset} ->
            connection_insert_error(changeset)
        end
    end
  end

  def accept_tutor_request(%Scope{user: %User{id: student_id, role: :student}}, connection_id) do
    case Repo.get_by(TutorStudentConnection,
           id: connection_id,
           student_id: student_id,
           status: :pending,
           requested_by: :tutor
         ) do
      nil ->
        {:error, :not_found}

      connection ->
        if tutor_available?(connection.tutor_id) do
          case Repo.update(TutorStudentConnection.changeset(connection, %{status: :active})) do
            {:ok, active_connection} ->
              broadcast_tutor(
                active_connection.tutor_id,
                {:recitation_changed, :student_connected, nil}
              )

              Notifications.create(active_connection.tutor_id, %{
                kind: "student_connected",
                title: "Student connection accepted",
                body: "You can now assign portions to this student.",
                path: "/tutor"
              })

              {:ok, active_connection}

            error ->
              error
          end
        else
          {:error, :tutor_unavailable}
        end
    end
  end

  def decline_tutor_request(%Scope{user: %User{id: student_id, role: :student}}, connection_id) do
    case Repo.get_by(TutorStudentConnection,
           id: connection_id,
           student_id: student_id,
           status: :pending,
           requested_by: :tutor
         ) do
      nil ->
        {:error, :not_found}

      connection ->
        case Repo.delete(connection) do
          {:ok, deleted_connection} ->
            broadcast_tutor(
              deleted_connection.tutor_id,
              {:recitation_changed, :tutor_request_declined, nil}
            )

            Notifications.create(deleted_connection.tutor_id, %{
              kind: "tutor_request_declined",
              title: "Tutor invitation declined",
              body: "The student declined your invitation to join their recitation circle.",
              path: "/tutor"
            })

            {:ok, deleted_connection}

          error ->
            error
        end
    end
  end

  def accept_student_request(%Scope{user: %User{id: tutor_id, role: :tutor}}, connection_id) do
    case Repo.get_by(TutorStudentConnection,
           id: connection_id,
           tutor_id: tutor_id,
           status: :pending,
           requested_by: :student
         ) do
      nil ->
        {:error, :not_found}

      connection ->
        with :ok <- ensure_tutor_available(tutor_id),
             :ok <- ensure_tutor_capacity(tutor_id) do
          case Repo.update(TutorStudentConnection.changeset(connection, %{status: :active})) do
            {:ok, active_connection} ->
              broadcast_student(
                active_connection.student_id,
                {:recitation_changed, :tutor_connected, nil}
              )

              Notifications.create(active_connection.student_id, %{
                kind: "tutor_request_accepted",
                title: "Your tutor request was accepted",
                body: "Your teacher can now assign recitation portions and send guidance.",
                path: "/dashboard"
              })

              {:ok, active_connection}

            error ->
              error
          end
        end
    end
  end

  def decline_student_request(%Scope{user: %User{id: tutor_id, role: :tutor}}, connection_id) do
    case Repo.get_by(TutorStudentConnection,
           id: connection_id,
           tutor_id: tutor_id,
           status: :pending,
           requested_by: :student
         ) do
      nil ->
        {:error, :not_found}

      connection ->
        case Repo.delete(connection) do
          {:ok, deleted_connection} ->
            broadcast_student(
              deleted_connection.student_id,
              {:recitation_changed, :tutor_request_declined, nil}
            )

            Notifications.create(deleted_connection.student_id, %{
              kind: "tutor_request_declined",
              title: "Tutor request declined",
              body: "This teacher is unable to take on your request at this time.",
              path: "/dashboard"
            })

            {:ok, deleted_connection}

          error ->
            error
        end
    end
  end

  def disconnect_tutor_student(%Scope{user: %User{id: student_id, role: :student}}, connection_id) do
    disconnect_connection(connection_id, student_id: student_id)
  end

  def disconnect_tutor_student(%Scope{user: %User{id: tutor_id, role: :tutor}}, connection_id) do
    disconnect_connection(connection_id, tutor_id: tutor_id)
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
      active:
        Map.get(counts, :assigned, 0) + Map.get(counts, :submitted, 0) +
          Map.get(counts, :repeat_required, 0),
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

          Notifications.create(student_id, %{
            kind: "assignment",
            title: "New recitation assigned",
            body: assignment.title,
            path: "/recitations/new/#{assignment.id}"
          })

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
              {:ok, {submission, assignment}}
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
          assignment.tutor_id,
          scope.user.email,
          assignment.title
        )

        broadcast_tutor(
          assignment.tutor_id,
          {:recitation_changed, :submission_received, assignment.id}
        )

        Notifications.create(assignment.tutor_id, %{
          kind: "submission",
          title: "New recitation to review",
          body: "#{scope.user.email} submitted #{assignment.title}.",
          path: "/tutor/reviews/#{assignment.id}"
        })

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
             with {:ok, reviewed} <-
                    Repo.update(
                      Submission.review_changeset(submission, attrs, submission.assignment)
                    ),
                  {:ok, _assignment} <-
                    Repo.update(
                      Ecto.Changeset.change(submission.assignment,
                        status: reviewed.status,
                        due_date: review_due_date(submission.assignment, reviewed)
                      )
                    ) do
               {:ok, reviewed}
             else
               {:error, changeset} -> Repo.rollback(changeset)
             end
           end) do
        {:ok, reviewed} ->
          Notifications.notify_feedback(
            submission.student.email,
            submission.student_id,
            submission.assignment.title,
            reviewed.status,
            reviewed.feedback
          )

          broadcast_student(
            submission.student_id,
            {:recitation_changed, :feedback_sent, submission.assignment_id}
          )

          Notifications.create(submission.student_id, %{
            kind: "feedback",
            title:
              if(reviewed.status == :repeat_required,
                do: "Repeat requested",
                else: "Recitation approved"
              ),
            body: submission.assignment.title,
            path: "/recitations/#{submission.assignment_id}"
          })

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

  defp disconnect_connection(connection_id, ownership) do
    filters = Keyword.merge([id: connection_id, status: :active], ownership)

    case Repo.get_by(TutorStudentConnection, filters) do
      nil ->
        {:error, :not_found}

      connection ->
        case Repo.delete(connection) do
          {:ok, deleted} ->
            broadcast_tutor(deleted.tutor_id, {:recitation_changed, :student_disconnected, nil})
            broadcast_student(deleted.student_id, {:recitation_changed, :tutor_disconnected, nil})
            {:ok, deleted}

          error ->
            error
        end
    end
  end

  def get_feedback_audio(%Scope{user: %User{id: user_id, role: :student}}, id) do
    get_feedback_audio_query(
      id,
      dynamic([submission, assignment], assignment.student_id == ^user_id)
    )
  end

  def get_feedback_audio(%Scope{user: %User{id: user_id, role: :tutor}}, id) do
    get_feedback_audio_query(
      id,
      dynamic([submission, assignment], assignment.tutor_id == ^user_id)
    )
  end

  defp get_submission_audio_query(id, ownership_filter) do
    case Ecto.Type.cast(:id, id) do
      {:ok, id} ->
        case Repo.one(
               from submission in Submission,
                 join: assignment in assoc(submission, :assignment),
                 where: submission.id == ^id,
                 where: ^ownership_filter,
                 select: submission
             ) do
          nil -> :error
          submission -> {:ok, submission}
        end

      :error ->
        :error
    end
  end

  defp get_feedback_audio_query(id, ownership_filter) do
    case Ecto.Type.cast(:id, id) do
      {:ok, id} ->
        case Repo.one(
               from submission in Submission,
                 join: assignment in assoc(submission, :assignment),
                 where: submission.id == ^id and not is_nil(submission.tutor_audio_path),
                 where: ^ownership_filter,
                 select: submission
             ) do
          nil -> :error
          submission -> {:ok, submission}
        end

      :error ->
        :error
    end
  end

  defp review_due_date(assignment, %{status: :repeat_required, repeat_due_date: due_date}) do
    due_date || assignment.due_date
  end

  defp review_due_date(assignment, _reviewed), do: assignment.due_date

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

  defp find_user_by_email_and_role(email, role) do
    Repo.get_by(User, email: email |> String.trim() |> String.downcase(), role: role)
  end

  defp tutor_available?(tutor_id) do
    match?(%User{role: :tutor, tutor_verification_status: :verified}, Repo.get(User, tutor_id))
  end

  defp ensure_tutor_available(tutor_id) do
    if tutor_available?(tutor_id), do: :ok, else: {:error, :tutor_unavailable}
  end

  defp ensure_tutor_capacity(tutor_id) do
    tutor = Repo.get(User, tutor_id)

    active_students =
      Repo.aggregate(
        from(connection in TutorStudentConnection,
          where: connection.tutor_id == ^tutor_id and connection.status == :active
        ),
        :count
      )

    if active_students < tutor.tutor_student_limit,
      do: :ok,
      else: {:error, :tutor_capacity_reached}
  end

  defp connection_insert_error(changeset) do
    if Keyword.has_key?(changeset.errors, :student_id),
      do: {:error, :already_requested},
      else: {:error, changeset}
  end

  defp broadcast_tutor(tutor_id, message),
    do: Phoenix.PubSub.broadcast(App.PubSub, tutor_topic(tutor_id), message)

  defp broadcast_student(student_id, message),
    do: Phoenix.PubSub.broadcast(App.PubSub, student_topic(student_id), message)

  defp tutor_topic(tutor_id), do: "recitations:tutor:#{tutor_id}"
  defp student_topic(student_id), do: "recitations:student:#{student_id}"
end
