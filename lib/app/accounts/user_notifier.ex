defmodule App.Accounts.UserNotifier do
  import Swoosh.Email

  alias App.Mailer
  alias App.Accounts.User
  alias App.EmailTemplates

  # Delivers the email using the application mailer.
  defp deliver(recipient, %{subject: subject, text: text, html: html}) do
    email =
      new()
      |> to(recipient)
      |> from(Application.fetch_env!(:app, :mail_from))
      |> subject(subject)
      |> text_body(text)
      |> html_body(html)

    try do
      with {:ok, _metadata} <- Mailer.deliver(email) do
        {:ok, email}
      end
    rescue
      error -> {:error, Exception.message(error)}
    catch
      kind, reason -> {:error, {kind, reason}}
    end
  end

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    deliver(user.email, EmailTemplates.auth(:update_email, user, url))
  end

  @doc """
  Deliver instructions to log in with a magic link.
  """
  def deliver_login_instructions(user, url) do
    case user do
      %User{confirmed_at: nil} -> deliver_confirmation_instructions(user, url)
      _ -> deliver_magic_link_instructions(user, url)
    end
  end

  @doc """
  Delivers a normal Tilawah lifecycle email immediately using the same mailer
  as account confirmation and sign-in messages.
  """
  def deliver_notification(recipient, template), do: deliver(recipient, template)

  defp deliver_magic_link_instructions(user, url) do
    deliver(user.email, EmailTemplates.auth(:magic_link, user, url))
  end

  defp deliver_confirmation_instructions(user, url) do
    deliver(user.email, EmailTemplates.auth(:confirmation, user, url))
  end
end
