defmodule App.Workers.EmailDeliveryWorker do
  use Oban.Worker, queue: :mailers, max_attempts: 5

  import Swoosh.Email
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
             "tutor_verification"
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

    case Mailer.deliver(email) do
      {:ok, _} ->
        EmailDeliveryEvents.record(job, :sent)
        :ok

      {:error, reason} ->
        EmailDeliveryEvents.record(job, :failed, reason)
        {:error, reason}
    end
  end
end
