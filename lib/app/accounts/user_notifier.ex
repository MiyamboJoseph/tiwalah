defmodule App.Accounts.UserNotifier do
  import Swoosh.Email

  alias App.Mailer
  alias App.Accounts.User

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from(Application.fetch_env!(:app, :mail_from))
      |> subject(subject)
      |> text_body(body)
      |> html_body(template(subject, body))

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  defp template(subject, body) do
    subject = Phoenix.HTML.html_escape(subject) |> Phoenix.HTML.safe_to_string()
    body = Phoenix.HTML.html_escape(body) |> Phoenix.HTML.safe_to_string()

    """
    <div style="max-width:600px;margin:auto;padding:32px;font-family:Arial,sans-serif;color:#173b2d;background:#fcfaf3">
      <div style="font-size:24px;font-weight:700;color:#075a43">✦ Tilawah</div>
      <h1 style="font-size:24px;margin-top:28px">#{subject}</h1>
      <div style="white-space:pre-line;line-height:1.6">#{body}</div>
      <p style="margin-top:32px;border-top:1px solid #d9d5c8;padding-top:16px;color:#66756c;font-size:12px">Tilawah Recitation Circle</p>
    </div>
    """
  end

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    deliver(user.email, "Update email instructions", """

    ==============================

    Hi #{user.email},

    You can change your email by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
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

  defp deliver_magic_link_instructions(user, url) do
    deliver(user.email, "Log in instructions", """

    ==============================

    Hi #{user.email},

    You can log into your account by visiting the URL below:

    #{url}

    If you didn't request this email, please ignore this.

    ==============================
    """)
  end

  defp deliver_confirmation_instructions(user, url) do
    deliver(user.email, "Confirmation instructions", """

    ==============================

    Hi #{user.email},

    You can confirm your account by visiting the URL below:

    #{url}

    If you didn't create an account with us, please ignore this.

    ==============================
    """)
  end
end
