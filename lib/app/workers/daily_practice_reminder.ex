defmodule App.Workers.DailyPracticeReminder do
  use Oban.Worker, queue: :mailers, max_attempts: 3

  import Ecto.Query
  alias App.Recitations.Assignment
  alias App.Repo
  alias App.Workers.EmailDeliveryWorker

  @utc_offsets %{
    "Africa/Lagos" => 1,
    "Africa/Lusaka" => 2,
    "Africa/Nairobi" => 3,
    "Asia/Riyadh" => 3,
    "Asia/Karachi" => 5
  }

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Repo.all(
      from assignment in Assignment,
        where:
          assignment.status in [:assigned, :repeat_required] and not is_nil(assignment.due_date),
        preload: [:student]
    )
    |> Enum.filter(&due_tomorrow_in_student_time_zone?/1)
    |> Enum.reduce_while(:ok, fn assignment, :ok ->
      case enqueue_reminder(assignment) do
        {:ok, _job} -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp due_tomorrow_in_student_time_zone?(assignment) do
    now = local_now(assignment.student.time_zone)
    now.hour == 7 and assignment.due_date == now |> DateTime.to_date() |> Date.add(1)
  end

  defp local_now(time_zone) do
    offset = Map.get(@utc_offsets, time_zone, 0)
    DateTime.add(DateTime.utc_now(), offset * 3_600, :second)
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
