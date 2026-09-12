defmodule App.EmailTemplates do
  @moduledoc "Consistent text and HTML email templates for Tilawah lifecycle events."

  def auth(:confirmation, user, url),
    do:
      message(
        "Confirm your Tilawah account",
        greeting(user),
        "Welcome to Tilawah. Confirm your email address to activate your account and begin your recitation journey.",
        "Confirm my account",
        url,
        "If you did not create this account, you can safely ignore this email."
      )

  def auth(:magic_link, user, url),
    do:
      message(
        "Your secure Tilawah sign-in link",
        greeting(user),
        "Use this secure link to sign in to Tilawah. It is for one-time use only.",
        "Sign in to Tilawah",
        url,
        "If you did not request this sign-in link, you can safely ignore this email."
      )

  def auth(:update_email, user, url),
    do:
      message(
        "Confirm your new email address",
        greeting(user),
        "Confirm this new email address to complete the change on your Tilawah account.",
        "Confirm new email",
        url,
        "If you did not request this change, please secure your account and contact support."
      )

  def notification(:submission, args) do
    message(
      "A recitation is ready for your review",
      "As-salāmu ʿalaykum,",
      "#{args["student"]} submitted “#{args["title"]}”. Listen carefully and share clear, kind guidance.",
      "Review recitation",
      app_url("/tutor"),
      "You are receiving this because a student submitted a recitation in your Tilawah circle."
    )
  end

  def notification(:feedback, args) do
    {decision, action} =
      if args["status"] == "reviewed",
        do: {"approved", "View feedback"},
        else: {"marked for another attempt", "View repeat plan"}

    message(
      "Your tutor reviewed “#{args["title"]}”",
      "As-salāmu ʿalaykum,",
      "Your recitation was #{decision}.\n\nTutor guidance:\n#{args["feedback"]}",
      action,
      app_url("/dashboard"),
      "Keep practising with patience—each sincere attempt is part of your progress."
    )
  end

  def notification(:reminder, args) do
    message(
      "Your recitation is due tomorrow",
      "As-salāmu ʿalaykum,",
      "Your assigned recitation, “#{args["title"]}”, is due tomorrow. Set aside a quiet time to practise and submit it.",
      "Open my practice",
      app_url("/dashboard"),
      "If you need help, contact your tutor through Tilawah."
    )
  end

  def notification(:connection_request, args) do
    message(
      "New student learning request",
      "As-salāmu ʿalaykum,",
      "#{args["requester"]} would like to join your recitation circle. Review the request before accepting.",
      "Review request",
      app_url("/tutor"),
      "Only accept students you are able to guide with care."
    )
  end

  def notification(:tutor_invitation, args) do
    message(
      "A tutor invited you to learn",
      "As-salāmu ʿalaykum,",
      "#{args["requester"]} invited you to join their Tilawah recitation circle. Review the invitation before accepting.",
      "Review invitation",
      app_url("/dashboard"),
      "You remain in control of which tutor invitations you accept."
    )
  end

  def notification(:connection_accepted, args) do
    message(
      "Your Tilawah connection is active",
      "As-salāmu ʿalaykum,",
      "#{args["counterpart"]} accepted your learning request. You can now begin your recitation journey together.",
      "Open my portal",
      app_url(args["portal_path"]),
      "Your tutor will assign a focused portion when ready."
    )
  end

  def notification(:connection_declined, args) do
    message(
      "Tilawah connection update",
      "As-salāmu ʿalaykum,",
      "#{args["counterpart"]} was unable to accept the learning request at this time.",
      args["action_label"],
      app_url(args["portal_path"]),
      "You may continue your recitation journey by reviewing the available options in Tilawah."
    )
  end

  def notification(:assignment, args) do
    message(
      "A new recitation has been assigned",
      "As-salāmu ʿalaykum,",
      "Your tutor assigned “#{args["title"]}”. Read the assigned āyāt, then record your best attempt when you are ready.",
      "Record recitation",
      app_url(args["path"]),
      "A careful, sincere attempt is the best place to begin."
    )
  end

  def notification(:tutor_verification, args) do
    {heading, body, action, path} =
      case args["status"] do
        "verified" ->
          {"Your tutor profile is verified",
           "Your credentials have been reviewed and your tutor profile is now visible to students.",
           "Open tutor portal", "/tutor"}

        _ ->
          {"Your tutor profile needs attention",
           "Your tutor profile was not approved yet. Review your profile details and contact the Tilawah administrator for guidance.",
           "Open tutor portal", "/tutor"}
      end

    message(
      heading,
      "As-salāmu ʿalaykum,",
      body,
      action,
      app_url(path),
      "Thank you for serving Qur’an students with care."
    )
  end

  defp greeting(%{first_name: first_name}) when is_binary(first_name) and first_name != "",
    do: "As-salāmu ʿalaykum, #{first_name},"

  defp greeting(_user), do: "As-salāmu ʿalaykum,"

  defp message(subject, greeting, body, cta_label, cta_url, footer) do
    %{
      subject: subject,
      text:
        "#{greeting}\n\n#{body}\n\n#{cta_label}:\n#{cta_url}\n\n#{footer}\n\nTilawah Recitation Circle",
      html: html(subject, greeting, body, cta_label, cta_url, footer)
    }
  end

  defp html(subject, greeting, body, cta_label, cta_url, footer) do
    escaped_body =
      body
      |> Phoenix.HTML.html_escape()
      |> Phoenix.HTML.safe_to_string()
      |> String.replace("\n", "<br>")

    escaped = fn value -> value |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string() end

    """
    <div style="margin:0;padding:32px 16px;background:#f7f4ec;color:#173b2d;font-family:Arial,sans-serif">
      <div style="max-width:600px;margin:0 auto;background:#ffffff;border:1px solid #e7dfcf;border-radius:18px;overflow:hidden">
        <div style="padding:24px 32px;background:#043b2d;color:#fff8dc">
          <div style="font-size:22px;font-weight:700">✦ Tilawah</div>
          <div style="margin-top:4px;font-size:11px;font-weight:700;letter-spacing:1.8px;text-transform:uppercase;color:#f6c453">Recitation Circle</div>
        </div>
        <div style="padding:32px">
          <h1 style="margin:0 0 18px;font-size:25px;line-height:1.25;color:#063d2f">#{escaped.(subject)}</h1>
          <p style="margin:0 0 16px;line-height:1.6">#{escaped.(greeting)}</p>
          <p style="margin:0;line-height:1.7">#{escaped_body}</p>
          <p style="margin:28px 0"><a href="#{escaped.(cta_url)}" style="display:inline-block;padding:12px 18px;border-radius:8px;background:#08745a;color:#ffffff;font-weight:700;text-decoration:none">#{escaped.(cta_label)}</a></p>
          <p style="margin:0;padding-top:18px;border-top:1px solid #e7dfcf;color:#66756c;font-size:13px;line-height:1.6">#{escaped.(footer)}</p>
        </div>
      </div>
    </div>
    """
  end

  defp app_url(path), do: AppWeb.Endpoint.url() <> path
end
