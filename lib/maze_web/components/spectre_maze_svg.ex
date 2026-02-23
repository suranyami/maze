defmodule MazeWeb.Components.SpectreMazeSvg do
  @moduledoc """
  Phoenix component that renders a `Maze.SpectreGrid` as an SVG.

  Each spectre tile is a 14-sided polygon.  Wall lines are drawn for every
  edge that is either a boundary (no neighbour) or an unlinked interior edge.
  Linked edges are left open, creating visible passage gaps.

  Coordinates are scaled by `cell_size` pixels per tile-edge unit and
  translated so the tiling fits within a white SVG canvas.
  """

  use Phoenix.Component

  alias Maze.SpectreGrid

  attr :grid, :map, required: true
  attr :cell_size, :integer, default: 15

  def render(assigns) do
    %{grid: grid, cell_size: scale} = assigns

    all_verts = Enum.flat_map(grid.cells, fn {_, cell} -> cell.vertices end)
    {ox, oy, svg_width, svg_height} = bounding_box(all_verts, scale)

    lines = wall_lines(grid, scale, ox, oy)

    assigns =
      assign(assigns,
        lines: lines,
        width: svg_width,
        height: svg_height
      )

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
        stroke-width="1.5"
        stroke-linecap="round"
      />
    </svg>
    """
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  @n_edges 14

  defp wall_lines(grid, scale, ox, oy) do
    Enum.flat_map(grid.cells, fn {id, cell} ->
      cell.vertices
      |> Stream.with_index()
      |> Enum.flat_map(fn {v1, i} ->
        v2 = Enum.at(cell.vertices, rem(i + 1, @n_edges))
        neighbor_id = Enum.at(cell.neighbors, i)

        if is_nil(neighbor_id) or not SpectreGrid.linked?(grid, id, neighbor_id) do
          [{to_svg(v1, scale, ox, oy), to_svg(v2, scale, ox, oy)}]
        else
          []
        end
      end)
      |> Enum.map(fn {{x1, y1}, {x2, y2}} -> {x1, y1, x2, y2} end)
    end)
  end

  # Compute origin offset and canvas size from the vertex bounding box.
  # Returns {origin_x, origin_y, canvas_width, canvas_height}.
  defp bounding_box(vertices, scale) do
    xs = Enum.map(vertices, &elem(&1, 0))
    ys = Enum.map(vertices, &elem(&1, 1))
    min_x = Enum.min(xs)
    max_x = Enum.max(xs)
    min_y = Enum.min(ys)
    max_y = Enum.max(ys)
    pad = 1.0
    w = ceil((max_x - min_x + 2 * pad) * scale) |> round()
    h = ceil((max_y - min_y + 2 * pad) * scale) |> round()
    {min_x - pad, min_y - pad, w, h}
  end

  defp to_svg({x, y}, scale, ox, oy) do
    {(x - ox) * scale, (y - oy) * scale}
  end
end
