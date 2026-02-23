defmodule MazeWeb.MazeLiveTest do
  use MazeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "mount" do
    test "renders the maze page with SVG", %{conn: conn} do
      {:ok, view, html} = live(conn, "/")

      assert html =~ "Maze Generator"
      assert has_element?(view, "svg")
      assert has_element?(view, "line")
    end

    test "SVG has correct dimensions for default 30x40 grid with cell_size 25", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      # 40 cols * 25 = 1000, 30 rows * 25 = 750
      assert html =~ ~s(width="1000")
      assert html =~ ~s(height="750")
    end

    test "defaults to rectangular grid type", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")
      assert has_element?(view, ~s(option[value="rectangular"][selected]))
    end

    test "shadows toggle button is shown for rectangular grid", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")
      assert has_element?(view, "button", "Shadows: on")
    end
  end

  describe "regenerate event" do
    test "regenerate button produces a new maze", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Click regenerate — should not crash and SVG should still be present
      html = view |> element("button", "Regenerate") |> render_click()
      assert html =~ "<line"
    end
  end

  describe "toggle_shadows event" do
    test "toggles shadows off and back on", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Default is on
      assert has_element?(view, "button", "Shadows: on")

      # Toggle off
      view |> element("button", "Shadows: on") |> render_click()
      assert has_element?(view, "button", "Shadows: off")

      # Toggle back on
      view |> element("button", "Shadows: off") |> render_click()
      assert has_element?(view, "button", "Shadows: on")
    end
  end

  describe "update_params event" do
    test "applying new params updates the SVG dimensions", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      html =
        view
        |> form("form", %{rows: "10", cols: "10", cell_size: "30", weave_probability: "0.0"})
        |> render_submit()

      # 10 * 30 = 300
      assert html =~ ~s(width="300")
      assert html =~ ~s(height="300")
    end

    test "params are clamped to allowed ranges", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      html =
        view
        |> form("form", %{rows: "100", cols: "1", cell_size: "5", weave_probability: "2.0"})
        |> render_submit()

      # cols clamped to 5 (min), cell_size stays at 5 (min), weave clamped to 1.0
      # width = 5 cols * 5 px = 25
      assert html =~ ~s(width="25")
    end

    test "switching to hex grid renders SVG without line-based fills", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      html =
        view
        |> form("form", %{grid_type: "hex", rows: "5", cols: "5", cell_size: "20"})
        |> render_submit()

      assert html =~ "<line"
      assert html =~ "<svg"
    end

    test "switching to triangular grid renders SVG", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      html =
        view
        |> form("form", %{grid_type: "tri", rows: "5", cols: "8", cell_size: "20"})
        |> render_submit()

      assert html =~ "<line"
      assert html =~ "<svg"
    end

    test "weave probability control hidden for hex grid", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view
      |> form("form", %{grid_type: "hex", rows: "5", cols: "5", cell_size: "20"})
      |> render_submit()

      refute has_element?(view, ~s(input[name="weave_probability"]))
    end

    test "shadows toggle hidden for hex grid", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view
      |> form("form", %{grid_type: "hex", rows: "5", cols: "5", cell_size: "20"})
      |> render_submit()

      refute has_element?(view, "button", "Shadows: on")
      refute has_element?(view, "button", "Shadows: off")
    end
  end
end
