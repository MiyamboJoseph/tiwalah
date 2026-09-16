defmodule App.Accounts.AdminAuditEvent do
  use Ecto.Schema

  schema "admin_audit_events" do
    field :action, :string
    field :metadata, :map, default: %{}

    belongs_to :actor, App.Accounts.User
    belongs_to :target_user, App.Accounts.User

    timestamps(type: :utc_datetime, updated_at: false)
  end
end
