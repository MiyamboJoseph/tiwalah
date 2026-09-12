defmodule Mix.Tasks.App.PromoteAdmin do
  @shortdoc "Promotes an existing user to Tilawah administrator"
  @moduledoc """
  Promotes a registered user to the administrator role.

      mix app.promote_admin admin@example.com
  """
  use Mix.Task

  alias App.Accounts.User
  alias App.Repo

  @impl Mix.Task
  def run([email]) do
    Mix.Task.run("app.start")

    normalized_email = email |> String.trim() |> String.downcase()

    case Repo.get_by(User, email: normalized_email) do
      nil ->
        Mix.raise("No registered user was found for #{normalized_email}.")

      user ->
        {:ok, _user} = Repo.update(Ecto.Changeset.change(user, role: :admin))
        Mix.shell().info("#{normalized_email} is now a Tilawah administrator.")
    end
  end

  def run(_args), do: Mix.raise("Usage: mix app.promote_admin admin@example.com")
end
