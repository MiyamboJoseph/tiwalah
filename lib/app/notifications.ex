defmodule App.Notifications do
  import Ecto.Query

  alias App.Accounts.Scope
  alias App.Notifications.Notification
  alias App.Repo
  alias App.Workers.EmailDeliveryWorker

  def subscribe(user_id), do: Phoenix.PubSub.subscribe(App.PubSub, "notifications:#{user_id}")

  def list(%Scope{user: user}) do
    Repo.all(
      from notification in Notification,
        where: notification.user_id == ^user.id,
        order_by: [asc: is_nil(notification.read_at), desc: notification.inserted_at],
        limit: 30
    )
  end

  def unread_count(%Scope{user: user}),
    do:
      Repo.aggregate(
        from(n in Notification, where: n.user_id == ^user.id and is_nil(n.read_at)),
        :count
      )

  def create(user_id, attrs) do
    case %Notification{user_id: user_id} |> Notification.changeset(attrs) |> Repo.insert() do
      {:ok, notification} ->
        Phoenix.PubSub.broadcast(
          App.PubSub,
          "notifications:#{user_id}",
          {:notification_created, notification.id}
        )

        {:ok, notification}

      error ->
        error
    end
  end

  def mark_read(%Scope{user: user}, id) do
    with {:ok, id} <- Ecto.Type.cast(:id, id),
         %Notification{} = notification <- Repo.get_by(Notification, id: id, user_id: user.id) do
      case Repo.update(
             Ecto.Changeset.change(notification,
               read_at: DateTime.utc_now() |> DateTime.truncate(:second)
             )
           ) do
        {:ok, updated} ->
          Phoenix.PubSub.broadcast(
            App.PubSub,
            "notifications:#{user.id}",
            {:notification_read, updated.id}
          )

          {:ok, updated}

        error ->
          error
      end
    else
      _ -> {:error, :not_found}
    end
  end

  def notify_submission(tutor_email, tutor_id, student_email, title) do
    enqueue(%{
      "type" => "submission",
      "recipient" => tutor_email,
      "recipient_user_id" => tutor_id,
      "student" => student_email,
      "title" => title
    })
  end

  def notify_feedback(student_email, student_id, title, status, feedback) do
    enqueue(%{
      "type" => "feedback",
      "recipient" => student_email,
      "recipient_user_id" => student_id,
      "title" => title,
      "status" => Atom.to_string(status),
      "feedback" => feedback || ""
    })
  end

  defp enqueue(args), do: args |> EmailDeliveryWorker.new() |> Oban.insert()
end
