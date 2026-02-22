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
  end

  describe "regenerate event" do
    test "regenerate button produces a new maze", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Click regenerate — should not crash and SVG should still be present
      html = view |> element("button", "Regenerate") |> render_click()
      assert html =~ "<line"
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

      # rows clamped to 50, cols clamped to 5, cell_size clamped to 10
      # 50 * 10 = 500 (width would be 5*10=50)
      assert html =~ ~s(width="50")
    end
  end
end
