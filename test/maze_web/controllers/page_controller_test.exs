defmodule MazeWeb.PageControllerTest do
  use MazeWeb.ConnCase

  test "GET / redirects to the LiveView maze page", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Maze Generator"
  end
end
