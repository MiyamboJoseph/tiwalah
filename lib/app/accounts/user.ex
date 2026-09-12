defmodule App.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :role, Ecto.Enum, values: [:student, :tutor], default: :student
    field :first_name, :string
    field :last_name, :string
    field :gender, :string
    field :location, :string
    field :phone_number, :string
    field :time_zone, :string, default: "Africa/Lusaka"
    field :terms_accepted_at, :utc_datetime
    field :terms_accepted, :boolean, virtual: true, default: false
    field :tutor_qualification, :string
    field :tutor_experience_years, :integer
    field :tutor_languages, :string
    field :tutor_teaching_format, :string
    field :tutor_availability, :string
    field :tutor_bio, :string

    field :tutor_verification_status, Ecto.Enum,
      values: [:not_applicable, :pending, :verified, :rejected],
      default: :not_applicable

    field :tutor_verified_at, :utc_datetime
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :confirmed_at, :utc_datetime
    field :authenticated_at, :utc_datetime, virtual: true

    timestamps(type: :utc_datetime)
  end

  @doc """
  A user changeset for registering or changing the email.

  It requires the email to change otherwise an error is added.

  ## Options

    * `:validate_unique` - Set to false if you don't want to validate the
      uniqueness of the email, useful when displaying live validations.
      Defaults to `true`.
  """
  def email_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email])
    |> validate_email(opts)
  end

  @doc "A changeset for a new account, including the chosen portal role."
  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [
      :email,
      :role,
      :first_name,
      :last_name,
      :gender,
      :location,
      :phone_number,
      :time_zone,
      :terms_accepted,
      :tutor_qualification,
      :tutor_experience_years,
      :tutor_languages,
      :tutor_teaching_format,
      :tutor_availability,
      :tutor_bio
    ])
    |> validate_email(opts)
    |> validate_required([:role, :first_name, :last_name, :gender, :location, :phone_number])
    |> validate_inclusion(:gender, ["female", "male", "prefer_not_to_say"])
    |> validate_length(:first_name, min: 2, max: 80)
    |> validate_length(:last_name, min: 2, max: 80)
    |> validate_length(:location, min: 2, max: 120)
    |> validate_format(:phone_number, ~r/^\+?[0-9()\-\s]{7,20}$/,
      message: "must be a valid phone number"
    )
    |> validate_required([:time_zone])
    |> validate_acceptance(:terms_accepted, message: "must be accepted to create an account")
    |> validate_tutor_profile()
    |> set_tutor_verification_status()
    |> record_terms_acceptance()
  end

  defp validate_tutor_profile(changeset) do
    if get_field(changeset, :role) == :tutor do
      changeset
      |> validate_required([
        :tutor_qualification,
        :tutor_languages,
        :tutor_teaching_format,
        :tutor_availability
      ])
      |> validate_inclusion(:tutor_teaching_format, ["online", "in_person", "both"])
      |> validate_number(:tutor_experience_years,
        greater_than_or_equal_to: 0,
        less_than_or_equal_to: 80
      )
      |> validate_length(:tutor_qualification, max: 240)
      |> validate_length(:tutor_languages, max: 240)
      |> validate_length(:tutor_availability, max: 500)
      |> validate_length(:tutor_bio, max: 2_000)
    else
      changeset
    end
  end

  defp record_terms_acceptance(changeset) do
    if get_field(changeset, :terms_accepted) do
      put_change(changeset, :terms_accepted_at, DateTime.utc_now(:second))
    else
      changeset
    end
  end

  defp set_tutor_verification_status(changeset) do
    if get_field(changeset, :role) == :tutor do
      put_change(changeset, :tutor_verification_status, :pending)
    else
      changeset
    end
  end

  defp validate_email(changeset, opts) do
    changeset =
      changeset
      |> validate_required([:email])
      |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
        message: "must have the @ sign and no spaces"
      )
      |> validate_length(:email, max: 160)

    if Keyword.get(opts, :validate_unique, true) do
      changeset
      |> unsafe_validate_unique(:email, App.Repo)
      |> unique_constraint(:email)
      |> validate_email_changed()
    else
      changeset
    end
  end

  defp validate_email_changed(changeset) do
    if get_field(changeset, :email) && get_change(changeset, :email) == nil do
      add_error(changeset, :email, "did not change")
    else
      changeset
    end
  end

  @doc """
  A user changeset for changing the password.

  It is important to validate the length of the password, as long passwords may
  be very expensive to hash for certain algorithms.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.
  """
  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 8, max: 72)
    # Examples of additional password validation:
    # |> validate_format(:password, ~r/[a-z]/, message: "at least one lower case character")
    # |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
    # |> validate_format(:password, ~r/[!?@#$%^&*_0-9]/, message: "at least one digit or punctuation character")
    |> maybe_hash_password(opts)
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      # Hashing could be done with `Ecto.Changeset.prepare_changes/2`, but that
      # would keep the database transaction open longer and hurt performance.
      |> put_change(:hashed_password, Pbkdf2.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  @doc """
  Confirms the account by setting `confirmed_at`.
  """
  def confirm_changeset(user) do
    now = DateTime.utc_now(:second)
    change(user, confirmed_at: now)
  end

  @doc """
  Verifies the password.

  If there is no user or the user doesn't have a password, we call
  `Pbkdf2.no_user_verify/0` to avoid timing attacks.
  """
  def valid_password?(%App.Accounts.User{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Pbkdf2.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Pbkdf2.no_user_verify()
    false
  end
end
