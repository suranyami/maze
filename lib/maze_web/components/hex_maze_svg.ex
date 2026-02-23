defmodule MazeWeb.Components.HexMazeSvg do
  @moduledoc """
  Phoenix component that renders a `Maze.HexGrid` as an SVG.

  Uses pointy-top hexagons with odd-r offset layout.

  Each hex has circumradius `s = cell_size`.  The six vertices
  (numbered clockwise from the top):

      V0 (top)
    V5       V1
    V4       V2
      V3 (bottom)

  Edges:
    NW wall  →  V5 → V0
    NE wall  →  V0 → V1
    E  wall  →  V1 → V2
    SE wall  →  V2 → V3
    SW wall  →  V3 → V4
    W  wall  →  V4 → V5

  A wall line is drawn when the cell is NOT linked to the neighbour
  in that direction (or has no neighbour there — border edge).
  """

  use Phoenix.Component

  alias Maze.HexGrid

  @sqrt3 1.7320508075688772

  attr :grid, :map, required: true
  attr :cell_size, :integer, default: 20

  def render(assigns) do
    %{grid: grid, cell_size: s} = assigns
    hex_w = s * @sqrt3
    row_h = s * 1.5

    width = ceil(hex_w * grid.cols + hex_w / 2) |> round()
    height = ceil(row_h * (grid.rows - 1) + 2 * s) |> round()

    lines = compute_lines(grid, s, hex_w, row_h)
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

  defp compute_lines(grid, s, hex_w, row_h) do
    h = hex_w / 2
    q = s / 2

    Enum.flat_map(grid.cells, fn {id, cell} ->
      {row, col} = id
      odd = rem(row, 2) == 1
      cx = col * hex_w + if(odd, do: hex_w / 2, else: 0) + hex_w / 2
      cy = row * row_h + s

      v0 = {cx, cy - s}
      v1 = {cx + h, cy - q}
      v2 = {cx + h, cy + q}
      v3 = {cx, cy + s}
      v4 = {cx - h, cy + q}
      v5 = {cx - h, cy - q}

      walls_for(grid, id, cell, [
        {:northwest, v5, v0},
        {:northeast, v0, v1},
        {:east, v1, v2},
        {:southeast, v2, v3},
        {:southwest, v3, v4},
        {:west, v4, v5}
      ])
    end)
  end

  defp walls_for(grid, id, cell, wall_specs) do
    Enum.flat_map(wall_specs, fn {dir, {x1, y1}, {x2, y2}} ->
      neighbor_id = Map.get(cell, dir)

      if is_nil(neighbor_id) or not HexGrid.linked?(grid, id, neighbor_id) do
        [{x1, y1, x2, y2}]
      else
        []
      end
    end)
  end
end
