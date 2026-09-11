defmodule App.Notifications.Notification do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_notifications" do
    field :kind, :string
    field :title, :string
    field :body, :string
    field :path, :string
    field :read_at, :utc_datetime
    belongs_to :user, App.Accounts.User
    timestamps(type: :utc_datetime)
  end

  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [:kind, :title, :body, :path])
    |> validate_required([:kind, :title])
  end
end
