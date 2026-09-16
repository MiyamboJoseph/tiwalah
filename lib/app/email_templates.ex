defmodule App.EmailTemplates do
  @moduledoc "Consistent text and HTML email templates for Tilawah lifecycle events."

  def auth(:confirmation, user, url),
    do:
      message(
        "Confirm your Tilawah email address",
        greeting(user),
        "Welcome to Tilawah. Please confirm this email address to finish setting up your account and keep it secure.",
        "Confirm my account",
        url,
        "If you did not create a Tilawah account, you can safely ignore this email."
      )

  def auth(:magic_link, user, url),
    do:
      message(
        "Your secure Tilawah sign-in link",
        greeting(user),
        "Use this secure, one-time link to sign in to your Tilawah account. Do not forward this email or share the link with anyone.",
        "Sign in to Tilawah",
        url,
        "If you did not request this sign-in link, you can safely ignore this email."
      )

  def auth(:update_email, user, url),
    do:
      message(
        "Confirm your new email address",
        greeting(user),
        "Confirm this new email address to complete the change to your Tilawah account. Until you confirm it, your existing email remains on the account.",
        "Confirm new email",
        url,
        "If you did not request this change, please secure your account and contact support."
      )

  def notification(:submission, args) do
    message(
      "A recitation is ready for your review",
      "As-salāmu ʿalaykum,",
      "#{value(args, "student", "A student")} submitted “#{value(args, "title", "a recitation")}”. Listen to the recording, then approve it or request a repeat with clear, kind guidance.",
      "Review recitation",
      app_url("/tutor"),
      "You are receiving this because a student submitted a recitation in your Tilawah circle."
    )
  end

  def notification(:welcome, args) do
    {portal_path, next_step} =
      if args["role"] == "tutor" do
        {"/tutor",
         "Complete your teaching profile and wait for its verification before students can request to learn with you."}
      else
        {"/dashboard",
         "Choose a verified Qur’an teacher, send a learning request, and begin once they accept it."}
      end

    message(
      "Welcome to Tilawah",
      "As-salāmu ʿalaykum, #{value(args, "name", "")},",
      "Your Tilawah account is ready. #{next_step}",
      "Open Tilawah",
      app_url(portal_path),
      "May Allah place barakah in your learning and teaching."
    )
  end

  def notification(:feedback, args) do
    {decision, action} =
      if args["status"] == "reviewed",
        do: {"approved", "View feedback"},
        else: {"marked for another attempt", "View repeat plan"}

    message(
      "Your tutor reviewed “#{value(args, "title", "your recitation")}”",
      "As-salāmu ʿalaykum,",
      "Your recitation was #{decision}.\n\nTutor guidance:\n#{feedback_text(args)}#{repeat_plan(args)}",
      action,
      app_url("/dashboard"),
      if(args["status"] == "reviewed",
        do: "Keep practising with patience—each sincere attempt is part of your progress.",
        else:
          "Open your repeat plan for the focus āyāt, instructions, deadline, and any audio example from your tutor."
      )
    )
  end

  def notification(:reminder, args) do
    message(
      "Your recitation is due tomorrow",
      "As-salāmu ʿalaykum,",
      "Your assigned recitation, “#{value(args, "title", "your practice")}”, is due tomorrow.#{portion_details(args)} Set aside a quiet time to practise and submit your recording.",
      "Open my practice",
      app_url("/dashboard"),
      "If you need help, contact your tutor through Tilawah."
    )
  end

  def notification(:connection_request, args) do
    message(
      "New student learning request",
      "As-salāmu ʿalaykum,",
      "#{value(args, "requester", "A student")} would like to learn with you. Review their request, then accept only if you have room to guide them with care.",
      "Review request",
      app_url("/tutor"),
      "Accepting creates a private student–tutor connection. You can decline if your circle is full or the fit is not right."
    )
  end

  def notification(:tutor_invitation, args) do
    message(
      "A tutor invited you to learn",
      "As-salāmu ʿalaykum,",
      "#{value(args, "requester", "A tutor")} invited you to join their Tilawah recitation circle. Review the invitation before accepting.",
      "Review invitation",
      app_url("/dashboard"),
      "You remain in control of which tutor invitations you accept."
    )
  end

  def notification(:connection_accepted, args) do
    message(
      "Your Tilawah connection is active",
      "As-salāmu ʿalaykum,",
      "#{value(args, "counterpart", "Your tutor")} accepted your learning request. Your private learning connection is now active.",
      "Open my portal",
      app_url(args["portal_path"]),
      "Your tutor can now assign a focused portion. You will be notified when there is practice ready for you."
    )
  end

  def notification(:connection_declined, args) do
    message(
      "Tilawah connection update",
      "As-salāmu ʿalaykum,",
      "#{value(args, "counterpart", "This person")} was unable to accept the learning request at this time.",
      value(args, "action_label", "Open my portal"),
      app_url(value(args, "portal_path", "/dashboard")),
      "You can choose another available verified tutor from your Tilawah portal."
    )
  end

  def notification(:assignment, args) do
    message(
      "A new recitation has been assigned",
      "As-salāmu ʿalaykum,",
      "Your tutor assigned “#{value(args, "title", "a new recitation")}”.#{portion_details(args)} Read the assigned āyāt, practise in a quiet place, then record your best attempt when you are ready.",
      "Record recitation",
      app_url(value(args, "path", "/dashboard")),
      "Your practice page includes the assigned Arabic text, translation, and any guidance from your tutor."
    )
  end

  def notification(:tutor_verification, args) do
    {heading, body, action, path} =
      case args["status"] do
        "verified" ->
          {"Your tutor profile is verified",
           "Your credentials have been reviewed and your tutor profile is now visible to students looking for guidance.",
           "Open tutor portal", "/tutor"}

        _ ->
          {"Your tutor profile needs attention", rejection_message(args["reason"]),
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

  defp rejection_message(reason) when is_binary(reason) and reason != "" do
    "Your tutor profile was not approved at this time. Administrator guidance: #{reason}"
  end

  defp rejection_message(_reason) do
    "Your tutor profile was not approved at this time. Review your profile details and contact the Tilawah administrator if you need guidance."
  end

  defp greeting(%{first_name: first_name}) when is_binary(first_name) and first_name != "",
    do: "As-salāmu ʿalaykum, #{first_name},"

  defp greeting(_user), do: "As-salāmu ʿalaykum,"

  defp value(args, key, fallback) do
    case Map.get(args, key) do
      value when is_binary(value) and value != "" -> value
      value when is_integer(value) -> Integer.to_string(value)
      _ -> fallback
    end
  end

  defp feedback_text(args) do
    case String.trim(value(args, "feedback", "")) do
      "" -> "Your tutor has updated this recitation. Open your portal to see the next step."
      feedback -> feedback
    end
  end

  defp portion_details(args) do
    case {value(args, "surah", ""), Map.get(args, "ayah_from"), Map.get(args, "ayah_to")} do
      {surah, first, last} when surah != "" and is_integer(first) and is_integer(last) ->
        due_date =
          case formatted_date(Map.get(args, "due_date")) do
            nil -> ""
            date -> " It is due on #{date}."
          end

        " Your portion is #{surah}, āyah #{first}–#{last}.#{due_date}"

      _ ->
        ""
    end
  end

  defp repeat_plan(args) do
    if args["status"] == "repeat_required" do
      focus =
        case {Map.get(args, "repeat_ayah_from"), Map.get(args, "repeat_ayah_to")} do
          {first, last} when is_integer(first) and is_integer(last) ->
            "\n\nRepeat plan:\nFocus on āyah #{first}–#{last}."

          _ ->
            ""
        end

      instruction =
        case value(args, "repeat_instruction", "") do
          "" -> ""
          text -> "\nPractice instruction: #{text}"
        end

      deadline =
        case formatted_date(Map.get(args, "repeat_due_date")) do
          nil -> ""
          date -> "\nRevised deadline: #{date}"
        end

      audio =
        if args["has_tutor_audio"] == true,
          do: "\nAn audio example from your tutor is available on your practice page.",
          else: ""

      focus <> instruction <> deadline <> audio
    else
      ""
    end
  end

  defp formatted_date(%Date{} = date), do: Calendar.strftime(date, "%d %b %Y")
  defp formatted_date(_date), do: nil

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
    <div style="display:none;max-height:0;max-width:0;overflow:hidden;opacity:0;color:transparent">#{escaped.(subject)} — Tilawah Recitation Circle</div>
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
          <p style="margin:-12px 0 24px;color:#66756c;font-size:12px;line-height:1.5">If the button does not open, copy this link into your browser:<br><a href="#{escaped.(cta_url)}" style="color:#08745a;word-break:break-word">#{escaped.(cta_url)}</a></p>
          <p style="margin:0;padding-top:18px;border-top:1px solid #e7dfcf;color:#66756c;font-size:13px;line-height:1.6">#{escaped.(footer)}</p>
        </div>
      </div>
    </div>
    """
  end

  defp app_url(path), do: AppWeb.Endpoint.url() <> path
end
