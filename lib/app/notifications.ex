defmodule App.Notifications do
  import Ecto.Query

  alias App.Accounts.Scope
  alias App.Accounts.UserNotifier
  alias App.EmailTemplates
  alias App.Notifications.Notification
  alias App.Repo

  @email_types %{
    "assignment" => :assignment,
    "connection_accepted" => :connection_accepted,
    "connection_declined" => :connection_declined,
    "connection_request" => :connection_request,
    "feedback" => :feedback,
    "reminder" => :reminder,
    "submission" => :submission,
    "tutor_invitation" => :tutor_invitation,
    "tutor_verification" => :tutor_verification,
    "welcome" => :welcome
  }

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

  def notify_welcome(user) do
    deliver_email(%{
      "type" => "welcome",
      "recipient" => user.email,
      "recipient_user_id" => user.id,
      "name" => user.first_name || user.email,
      "role" => Atom.to_string(user.role)
    })
  end

  def notify_feedback(student_email, student_id, title, status, feedback, details \\ %{}) do
    enqueue(
      Map.merge(
        %{
          "type" => "feedback",
          "recipient" => student_email,
          "recipient_user_id" => student_id,
          "title" => title,
          "status" => Atom.to_string(status),
          "feedback" => feedback || ""
        },
        details
      )
    )
  end

  def notify_connection_request(tutor_email, tutor_id, requester) do
    enqueue(%{
      "type" => "connection_request",
      "recipient" => tutor_email,
      "recipient_user_id" => tutor_id,
      "requester" => requester
    })
  end

  def notify_tutor_invitation(student_email, student_id, requester) do
    enqueue(%{
      "type" => "tutor_invitation",
      "recipient" => student_email,
      "recipient_user_id" => student_id,
      "requester" => requester
    })
  end

  def notify_connection_accepted(recipient_email, recipient_id, counterpart, portal_path) do
    enqueue(%{
      "type" => "connection_accepted",
      "recipient" => recipient_email,
      "recipient_user_id" => recipient_id,
      "counterpart" => counterpart,
      "portal_path" => portal_path
    })
  end

  def notify_connection_declined(
        recipient_email,
        recipient_id,
        counterpart,
        action_label,
        portal_path
      ) do
    enqueue(%{
      "type" => "connection_declined",
      "recipient" => recipient_email,
      "recipient_user_id" => recipient_id,
      "counterpart" => counterpart,
      "action_label" => action_label,
      "portal_path" => portal_path
    })
  end

  def notify_assignment(student_email, student_id, title, path, details \\ %{}) do
    enqueue(
      Map.merge(
        %{
          "type" => "assignment",
          "recipient" => student_email,
          "recipient_user_id" => student_id,
          "title" => title,
          "path" => path
        },
        details
      )
    )
  end

  def notify_tutor_verification(tutor_email, tutor_id, status) do
    enqueue(%{
      "type" => "tutor_verification",
      "recipient" => tutor_email,
      "recipient_user_id" => tutor_id,
      "status" => Atom.to_string(status)
    })
  end

  def notify_reminder(student_email, student_id, title, details \\ %{}) do
    deliver_email(
      Map.merge(
        %{
          "type" => "reminder",
          "recipient" => student_email,
          "recipient_user_id" => student_id,
          "title" => title
        },
        details
      )
    )
  end

  defp enqueue(args), do: deliver_email(args)

  defp deliver_email(%{"type" => type, "recipient" => recipient} = args) do
    case Map.fetch(@email_types, type) do
      {:ok, template_type} ->
        UserNotifier.deliver_notification(
          recipient,
          EmailTemplates.notification(template_type, args)
        )

      :error ->
        {:error, :unsupported_email_type}
    end
  end
end
