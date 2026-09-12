defmodule App.Workers.AudioBackupWorker do
  use Oban.Worker, queue: :maintenance, max_attempts: 3

  alias App.Recitations.AudioStorage

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    case AudioStorage.backup_private_files() do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
