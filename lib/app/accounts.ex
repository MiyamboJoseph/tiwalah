defmodule App.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias App.Repo
  alias App.Notifications

  alias App.Accounts.{AdminAuditEvent, Scope, User, UserToken, UserNotifier}

  ## Database getters

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: normalize_email(email))
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: normalize_email(email))
    if User.valid_password?(user, password) and active?(user), do: user
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  ## User registration

  @doc """
  Registers a user.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> User.password_changeset(attrs)
    |> Repo.insert()
  end

  def change_user_registration(user, attrs \\ %{}, opts \\ []) do
    User.registration_changeset(user, attrs, opts)
  end

  def change_user_practice_location(user, attrs \\ %{}) do
    User.practice_location_changeset(user, attrs)
  end

  def update_user_practice_location(user, attrs) do
    user
    |> User.practice_location_changeset(attrs)
    |> Repo.update()
  end

  def clear_user_practice_location(user) do
    user
    |> Ecto.Changeset.change(latitude: nil, longitude: nil)
    |> Repo.update()
  end

  @doc "Marks a tutor profile after a manual credential review by trusted staff."
  def set_tutor_verification(%User{role: :tutor} = user, status)
      when status in [:pending, :verified, :rejected] do
    changes = %{tutor_verification_status: status}

    changes =
      if status == :verified,
        do: Map.put(changes, :tutor_verified_at, DateTime.utc_now(:second)),
        else: Map.put(changes, :tutor_verified_at, nil)

    user
    |> Ecto.Changeset.change(changes)
    |> Repo.update()
  end

  @doc "Lists tutor profiles for a trusted administrator to review."
  def list_tutors_for_verification(%Scope{user: %User{role: :admin}}) do
    Repo.all(tutors_for_verification_query())
  end

  def paginate_tutors_for_verification(%Scope{user: %User{role: :admin}}, page, per_page \\ 12) do
    paginate_query(
      from(user in tutors_for_verification_query(),
        where: user.tutor_verification_status == :pending
      ),
      page,
      per_page
    )
  end

  @doc "Records an administrator's decision about a tutor profile."
  def review_tutor(scope, tutor_id, status, reason \\ nil)

  def review_tutor(
        %Scope{user: %User{id: admin_id, role: :admin}} = scope,
        tutor_id,
        status,
        reason
      )
      when status in [:verified, :rejected] do
    reason = normalize_optional_text(reason)

    if status == :rejected and is_nil(reason) do
      {:error, :rejection_reason_required}
    else
      review_tutor_with_reason(scope, admin_id, tutor_id, status, reason)
    end
  end

  defp review_tutor_with_reason(_scope, admin_id, tutor_id, status, reason) do
    case Repo.get_by(User, id: tutor_id, role: :tutor) do
      nil ->
        {:error, :not_found}

      tutor ->
        changes = %{
          tutor_verification_status: status,
          tutor_verified_at: if(status == :verified, do: DateTime.utc_now(:second), else: nil),
          tutor_verified_by_id: admin_id,
          tutor_verification_reason: if(status == :rejected, do: reason, else: nil)
        }

        case Repo.update(Ecto.Changeset.change(tutor, changes)) do
          {:ok, updated_tutor} ->
            record_admin_event(admin_id, updated_tutor.id, "tutor_#{status}", %{
              "reason" => reason
            })

            Notifications.notify_tutor_verification(
              updated_tutor.email,
              updated_tutor.id,
              status,
              reason
            )

            {:ok, updated_tutor}

          error ->
            error
        end
    end
  end

  @doc "Lists users for an administrator, with bounded server-side filters."
  def admin_list_users(%Scope{user: %User{role: :admin}}, filters \\ %{}) do
    filters
    |> admin_users_query()
    |> Repo.all()
  end

  def admin_paginate_users(%Scope{user: %User{role: :admin}}, filters, page, per_page \\ 20) do
    filters
    |> admin_users_query()
    |> paginate_query(page, per_page)
  end

  defp admin_users_query(filters) do
    search = filters |> Map.get("search", "") |> String.trim()
    role = Map.get(filters, "role", "all")
    account_status = Map.get(filters, "account_status", "all")

    query = from user in User, order_by: [desc: user.inserted_at]

    query =
      if search == "" do
        query
      else
        term = "%#{search}%"

        from user in query,
          where:
            ilike(user.email, ^term) or
              ilike(fragment("concat_ws(' ', ?, ?)", user.first_name, user.last_name), ^term)
      end

    query =
      if role in ["student", "tutor", "admin"],
        do: from(user in query, where: user.role == ^role),
        else: query

    query =
      if account_status in ["active", "suspended"],
        do: from(user in query, where: user.account_status == ^account_status),
        else: query

    query
  end

  @doc "Suspends or restores a non-admin account; the action is retained in the audit log."
  def set_account_status(%Scope{user: %User{id: admin_id, role: :admin}}, user_id, status)
      when status in [:active, :suspended] do
    with {:ok, target_id} <- Ecto.Type.cast(:id, user_id),
         %User{} = user <- Repo.get(User, target_id),
         true <- user.role != :admin,
         true <- user.id != admin_id,
         {:ok, updated} <- Repo.update(Ecto.Changeset.change(user, account_status: status)) do
      record_admin_event(admin_id, updated.id, "account_#{status}", %{})
      {:ok, updated}
    else
      false -> {:error, :protected_account}
      nil -> {:error, :not_found}
      {:error, _changeset} = error -> error
      :error -> {:error, :not_found}
    end
  end

  def admin_list_audit_events(%Scope{user: %User{role: :admin}}, limit \\ 12) do
    Repo.all(
      from event in AdminAuditEvent,
        order_by: [desc: event.inserted_at],
        limit: ^min(max(limit, 1), 50),
        preload: [:actor, :target_user]
    )
  end

  def record_admin_event(actor_id, target_user_id, action, metadata) do
    %AdminAuditEvent{
      actor_id: actor_id,
      target_user_id: target_user_id,
      action: action,
      metadata: metadata
    }
    |> Repo.insert()
  end

  defp normalize_optional_text(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      text -> text
    end
  end

  defp normalize_optional_text(_value), do: nil

  defp tutors_for_verification_query do
    from user in User,
      where: user.role == :tutor,
      order_by: [asc: user.tutor_verification_status, desc: user.inserted_at]
  end

  defp paginate_query(query, page, per_page) do
    per_page = min(max(per_page, 1), 50)
    total_entries = Repo.aggregate(query, :count, :id)
    total_pages = max(1, div(total_entries + per_page - 1, per_page))
    page = page |> normalize_page() |> min(total_pages)

    %{
      entries: query |> limit(^per_page) |> offset(^(per_page * (page - 1))) |> Repo.all(),
      page: page,
      per_page: per_page,
      total_entries: total_entries,
      total_pages: total_pages
    }
  end

  defp normalize_page(page) when is_integer(page), do: max(page, 1)

  defp normalize_page(page) when is_binary(page) do
    case Integer.parse(page) do
      {number, ""} -> max(number, 1)
      _ -> 1
    end
  end

  defp normalize_page(_page), do: 1

  def active?(%User{account_status: :active}), do: true
  def active?(_user), do: false

  defp normalize_email(email), do: email |> String.trim() |> String.downcase()

  ## Settings

  @doc """
  Checks whether the user is in sudo mode.

  The user is in sudo mode when the last authentication was done no further
  than 20 minutes ago. The limit can be given as second argument in minutes.
  """
  def sudo_mode?(user, minutes \\ -20)

  def sudo_mode?(%User{authenticated_at: ts}, minutes) when is_struct(ts, DateTime) do
    DateTime.after?(ts, DateTime.utc_now() |> DateTime.add(minutes, :minute))
  end

  def sudo_mode?(_user, _minutes), do: false

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.

  See `App.Accounts.User.email_changeset/3` for a list of supported options.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_email(user, attrs \\ %{}, opts \\ []) do
    User.email_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.
  """
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    Repo.transact(fn ->
      with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
           %UserToken{sent_to: email} <- Repo.one(query),
           {:ok, user} <- Repo.update(User.email_changeset(user, %{email: email})),
           {_count, _result} <-
             Repo.delete_all(from(UserToken, where: [user_id: ^user.id, context: ^context])) do
        {:ok, user}
      else
        _ -> {:error, :transaction_aborted}
      end
    end)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  See `App.Accounts.User.password_changeset/3` for a list of supported options.

  ## Examples

      iex> change_user_password(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_password(user, attrs \\ %{}, opts \\ []) do
    User.password_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user password.

  Returns a tuple with the updated user, as well as a list of expired tokens.

  ## Examples

      iex> update_user_password(user, %{password: ...})
      {:ok, {%User{}, [...]}}

      iex> update_user_password(user, %{password: "too short"})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_password(user, attrs) do
    user
    |> User.password_changeset(attrs)
    |> update_user_and_delete_all_tokens()
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.

  If the token is valid `{user, token_inserted_at}` is returned, otherwise `nil` is returned.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Gets the user with the given magic link token.
  """
  def get_user_by_magic_link_token(token) do
    with {:ok, query} <- UserToken.verify_magic_link_token_query(token),
         {user, _token} <- Repo.one(query),
         true <- active?(user) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Logs the user in by magic link.

  There are three cases to consider:

  1. The user has already confirmed their email. They are logged in
     and the magic link is expired.

  2. The user has not confirmed their email and no password is set.
     In this case, the user gets confirmed, logged in, and all tokens -
     including session ones - are expired. In theory, no other tokens
     exist but we delete all of them for best security practices.

  3. The user has not confirmed their email but a password is set.
     This cannot happen in the default implementation but may be the
     source of security pitfalls. See the "Mixing magic link and password registration" section of
     `mix help phx.gen.auth`.
  """
  def login_user_by_magic_link(token) do
    {:ok, query} = UserToken.verify_magic_link_token_query(token)

    case Repo.one(query) do
      {%User{} = user, _token} when user.account_status != :active ->
        {:error, :not_found}

      # Prevent session fixation attacks by disallowing magic links for unconfirmed users with password
      {%User{confirmed_at: nil, hashed_password: hash}, _token} when not is_nil(hash) ->
        raise """
        magic link log in is not allowed for unconfirmed users with a password set!

        This cannot happen with the default implementation, which indicates that you
        might have adapted the code to a different use case. Please make sure to read the
        "Mixing magic link and password registration" section of `mix help phx.gen.auth`.
        """

      {%User{confirmed_at: nil} = user, _token} ->
        user
        |> User.confirm_changeset()
        |> update_user_and_delete_all_tokens()

      {user, token} ->
        Repo.delete!(token)
        {:ok, {user, []}}

      nil ->
        {:error, :not_found}
    end
  end

  @doc ~S"""
  Delivers the update email instructions to the given user.

  ## Examples

      iex> deliver_user_update_email_instructions(user, current_email, &url(~p"/users/settings/confirm-email/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  @doc """
  Delivers the magic link login instructions to the given user.
  """
  def deliver_login_instructions(%User{} = user, magic_link_url_fun)
      when is_function(magic_link_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "login")
    Repo.insert!(user_token)
    UserNotifier.deliver_login_instructions(user, magic_link_url_fun.(encoded_token))
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(from(UserToken, where: [token: ^token, context: "session"]))
    :ok
  end

  ## Token helper

  defp update_user_and_delete_all_tokens(changeset) do
    Repo.transact(fn ->
      with {:ok, user} <- Repo.update(changeset) do
        tokens_to_expire = Repo.all_by(UserToken, user_id: user.id)

        Repo.delete_all(from(t in UserToken, where: t.id in ^Enum.map(tokens_to_expire, & &1.id)))

        {:ok, {user, tokens_to_expire}}
      end
    end)
  end
end
