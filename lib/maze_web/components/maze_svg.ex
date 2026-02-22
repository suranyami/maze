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

  For every **over-cell** (normal or the over-passage of a crossing):
    - Linked direction: draw two corridor-wall segments (the sides of the opening)
    - Unlinked direction: draw one inner wall segment (closing the passage)

  For every **under-cell** (the passage that tunnels beneath another):
    - `over: :north_south` (N-S over, E-W under) — draw horizontal caps at W and E entries
    - `over: :east_west`   (E-W over, N-S under) — draw vertical caps at N and S entries

  No explicit outer border is drawn; the inner wall segments of border cells
  provide the visual boundary.
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

  def render(assigns) do
    %{grid: grid, cell_size: cs} = assigns
    inset = cs * @inset_ratio
    lines = compute_lines(grid, cs, inset)
    width = grid.cols * cs
    height = grid.rows * cs

    assigns = assign(assigns, lines: lines, width: width, height: height)

    ~H"""
    <svg
      width={@width}
      height={@height}
      viewBox={"0 0 #{@width} #{@height}"}
      xmlns="http://www.w3.org/2000/svg"
      style="background: white;"
    >
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
  # Line computation
  # ---------------------------------------------------------------------------

  defp compute_lines(%Grid{} = grid, cs, inset) do
    Enum.flat_map(grid.cells, fn {id, cell} ->
      # Inset coordinates for this cell
      cx1 = cell.col * cs
      cx4 = cx1 + cs
      cx2 = cx1 + inset
      cx3 = cx4 - inset

      cy1 = cell.row * cs
      cy4 = cy1 + cs
      cy2 = cy1 + inset
      cy3 = cy4 - inset

      if Grid.crossing?(grid, id) do
        under_cell_lines(grid, id, cx1, cx2, cx3, cx4, cy1, cy2, cy3, cy4)
      else
        over_cell_lines(grid, id, cell, cx1, cx2, cx3, cx4, cy1, cy2, cy3, cy4)
      end
    end)
  end

  # Over-cell: normal cell or the over-passage side of a crossing.
  # Each of the four directions is drawn independently.
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

  # Crossing cell: draws both the over-corridor walls and the under-tunnel caps.
  #
  # The book uses two separate cell objects at the same grid position (OverCell +
  # UnderCell). Since this implementation has a single cell per position, we must
  # draw both contributions here.
  #
  # Over-corridor walls are the two long lines that bound the over-passage as it
  # runs through the crossing cell. Under-tunnel caps are the four short segments
  # at the tunnel entry/exit points showing the opening of the under-passage.
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
