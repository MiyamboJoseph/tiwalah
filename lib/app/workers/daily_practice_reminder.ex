defmodule App.Workers.DailyPracticeReminder do
  use Oban.Worker, queue: :mailers, max_attempts: 3

  import Ecto.Query
  alias App.Recitations.Assignment
  alias App.UmmahApi.Learning
  alias App.Repo
  alias App.Notifications

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
    |> Enum.filter(&ready_for_reminder?/1)
    |> Enum.reduce_while(:ok, fn assignment, :ok ->
      case Notifications.notify_reminder(
             assignment.student.email,
             assignment.student_id,
             assignment.title,
             %{
               "surah" => assignment.surah_name,
               "ayah_from" => assignment.ayah_from,
               "ayah_to" => assignment.ayah_to,
               "due_date" => assignment.due_date
             }
           ) do
        {:ok, _email} -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp ready_for_reminder?(assignment) do
    now = local_now(assignment.student.time_zone)
    due_tomorrow? = assignment.due_date == now |> DateTime.to_date() |> Date.add(1)

    due_tomorrow? and after_maghrib_or_fallback?(assignment.student, now)
  end

  defp after_maghrib_or_fallback?(student, now) do
    with latitude when is_number(latitude) <- student.latitude,
         longitude when is_number(longitude) <- student.longitude,
         {:ok, maghrib} <-
           Learning.maghrib_time(latitude, longitude, student.time_zone, DateTime.to_date(now)) do
      minutes_since_midnight(now) in minutes_since_midnight(maghrib)..(minutes_since_midnight(
                                                                         maghrib
                                                                       ) + 14)
    else
      _ -> now.hour == 7 and now.minute < 15
    end
  end

  defp local_now(time_zone) do
    offset = Map.get(@utc_offsets, time_zone, 0)
    DateTime.add(DateTime.utc_now(), offset * 3_600, :second)
  end

  defp minutes_since_midnight(%DateTime{} = datetime), do: datetime.hour * 60 + datetime.minute
  defp minutes_since_midnight(%Time{} = time), do: time.hour * 60 + time.minute
end
