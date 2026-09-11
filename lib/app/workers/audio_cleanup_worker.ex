defmodule App.Workers.AudioCleanupWorker do
  use Oban.Worker, queue: :maintenance, max_attempts: 3

  alias App.Recitations.AudioStorage

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    AudioStorage.cleanup_orphaned_files()
    :ok
  end
end
