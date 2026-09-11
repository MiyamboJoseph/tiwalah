defmodule App.Workers.DailyPracticeReminder do
  use Oban.Worker, queue: :mailers, max_attempts: 3

  import Ecto.Query
  alias App.Recitations.Assignment
  alias App.Repo
  alias App.Workers.EmailDeliveryWorker

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    tomorrow = Date.add(Date.utc_today(), 1)

    Repo.all(
      from assignment in Assignment,
        where:
          assignment.due_date == ^tomorrow and assignment.status in [:assigned, :repeat_required],
        preload: [:student]
    )
    |> Enum.reduce_while(:ok, fn assignment, :ok ->
      case enqueue_reminder(assignment) do
        {:ok, _job} -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp enqueue_reminder(assignment) do
    %{
      "type" => "reminder",
      "recipient" => assignment.student.email,
      "title" => assignment.title
    }
    |> EmailDeliveryWorker.new(unique: [period: 86_400, fields: [:worker, :args]])
    |> Oban.insert()
  end
end
