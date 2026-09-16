defmodule App.EmailDeliveryEvents do
  import Ecto.Query

  alias App.Accounts.Scope
  alias App.EmailDeliveryEvents.EmailDeliveryEvent
  alias App.Repo

  @doc """
  Records an email job as soon as it enters Oban, without overwriting a result
  that an exceptionally fast worker may have already recorded.
  """
  def record_queued(%Oban.Job{} = job), do: record(job, :queued)

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

    conflict_action =
      if status == :queued,
        do: :nothing,
        else: {:replace, [:status, :last_error, :sent_at, :updated_at]}

    case %EmailDeliveryEvent{}
         |> EmailDeliveryEvent.changeset(attrs)
         |> Repo.insert(
           on_conflict: conflict_action,
           conflict_target: :oban_job_id
         ) do
      {:ok, event} = result ->
        Phoenix.PubSub.broadcast(
          App.PubSub,
          "notifications:#{event.user_id}",
          {:email_delivery_recorded, event.id}
        )

        result

      error ->
        error
    end
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
