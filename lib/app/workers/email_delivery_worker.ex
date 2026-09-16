defmodule App.Workers.EmailDeliveryWorker do
  use Oban.Worker, queue: :mailers, max_attempts: 5

  import Swoosh.Email
  require Logger
  alias App.EmailTemplates
  alias App.EmailDeliveryEvents
  alias App.Mailer

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"type" => "submission"} = args} = job) do
    deliver(job, args, args["recipient"], EmailTemplates.notification(:submission, args))
  end

  def perform(%Oban.Job{args: %{"type" => "feedback"} = args} = job) do
    deliver(job, args, args["recipient"], EmailTemplates.notification(:feedback, args))
  end

  def perform(%Oban.Job{args: %{"type" => "reminder"} = args} = job) do
    deliver(job, args, args["recipient"], EmailTemplates.notification(:reminder, args))
  end

  def perform(%Oban.Job{args: %{"type" => type} = args} = job)
      when type in [
             "connection_request",
             "tutor_invitation",
             "connection_accepted",
             "connection_declined",
             "assignment",
             "tutor_verification",
             "welcome"
           ] do
    deliver(
      job,
      args,
      args["recipient"],
      EmailTemplates.notification(String.to_existing_atom(type), args)
    )
  end

  defp deliver(job, _args, recipient, %{subject: subject, text: text, html: html}) do
    email =
      new()
      |> to(recipient)
      |> from(Application.fetch_env!(:app, :mail_from))
      |> subject(subject)
      |> text_body(text)
      |> html_body(html)

    try do
      case Mailer.deliver(email) do
        {:ok, _} ->
          status = delivery_status()

          Logger.info(
            "Tilawah email job #{job.id} accepted by #{delivery_transport_label(status)} for #{recipient}"
          )

          EmailDeliveryEvents.record(job, status)
          :ok

        {:error, reason} ->
          record_failure(job, recipient, reason)
      end
    rescue
      error ->
        record_failure(job, recipient, Exception.message(error))
    catch
      kind, reason ->
        record_failure(job, recipient, {kind, reason})
    end
  end

  defp record_failure(job, recipient, reason) do
    Logger.error("Tilawah email job #{job.id} failed for #{recipient}: #{inspect(reason)}")
    EmailDeliveryEvents.record(job, :failed, reason)
    {:error, reason}
  end

  defp delivery_status do
    case Application.get_env(:app, App.Mailer, []) |> Keyword.get(:adapter) do
      Swoosh.Adapters.Local -> :local
      _ -> :sent
    end
  end

  defp delivery_transport_label(:local), do: "the local development mailbox (not Gmail)"
  defp delivery_transport_label(:sent), do: "the configured SMTP relay"
end
