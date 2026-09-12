defmodule App.EmailDeliveryEvents do
  import Ecto.Query

  alias App.Accounts.Scope
  alias App.EmailDeliveryEvents.EmailDeliveryEvent
  alias App.Repo

  def record(%Oban.Job{id: job_id, args: args}, status, error \\ nil) do
    attrs = %{
      oban_job_id: job_id,
      user_id: Map.get(args, "recipient_user_id"),
      event_type: Map.fetch!(args, "type"),
      recipient: Map.fetch!(args, "recipient"),
      status: status,
      last_error: if(status == :failed, do: inspect(error), else: nil),
      sent_at: if(status == :sent, do: DateTime.utc_now(:second), else: nil)
    }

    %EmailDeliveryEvent{}
    |> EmailDeliveryEvent.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:status, :last_error, :sent_at, :updated_at]},
      conflict_target: :oban_job_id
    )
  end

  def recent(%Scope{user: user}, limit \\ 5) do
    Repo.all(
      from event in EmailDeliveryEvent,
        where: event.user_id == ^user.id,
        order_by: [desc: event.updated_at],
        limit: ^limit
    )
  end
end
