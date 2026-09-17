defmodule AppWeb.UserLive.RegistrationTest do
  use AppWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import App.AccountsFixtures

  describe "Registration page" do
    test "renders registration page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/register")

      assert html =~ "Create your account"
      assert html =~ "Sign in"
    end

    test "redirects if already logged in", %{conn: conn} do
      result =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/users/register")
        |> follow_redirect(conn, ~p"/dashboard")

      assert {:ok, _conn} = result
    end

    test "renders errors for invalid data", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      result =
        lv
        |> element("#registration_form")
        |> render_change(user: %{"email" => "with spaces"})

      assert result =~ "Create your account"
      assert result =~ "must have the @ sign and no spaces"
    end
  end

  describe "register user" do
    test "creates account but does not log in", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      email = unique_user_email()
      form = form(lv, "#registration_form", user: valid_user_attributes(email: email))

      {:ok, _lv, html} =
        render_submit(form)
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ "Your account is ready. Please sign in with your email and password."
    end

    test "renders errors for duplicated email", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      user = user_fixture(%{email: "test@email.com"})

      result =
        lv
        |> form("#registration_form",
          user: %{"email" => user.email}
        )
        |> render_submit()

      assert result =~ "has already been taken"
    end
  end

  describe "registration navigation" do
    test "redirects to login page when the Sign in button is clicked", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      {:ok, _login_live, login_html} =
        lv
        |> element("main a", "Sign in")
        |> render_click()
        |> follow_redirect(conn, ~p"/users/log-in")

      assert login_html =~ "Welcome to Tilawah"
    end
  end

  describe "registration wizard" do
    @tag :role_sync
    test "role links select the matching account type", %{conn: conn} do
      for role <- ["student", "tutor"] do
        {:ok, lv, _html} = live(conn, ~p"/users/register?#{[role: role]}")
        assert has_element?(lv, "input[name='user[role]'][value='#{role}'][checked]")
      end
    end

    @tag :role_sync
    test "switching roles updates the URL and preserves personal details", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register?role=tutor")

      for role <- ["student", "tutor"] do
        lv
        |> form("#registration_form")
        |> render_change(
          user: %{role: role, first_name: "Amina", last_name: "Student", gender: "female"}
        )

        assert_patch(lv, ~p"/users/register?#{[role: role]}")
        assert has_element?(lv, "input[name='user[role]'][value='#{role}'][checked]")
        assert has_element?(lv, "input[name='user[first_name]'][value='Amina']")
      end
    end

    @tag :role_sync
    test "URL changes select the matching role without losing entered details", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register?role=student")
      lv |> form("#registration_form") |> render_change(user: %{first_name: "Amina"})
      render_patch(lv, ~p"/users/register?role=tutor")
      assert has_element?(lv, "input[name='user[role]'][value='tutor'][checked]")
      assert has_element?(lv, "input[name='user[first_name]'][value='Amina']")
    end

    test "moves a student from personal details to contact details", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register?role=student")

      html =
        lv
        |> form("#registration_form", %{
          "wizard_action" => "next",
          "user" => %{
            "role" => "student",
            "first_name" => "Amina",
            "last_name" => "Student",
            "gender" => "female"
          }
        })
        |> render_submit()

      assert html =~ "Step 2 of 3"
      assert html =~ "Contact details"
      assert html =~ "Your account type"
      assert html =~ "Student"
    end

    test "shows a tutor profile with the correct step title", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register?role=tutor")

      html =
        lv
        |> form("#registration_form", %{
          "wizard_action" => "next",
          "user" => %{
            "role" => "tutor",
            "first_name" => "Yusuf",
            "last_name" => "Teacher",
            "gender" => "male"
          }
        })
        |> render_submit()

      assert html =~ "Step 2 of 3"
      assert html =~ "Tutor profile"
      assert html =~ "Your teaching profile"
      assert html =~ "Qur’an teacher"
      assert html =~ "profiles are reviewed"
    end
  end
end
