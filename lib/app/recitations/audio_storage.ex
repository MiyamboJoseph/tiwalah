defmodule App.Recitations.AudioStorage do
  @moduledoc false

  import Ecto.Query
  alias App.Repo
  alias App.Recitations.Submission

  @extensions ~w(.webm .mp3 .wav .m4a .ogg)

  def store(source_path, client_name) do
    extension = client_name |> Path.extname() |> String.downcase()

    with true <- extension in @extensions,
         {:ok, binary} <- File.read(source_path),
         true <- audio_binary?(binary, extension),
         {:ok, storage_key} <- copy_to_private_storage(source_path, extension) do
      {:ok, storage_key}
    else
      false -> {:error, :invalid_audio}
      {:error, _reason} -> {:error, :storage_unavailable}
    end
  end

  def path_for(storage_key) when is_binary(storage_key) do
    if String.starts_with?(storage_key, "/uploads/") do
      Path.join([:code.priv_dir(:app), "static", "uploads", Path.basename(storage_key)])
    else
      Path.join(private_directory(), Path.basename(storage_key))
    end
  end

  def existing_file?(storage_key), do: storage_key |> path_for() |> File.regular?()

  def cleanup_orphaned_files do
    active_keys =
      Repo.all(
        from submission in Submission,
          select: {submission.audio_path, submission.tutor_audio_path}
      )
      |> Enum.flat_map(fn {audio_path, tutor_audio_path} -> [audio_path, tutor_audio_path] end)
      |> Enum.reject(&is_nil/1)
      |> MapSet.new()

    with {:ok, files} <- File.ls(private_directory()) do
      Enum.each(files, fn file ->
        if not MapSet.member?(active_keys, file), do: File.rm(path_for(file))
      end)
    end

    :ok
  end

  defp copy_to_private_storage(source_path, extension) do
    storage_key = Base.url_encode64(:crypto.strong_rand_bytes(24), padding: false) <> extension
    destination = path_for(storage_key)

    with :ok <- File.mkdir_p(private_directory()), :ok <- File.cp(source_path, destination) do
      {:ok, storage_key}
    end
  end

  defp private_directory, do: Path.join([:code.priv_dir(:app), "uploads"])

  defp audio_binary?(<<0x1A, 0x45, 0xDF, 0xA3, _rest::binary>>, ".webm"), do: true
  defp audio_binary?(<<"ID3", _rest::binary>>, ".mp3"), do: true
  defp audio_binary?(<<0xFF, byte, _rest::binary>>, ".mp3") when byte in 0xE0..0xFB, do: true
  defp audio_binary?(<<"RIFF", _size::binary-size(4), "WAVE", _rest::binary>>, ".wav"), do: true
  defp audio_binary?(<<"OggS", _rest::binary>>, ".ogg"), do: true
  defp audio_binary?(<<_size::binary-size(4), "ftyp", _rest::binary>>, ".m4a"), do: true
  defp audio_binary?(_binary, _extension), do: false
end
