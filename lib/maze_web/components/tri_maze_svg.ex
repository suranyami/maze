defmodule MazeWeb.Components.TriMazeSvg do
  @moduledoc """
  Phoenix component that renders a `Maze.TriGrid` as an SVG.

  Each cell is an equilateral triangle with base width `cell_size` and
  height `cell_size * √3/2`.  Cells alternate between upright (△) and
  inverted (▽) orientations.

  For cell {r, c} with `half_w = cell_size / 2`:
    - x_left  = c * half_w
    - x_mid   = (c + 1) * half_w
    - x_right = (c + 2) * half_w
    - y_top    = r * h
    - y_bottom = (r + 1) * h

  Upright △ vertices:  (x_left, y_bottom), (x_right, y_bottom), (x_mid, y_top)
    - west wall (left side): (x_left, y_bottom) → (x_mid, y_top)
    - east wall (right side): (x_mid, y_top) → (x_right, y_bottom)
    - south wall (base): (x_left, y_bottom) → (x_right, y_bottom)

  Inverted ▽ vertices: (x_left, y_top), (x_right, y_top), (x_mid, y_bottom)
    - west wall (left side): (x_left, y_top) → (x_mid, y_bottom)
    - east wall (right side): (x_mid, y_bottom) → (x_right, y_top)
    - north wall (base): (x_left, y_top) → (x_right, y_top)
  """

  use Phoenix.Component

  alias Maze.TriGrid

  @sqrt3 1.7320508075688772

  attr :grid, :map, required: true
  attr :cell_size, :integer, default: 20

  def render(assigns) do
    %{grid: grid, cell_size: cs} = assigns
    half_w = cs / 2
    h = cs * @sqrt3 / 2

    width = round((grid.cols + 1) * half_w)
    height = round(grid.rows * h)

    lines = compute_lines(grid, half_w, h)
    assigns = assign(assigns, lines: lines, width: width, height: height)

    ~H"""
    <svg
      width={@width}
      height={@height}
      viewBox={"0 0 #{@width} #{@height}"}
      xmlns="http://www.w3.org/2000/svg"
    >
      <rect width="100%" height="100%" fill="white" />
      <line
        :for={{x1, y1, x2, y2} <- @lines}
        x1={x1}
        y1={y1}
        x2={x2}
        y2={y2}
        stroke="black"
        stroke-width="2"
        stroke-linecap="round"
      />
    </svg>
    """
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp compute_lines(grid, half_w, h) do
    Enum.flat_map(grid.cells, fn {id, cell} ->
      {row, col} = id
      x_left = col * half_w
      x_mid = (col + 1) * half_w
      x_right = (col + 2) * half_w
      y_top = row * h
      y_bottom = (row + 1) * h

      if cell.upright do
        upright_walls(grid, id, cell, x_left, x_mid, x_right, y_top, y_bottom)
      else
        inverted_walls(grid, id, cell, x_left, x_mid, x_right, y_top, y_bottom)
      end
    end)
  end

  # Upright △: west, east, south walls
  defp upright_walls(grid, id, cell, x_left, x_mid, x_right, y_top, y_bottom) do
    west_wall =
      if is_nil(cell.west) or not TriGrid.linked?(grid, id, cell.west),
        do: [{x_left, y_bottom, x_mid, y_top}],
        else: []

    east_wall =
      if is_nil(cell.east) or not TriGrid.linked?(grid, id, cell.east),
        do: [{x_mid, y_top, x_right, y_bottom}],
        else: []

    south_wall =
      if is_nil(cell.south) or not TriGrid.linked?(grid, id, cell.south),
        do: [{x_left, y_bottom, x_right, y_bottom}],
        else: []

    west_wall ++ east_wall ++ south_wall
  end

  # Inverted ▽: west, east, north walls
  defp inverted_walls(grid, id, cell, x_left, x_mid, x_right, y_top, y_bottom) do
    west_wall =
      if is_nil(cell.west) or not TriGrid.linked?(grid, id, cell.west),
        do: [{x_left, y_top, x_mid, y_bottom}],
        else: []

    east_wall =
      if is_nil(cell.east) or not TriGrid.linked?(grid, id, cell.east),
        do: [{x_mid, y_bottom, x_right, y_top}],
        else: []

    north_wall =
      if is_nil(cell.north) or not TriGrid.linked?(grid, id, cell.north),
        do: [{x_left, y_top, x_right, y_top}],
        else: []

    west_wall ++ east_wall ++ north_wall
  end
end
