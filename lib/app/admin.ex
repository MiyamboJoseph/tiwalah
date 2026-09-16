defmodule App.Admin do
  @moduledoc "Administrator-only reporting and connection oversight."

  import Ecto.Query

  alias App.Accounts.{Scope, User}
  alias App.Accounts
  alias App.Notifications
  alias App.Recitations.{Assignment, Submission, TutorStudentConnection}
  alias App.Repo

  def dashboard(%Scope{user: %User{role: :admin}} = scope) do
    %{
      pending_tutors: count_users(role: :tutor, tutor_verification_status: :pending),
      verified_tutors: count_users(role: :tutor, tutor_verification_status: :verified),
      students: count_users(role: :student),
      suspended_accounts: count_users(account_status: :suspended),
      active_connections:
        Repo.aggregate(from(c in TutorStudentConnection, where: c.status == :active), :count),
      pending_connections:
        Repo.aggregate(from(c in TutorStudentConnection, where: c.status == :pending), :count),
      awaiting_review:
        Repo.aggregate(from(s in Submission, where: s.status == :submitted), :count),
      active_assignments:
        Repo.aggregate(
          from(a in Assignment, where: a.status in [:assigned, :submitted, :repeat_required]),
          :count
        ),
      tutor_roster: tutor_roster(),
      recent_events: Accounts.admin_list_audit_events(scope)
    }
  end

  def list_connections(%Scope{user: %User{role: :admin}}, status \\ "all") do
    connections_query(status)
    |> Repo.all()
  end

  def paginate_connections(%Scope{user: %User{role: :admin}}, status, page, per_page \\ 12) do
    query = connections_query(status)
    per_page = min(max(per_page, 1), 50)
    total_entries = Repo.aggregate(query, :count, :id)
    total_pages = max(1, div(total_entries + per_page - 1, per_page))
    page = page |> normalize_page() |> min(total_pages)

    %{
      entries: query |> limit(^per_page) |> offset(^(per_page * (page - 1))) |> Repo.all(),
      page: page,
      per_page: per_page,
      total_entries: total_entries,
      total_pages: total_pages
    }
  end

  defp connections_query(status) do
    query =
      from connection in TutorStudentConnection,
        order_by: [desc: connection.inserted_at],
        preload: [:tutor, :student]

    query =
      if status in ["active", "pending"],
        do: from(c in query, where: c.status == ^status),
        else: query

    query
  end

  def end_connection(%Scope{user: %User{id: admin_id, role: :admin}}, connection_id, reason) do
    with {:ok, id} <- Ecto.Type.cast(:id, connection_id),
         %TutorStudentConnection{} = connection <- Repo.get(TutorStudentConnection, id),
         reason when is_binary(reason) and reason != "" <- String.trim(reason),
         {:ok, _connection} <- Repo.delete(connection) do
      Accounts.record_admin_event(admin_id, connection.student_id, "connection_ended", %{
        "connection_id" => connection.id,
        "tutor_id" => connection.tutor_id,
        "reason" => reason
      })

      Enum.each([connection.student_id, connection.tutor_id], fn user_id ->
        Notifications.create(user_id, %{
          kind: "connection",
          title: "Learning connection closed by an administrator",
          body: reason,
          path: "/notifications"
        })
      end)

      {:ok, connection}
    else
      nil -> {:error, :not_found}
      :error -> {:error, :not_found}
      _ -> {:error, :reason_required}
    end
  end

  defp count_users(filters) do
    filters
    |> Enum.reduce(from(user in User), fn {field, value}, query ->
      from user in query, where: field(user, ^field) == ^value
    end)
    |> Repo.aggregate(:count)
  end

  defp tutor_roster do
    connection_counts =
      Repo.all(
        from connection in TutorStudentConnection,
          where: connection.status == :active,
          group_by: connection.tutor_id,
          select: {connection.tutor_id, count(connection.id)}
      )
      |> Map.new()

    Repo.all(
      from tutor in User,
        where: tutor.role == :tutor,
        order_by: [asc: tutor.first_name, asc: tutor.last_name, asc: tutor.email]
    )
    |> Enum.map(fn tutor ->
      %{tutor: tutor, connected_students: Map.get(connection_counts, tutor.id, 0)}
    end)
    |> Enum.take(8)
  end

  defp normalize_page(page) when is_integer(page), do: max(page, 1)

  defp normalize_page(page) when is_binary(page) do
    case Integer.parse(page) do
      {number, ""} -> max(number, 1)
      _ -> 1
    end
  end

  defp normalize_page(_page), do: 1
end
