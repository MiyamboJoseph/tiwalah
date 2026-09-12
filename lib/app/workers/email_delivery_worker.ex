defmodule App.Workers.EmailDeliveryWorker do
  use Oban.Worker, queue: :mailers, max_attempts: 5

  import Swoosh.Email
  alias App.EmailDeliveryEvents
  alias App.Mailer

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"type" => "submission"} = args} = job) do
    deliver(
      job,
      args,
      args["recipient"],
      "New recitation awaiting your review",
      "#{args["student"]} submitted #{args["title"]}. Open Tilawah to listen and give feedback."
    )
  end

  def perform(%Oban.Job{args: %{"type" => "feedback"} = args} = job) do
    decision = if args["status"] == "reviewed", do: "approved", else: "marked for another attempt"

    deliver(
      job,
      args,
      args["recipient"],
      "Your tutor reviewed #{args["title"]}",
      "Your recitation was #{decision}.\n\nTutor feedback:\n#{args["feedback"]}"
    )
  end

  def perform(%Oban.Job{args: %{"type" => "reminder"} = args} = job) do
    deliver(
      job,
      args,
      args["recipient"],
      "Your recitation is due tomorrow",
      "Your assigned recitation, #{args["title"]}, is due tomorrow. Set aside a quiet time to practise and submit it."
    )
  end

  defp deliver(job, _args, recipient, subject, text) do
    email =
      new()
      |> to(recipient)
      |> from(Application.fetch_env!(:app, :mail_from))
      |> subject(subject)
      |> text_body(text)
      |> html_body(html(subject, text))

    case Mailer.deliver(email) do
      {:ok, _} ->
        EmailDeliveryEvents.record(job, :sent)
        :ok

      {:error, reason} ->
        EmailDeliveryEvents.record(job, :failed, reason)
        {:error, reason}
    end
  end

  defp html(subject, text) do
    subject = Phoenix.HTML.html_escape(subject) |> Phoenix.HTML.safe_to_string()
    text = Phoenix.HTML.html_escape(text) |> Phoenix.HTML.safe_to_string()

    "<div style=\"max-width:600px;margin:auto;padding:32px;font-family:Arial,sans-serif;color:#173b2d;background:#fcfaf3\"><div style=\"font-size:24px;font-weight:bold;color:#075a43\">✦ Tilawah</div><h1>#{subject}</h1><p style=\"white-space:pre-line;line-height:1.6\">#{text}</p></div>"
  end
end
