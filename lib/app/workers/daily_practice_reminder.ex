defmodule App.Workers.DailyPracticeReminder do
  use Oban.Worker, queue: :mailers, max_attempts: 3

  import Ecto.Query
  alias App.Recitations.Assignment
  alias App.UmmahApi.Learning
  alias App.Repo
  alias App.Notifications

  @reminder_window_minutes 14

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Repo.all(
      from assignment in Assignment,
        where:
          assignment.status in [:assigned, :repeat_required] and not is_nil(assignment.due_date) and
            is_nil(assignment.reminder_sent_on),
        preload: [:student]
    )
    |> Enum.filter(&ready_for_reminder?/1)
    |> Enum.reduce([], fn assignment, failures ->
      case deliver_once(assignment) do
        :ok -> failures
        {:error, reason} -> [reason | failures]
      end
    end)
    |> case do
      [] -> :ok
      failures -> {:error, {:reminders_failed, Enum.reverse(failures)}}
    end
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
                                                                       ) +
                                                                         @reminder_window_minutes)
    else
      # Location is optional. Keep a predictable evening reminder for users who
      # have not shared coordinates, rather than silently omitting their reminder.
      _ -> now.hour == 19 and now.minute <= @reminder_window_minutes
    end
  end

  defp local_now(time_zone) do
    case DateTime.now(time_zone || "Etc/UTC", Tzdata.TimeZoneDatabase) do
      {:ok, datetime} -> datetime
      {:error, _reason} -> DateTime.utc_now()
    end
  end

  # The reminder is sent while a row-level database lock is held, then marked as
  # sent only after Gmail accepts it. This prevents duplicate emails from the
  # minute-by-minute cron schedule and lets Oban retry an unsuccessful delivery.
  defp deliver_once(assignment) do
    Repo.transaction(fn ->
      locked_assignment =
        Repo.one(
          from assignment in Assignment,
            where: assignment.id == ^assignment.id and is_nil(assignment.reminder_sent_on),
            lock: "FOR UPDATE"
        )

      if locked_assignment do
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
          {:ok, _email} ->
            Repo.update!(
              Ecto.Changeset.change(locked_assignment, reminder_sent_on: assignment.due_date)
            )

            :ok

          {:error, reason} ->
            Repo.rollback(reason)
        end
      else
        :ok
      end
    end)
    |> case do
      {:ok, :ok} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp minutes_since_midnight(%DateTime{} = datetime), do: datetime.hour * 60 + datetime.minute
  defp minutes_since_midnight(%Time{} = time), do: time.hour * 60 + time.minute
end
