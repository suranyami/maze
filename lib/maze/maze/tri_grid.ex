defmodule Maze.TriGrid do
  @moduledoc """
  A triangular maze grid.

  Cells alternate between upright (△) and inverted (▽) triangles.
  Cell {r, c} is upright when `rem(r + c, 2) == 0`.

  Each row has `cols` cells; each column is half a base-width wide.
  """

  alias Maze.TriCell

  @type id :: TriCell.id()

  @type t :: %__MODULE__{
          rows: pos_integer(),
          cols: pos_integer(),
          cells: %{id() => TriCell.t()},
          links: MapSet.t()
        }

  defstruct rows: 0, cols: 0, cells: %{}, links: MapSet.new()

  @doc """
  Build a new triangular grid of `rows × cols` cells with all neighbours wired up.
  """
  @spec new(pos_integer(), pos_integer()) :: t()
  def new(rows, cols) do
    cells =
      for r <- 0..(rows - 1), c <- 0..(cols - 1), into: %{} do
        upright = rem(r + c, 2) == 0
        {{r, c}, %TriCell{row: r, col: c, upright: upright}}
      end

    grid = %__MODULE__{rows: rows, cols: cols, cells: cells}

    Enum.reduce(cells, grid, fn {{r, c} = id, cell}, acc ->
      neighbors = %{
        east: if(c < cols - 1, do: {r, c + 1}),
        west: if(c > 0, do: {r, c - 1}),
        south: if(cell.upright and r < rows - 1, do: {r + 1, c}),
        north: if(not cell.upright and r > 0, do: {r - 1, c})
      }

      updated = struct(acc.cells[id], neighbors)
      put_in(acc.cells[id], updated)
    end)
  end

  @doc "Open a bidirectional passage between `id1` and `id2`."
  @spec link(t(), id(), id()) :: t()
  def link(%__MODULE__{links: links} = grid, id1, id2) do
    %{grid | links: MapSet.put(links, canonical(id1, id2))}
  end

  @doc "Check whether there is an open passage between `id1` and `id2`."
  @spec linked?(t(), id(), id()) :: boolean()
  def linked?(%__MODULE__{links: links}, id1, id2) do
    MapSet.member?(links, canonical(id1, id2))
  end

  @doc "Return the ids of all direct neighbours of `id` that are unvisited."
  @spec unvisited_neighbours(t(), id()) :: [id()]
  def unvisited_neighbours(%__MODULE__{cells: cells, links: links}, id) do
    cell = Map.fetch!(cells, id)

    [cell.east, cell.west, cell.north, cell.south]
    |> Enum.reject(&is_nil/1)
    |> Enum.reject(&visited?(&1, links))
  end

  @doc "Triangular grids do not support weaving — always returns an empty list."
  @spec weave_candidates(t(), id()) :: []
  def weave_candidates(%__MODULE__{}, _id), do: []

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp canonical(a, b) when a <= b, do: {a, b}
  defp canonical(a, b), do: {b, a}

  defp visited?(id, links) do
    Enum.any?(links, fn {a, b} -> a == id or b == id end)
  end
end
