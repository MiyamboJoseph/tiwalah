defmodule App.EmailDeliveryEvents.EmailDeliveryEvent do
  use Ecto.Schema
  import Ecto.Changeset

  schema "email_delivery_events" do
    field :oban_job_id, :integer
    field :event_type, :string
    field :recipient, :string
    field :status, Ecto.Enum, values: [:sent, :failed]
    field :last_error, :string
    field :sent_at, :utc_datetime
    belongs_to :user, App.Accounts.User
    timestamps(type: :utc_datetime)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :oban_job_id,
      :user_id,
      :event_type,
      :recipient,
      :status,
      :last_error,
      :sent_at
    ])
    |> validate_required([:oban_job_id, :event_type, :recipient, :status])
    |> validate_inclusion(:status, [:sent, :failed])
    |> unique_constraint(:oban_job_id)
  end
end
