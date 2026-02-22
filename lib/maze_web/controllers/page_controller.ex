defmodule MazeWeb.PageController do
  use MazeWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
