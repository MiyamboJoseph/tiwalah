# Script for populating the database. Run with:
#
#     mix run priv/repo/seeds.exs
#
# In development, this creates an administrator with the credentials below
# unless ADMIN_EMAIL and ADMIN_PASSWORD are supplied. Never use the fallback
# password outside a local development database.

alias App.Accounts
alias App.Accounts.User
alias App.Repo

admin_email = System.get_env("ADMIN_EMAIL") || "admin@tilawah.test"

admin_password =
  System.get_env("ADMIN_PASSWORD") ||
    if Mix.env() == :dev do
      "TilawahAdmin2026!"
    else
      raise "ADMIN_PASSWORD must be set before seeding an administrator outside development."
    end

admin_email = admin_email |> String.trim() |> String.downcase()

admin =
  case Repo.get_by(User, email: admin_email) do
    nil ->
      {:ok, user} =
        Accounts.register_user(%{
          email: admin_email,
          password: admin_password,
          password_confirmation: admin_password,
          role: :student,
          first_name: "Tilawah",
          last_name: "Administrator",
          gender: "prefer_not_to_say",
          location: "Platform administration",
          phone_number: "+260000000000",
          time_zone: "Africa/Lusaka",
          terms_accepted: true
        })

      user
      |> User.confirm_changeset()
      |> Repo.update!()

    user ->
      user
  end

admin
|> Ecto.Changeset.change(role: :admin)
|> Repo.update!()

if Mix.env() == :dev and System.get_env("ADMIN_PASSWORD") == nil do
  IO.puts("Seeded Tilawah admin: admin@tilawah.test / TilawahAdmin2026!")
end
