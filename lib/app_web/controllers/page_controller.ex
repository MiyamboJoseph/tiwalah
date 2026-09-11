defmodule AppWeb.PageController do
  use AppWeb, :controller

  def home(%{assigns: %{current_scope: %{user: %{role: :tutor}}}} = conn, _params),
    do: redirect(conn, to: ~p"/tutor")

  def home(%{assigns: %{current_scope: %{user: %{role: :student}}}} = conn, _params),
    do: redirect(conn, to: ~p"/dashboard")

  def home(conn, _params), do: render(conn, :home)
end
