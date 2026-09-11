defmodule App.Notifications do
  alias App.Workers.EmailDeliveryWorker

  def notify_submission(tutor_email, student_email, title) do
    enqueue(%{
      "type" => "submission",
      "recipient" => tutor_email,
      "student" => student_email,
      "title" => title
    })
  end

  def notify_feedback(student_email, title, status, feedback) do
    enqueue(%{
      "type" => "feedback",
      "recipient" => student_email,
      "title" => title,
      "status" => Atom.to_string(status),
      "feedback" => feedback || ""
    })
  end

  defp enqueue(args), do: args |> EmailDeliveryWorker.new() |> Oban.insert()
end
