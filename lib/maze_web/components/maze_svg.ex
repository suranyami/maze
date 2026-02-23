defmodule MazeWeb.Components.MazeSvg do
  @moduledoc """
  Phoenix component that renders a `Maze.Grid` as an SVG using wall lines.

  Rendering follows the inset approach from "Mazes for Programmers" (Buck, 2015).
  Each cell is divided into a 3×3 region via four inset coordinates:

      x1  x2      x3  x4
  y1  +---+-------+---+
      |   |   N   |   |
  y2  +---+---+---+---+
      | W |       | E |
  y3  +---+---+---+---+
      |   |   S   |   |
  y4  +---+-------+---+

  **Fills (white rectangles):** rendered first (bottom layer)
    - Centre region `[x2,x3]×[y2,y3]` — always white
    - Each directional strip (N/S/E/W) — white when linked in that direction
    - Corner regions are never filled, so the page background shows through

  **Lines (black):** rendered on top of fills
    - Over-cell: linked direction → two corridor-wall segments; unlinked → inner wall
    - Crossing (under-cell): over-corridor full-span lines + under-tunnel entry caps

  No explicit outer border or background rect; non-corridor areas are transparent.
  """

  use Phoenix.Component

  alias Maze.Grid

  # Default inset as a fraction of cell_size — matches the book's default of 0.1.
  @inset_ratio 0.1

  @doc """
  Render the maze SVG.

  Assigns:
    - `grid`      — `Maze.Grid.t()`
    - `cell_size` — integer pixels per cell (default: 25)
  """
  attr :grid, :map, required: true
  attr :cell_size, :integer, default: 25
  attr :show_shadows, :boolean, default: true

  def render(assigns) do
    %{grid: grid, cell_size: cs} = assigns
    inset = cs * @inset_ratio
    fills = compute_fills(grid, cs, inset)
    shadows = if assigns.show_shadows, do: compute_shadows(grid, cs, inset), else: []
    lines = compute_lines(grid, cs, inset)
    width = grid.cols * cs
    height = grid.rows * cs

    assigns =
      assign(assigns, fills: fills, shadows: shadows, lines: lines, width: width, height: height)

    ~H"""
    <svg
      width={@width}
      height={@height}
      viewBox={"0 0 #{@width} #{@height}"}
      xmlns="http://www.w3.org/2000/svg"
    >
      <rect :for={{x, y, w, h} <- @fills} x={x} y={y} width={w} height={h} fill="white" />
      <rect :for={{x, y, w, h} <- @shadows} x={x} y={y} width={w} height={h} fill="black" />
      <line
        :for={{x1, y1, x2, y2} <- @lines}
        x1={x1}
        y1={y1}
        x2={x2}
        y2={y2}
        stroke="black"
        stroke-width="2"
        stroke-linecap="square"
      />
    </svg>
    """
  end

  # ---------------------------------------------------------------------------
  # Fill computation (white corridor rectangles)
  # ---------------------------------------------------------------------------

  defp compute_fills(%Grid{} = grid, cs, inset) do
    Enum.flat_map(grid.cells, fn {id, cell} ->
      x1 = cell.col * cs
      x4 = x1 + cs
      x2 = x1 + inset
      x3 = x4 - inset

      y1 = cell.row * cs
      y4 = y1 + cs
      y2 = y1 + inset
      y3 = y4 - inset

      if Grid.crossing?(grid, id) do
        crossing_fills(x1, x2, x3, x4, y1, y2, y3, y4)
      else
        over_cell_fills(grid, id, cell, x1, x2, x3, x4, y1, y2, y3, y4)
      end
    end)
  end

  # Normal cell: centre always filled; each directional strip filled when linked.
  defp over_cell_fills(grid, id, cell, x1, x2, x3, x4, y1, y2, y3, y4) do
    cw = x3 - x2
    ch = y3 - y2

    center = [{x2, y2, cw, ch}]

    north =
      if not is_nil(cell.north) and Grid.linked?(grid, id, cell.north),
        do: [{x2, y1, cw, y2 - y1}],
        else: []

    south =
      if not is_nil(cell.south) and Grid.linked?(grid, id, cell.south),
        do: [{x2, y3, cw, y4 - y3}],
        else: []

    west =
      if not is_nil(cell.west) and Grid.linked?(grid, id, cell.west),
        do: [{x1, y2, x2 - x1, ch}],
        else: []

    east =
      if not is_nil(cell.east) and Grid.linked?(grid, id, cell.east),
        do: [{x3, y2, x4 - x3, ch}],
        else: []

    center ++ north ++ south ++ west ++ east
  end

  # Crossing cell: both passages are always active so all five regions are filled.
  defp crossing_fills(x1, x2, x3, x4, y1, y2, y3, y4) do
    cw = x3 - x2
    ch = y3 - y2

    [
      {x2, y2, cw, ch},
      {x2, y1, cw, y2 - y1},
      {x2, y3, cw, y4 - y3},
      {x1, y2, x2 - x1, ch},
      {x3, y2, x4 - x3, ch}
    ]
  end

  # ---------------------------------------------------------------------------
  # Shadow computation (solid black rectangles at crossing over-passages)
  # ---------------------------------------------------------------------------

  # One thin shadow rect per crossing cell, placed in the inset gap alongside the
  # over-corridor centre region:
  #   - N-S over (vertical corridor): shadow on the right  → (x3, y2, inset, ch)
  #   - E-W over (horizontal corridor): shadow on the bottom → (x2, y3, cw, inset)
  defp compute_shadows(%Grid{} = grid, cs, inset) do
    Enum.flat_map(grid.cells, fn {id, cell} ->
      if Grid.crossing?(grid, id) do
        x1 = cell.col * cs
        x4 = x1 + cs
        x2 = x1 + inset
        x3 = x4 - inset

        y1 = cell.row * cs
        y4 = y1 + cs
        y2 = y1 + inset
        y3 = y4 - inset

        cw = x3 - x2
        ch = y3 - y2

        %{over: over_direction} = Grid.crossing_for(grid, id)

        case over_direction do
          :north_south ->
            # N-S corridor runs vertically; shadow on its right side.
            [{x3, y2, inset, ch}]

          :east_west ->
            # E-W corridor runs horizontally; shadow on its bottom.
            [{x2, y3, cw, inset}]
        end
      else
        []
      end
    end)
  end

  # ---------------------------------------------------------------------------
  # Line computation (black wall lines)
  # ---------------------------------------------------------------------------

  defp compute_lines(%Grid{} = grid, cs, inset) do
    Enum.flat_map(grid.cells, fn {id, cell} ->
      x1 = cell.col * cs
      x4 = x1 + cs
      x2 = x1 + inset
      x3 = x4 - inset

      y1 = cell.row * cs
      y4 = y1 + cs
      y2 = y1 + inset
      y3 = y4 - inset

      if Grid.crossing?(grid, id) do
        under_cell_lines(grid, id, x1, x2, x3, x4, y1, y2, y3, y4)
      else
        over_cell_lines(grid, id, cell, x1, x2, x3, x4, y1, y2, y3, y4)
      end
    end)
  end

  # Over-cell: normal cell or the over-passage side of a crossing.
  defp over_cell_lines(grid, id, cell, x1, x2, x3, x4, y1, y2, y3, y4) do
    north_lines(grid, id, cell.north, x2, x3, y1, y2) ++
      south_lines(grid, id, cell.south, x2, x3, y3, y4) ++
      west_lines(grid, id, cell.west, x1, x2, y2, y3) ++
      east_lines(grid, id, cell.east, x3, x4, y2, y3)
  end

  # NORTH: if linked, two vertical corridor walls; if not, one horizontal inner wall.
  defp north_lines(grid, id, north_id, x2, x3, y1, y2) do
    if not is_nil(north_id) and Grid.linked?(grid, id, north_id) do
      [{x2, y1, x2, y2}, {x3, y1, x3, y2}]
    else
      [{x2, y2, x3, y2}]
    end
  end

  # SOUTH: if linked, two vertical corridor walls; if not, one horizontal inner wall.
  defp south_lines(grid, id, south_id, x2, x3, y3, y4) do
    if not is_nil(south_id) and Grid.linked?(grid, id, south_id) do
      [{x2, y3, x2, y4}, {x3, y3, x3, y4}]
    else
      [{x2, y3, x3, y3}]
    end
  end

  # WEST: if linked, two horizontal corridor walls; if not, one vertical inner wall.
  defp west_lines(grid, id, west_id, x1, x2, y2, y3) do
    if not is_nil(west_id) and Grid.linked?(grid, id, west_id) do
      [{x1, y2, x2, y2}, {x1, y3, x2, y3}]
    else
      [{x2, y2, x2, y3}]
    end
  end

  # EAST: if linked, two horizontal corridor walls; if not, one vertical inner wall.
  defp east_lines(grid, id, east_id, x3, x4, y2, y3) do
    if not is_nil(east_id) and Grid.linked?(grid, id, east_id) do
      [{x3, y2, x4, y2}, {x3, y3, x4, y3}]
    else
      [{x3, y2, x3, y3}]
    end
  end

  # Crossing cell: over-corridor full-span lines + under-tunnel entry caps.
  defp under_cell_lines(grid, id, x1, x2, x3, x4, y1, y2, y3, y4) do
    %{over: over_direction} = Grid.crossing_for(grid, id)

    case over_direction do
      :north_south ->
        # N-S passes over; E-W is the under-tunnel.
        # Over-corridor: two full-height vertical lines bounding the N-S passage.
        # Under-tunnel caps: horizontal lines at y2 and y3 on the W and E sides.
        [
          {x2, y1, x2, y4},
          {x3, y1, x3, y4},
          {x1, y2, x2, y2},
          {x1, y3, x2, y3},
          {x3, y2, x4, y2},
          {x3, y3, x4, y3}
        ]

      :east_west ->
        # E-W passes over; N-S is the under-tunnel.
        # Over-corridor: two full-width horizontal lines bounding the E-W passage.
        # Under-tunnel caps: vertical lines at x2 and x3 on the N and S sides.
        [
          {x1, y2, x4, y2},
          {x1, y3, x4, y3},
          {x2, y1, x2, y2},
          {x3, y1, x3, y2},
          {x2, y3, x2, y4},
          {x3, y3, x3, y4}
        ]
    end
  end
end
