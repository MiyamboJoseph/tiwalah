defmodule AppWeb.RecitationAudioController do
  use AppWeb, :controller

  alias App.Recitations
  alias App.Recitations.AudioStorage

  def show(conn, %{"id" => id}) do
    with {:ok, submission} <- Recitations.get_submission_audio(conn.assigns.current_scope, id),
         true <- AudioStorage.existing_file?(submission.audio_path) do
      conn
      |> put_resp_content_type(content_type(submission.audio_path))
      |> put_resp_header("cache-control", "private, no-store")
      |> send_file(200, AudioStorage.path_for(submission.audio_path))
    else
      _ -> send_resp(conn, 404, "Recording not found")
    end
  end

  defp content_type(path) do
    case Path.extname(path) do
      ".mp3" -> "audio/mpeg"
      ".wav" -> "audio/wav"
      ".m4a" -> "audio/mp4"
      ".ogg" -> "audio/ogg"
      _ -> "audio/webm"
    end
  end
end
