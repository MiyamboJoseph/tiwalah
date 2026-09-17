defmodule AppWeb.UserConfirmationController do
  use AppWeb, :controller

  alias App.Accounts
  alias App.Notifications

  def show(conn, %{"token" => token}) do
    case Accounts.confirm_user(token) do
      {:ok, user} ->
        Notifications.notify_welcome(user)

        conn
        |> put_flash(:info, "Your email has been confirmed. You can now sign in.")
        |> redirect(to: ~p"/users/log-in")

      {:error, :not_found} ->
        conn
        |> put_flash(
          :error,
          "That confirmation link is invalid or has expired. Request a new one below."
        )
        |> redirect(to: ~p"/users/log-in")
    end
  end
end
