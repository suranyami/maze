defmodule Maze.Grid do
  @moduledoc """
  A rectangular maze grid.

  Cells are keyed by `{row, col}` tuples.  Passages between cells are stored
  in `links` as a `MapSet` of `{id1, id2}` pairs (always in canonical order
  so that `{a, b}` and `{b, a}` are stored identically).

  Crossings are stored in `crossings` as `%{cell_id => %{over: direction}}`
  where `direction` is `:north_south` or `:east_west`, indicating which axis
  passes over at that cell.
  """

  alias Maze.Cell

  @type id :: Cell.id()

  @type t :: %__MODULE__{
          rows: pos_integer(),
          cols: pos_integer(),
          cells: %{id() => Cell.t()},
          links: MapSet.t(),
          crossings: %{id() => %{over: :north_south | :east_west}}
        }

  defstruct rows: 0, cols: 0, cells: %{}, links: MapSet.new(), crossings: %{}

  @doc """
  Build a new grid of `rows × cols` cells with all neighbours wired up.
  """
  @spec new(pos_integer(), pos_integer()) :: t()
  def new(rows, cols) do
    cells =
      for r <- 0..(rows - 1), c <- 0..(cols - 1), into: %{} do
        cell = %Cell{
          row: r,
          col: c,
          north: if(r > 0, do: {r - 1, c}),
          south: if(r < rows - 1, do: {r + 1, c}),
          west: if(c > 0, do: {r, c - 1}),
          east: if(c < cols - 1, do: {r, c + 1})
        }

        {{r, c}, cell}
      end

    %__MODULE__{rows: rows, cols: cols, cells: cells}
  end

  @doc """
  Open a bidirectional passage between `id1` and `id2`.
  """
  @spec link(t(), id(), id()) :: t()
  def link(%__MODULE__{links: links} = grid, id1, id2) do
    %{grid | links: MapSet.put(links, canonical(id1, id2))}
  end

  @doc """
  Check whether there is an open passage between `id1` and `id2`.
  """
  @spec linked?(t(), id(), id()) :: boolean()
  def linked?(%__MODULE__{links: links}, id1, id2) do
    MapSet.member?(links, canonical(id1, id2))
  end

  @doc """
  Return the ids of all direct neighbours of `id` that have not yet been
  linked to any other cell (i.e. unvisited in DFS terms).
  """
  @spec unvisited_neighbours(t(), id()) :: [id()]
  def unvisited_neighbours(%__MODULE__{cells: cells, links: links} = grid, id) do
    cell = Map.fetch!(cells, id)

    [cell.north, cell.south, cell.east, cell.west]
    |> Enum.reject(&is_nil/1)
    |> Enum.filter(fn neighbour_id ->
      not visited?(grid, neighbour_id, links)
    end)
  end

  @doc """
  Return weave candidates from `id`.

  A weave move jumps two cells in one direction:
  - the intermediate cell must already be visited (linked to at least one
    cell) and must be linked **only** on the perpendicular axis relative to
    the direction we are travelling (so that crossing it makes physical sense)
  - the cell two steps away (`beyond`) must be unvisited

  Returns a list of `{beyond_id, crossing_id, over_direction}` tuples where
  `over_direction` is the axis (`:north_south` or `:east_west`) that will
  pass OVER at the crossing cell.
  """
  @spec weave_candidates(t(), id()) :: [{id(), id(), :north_south | :east_west}]
  def weave_candidates(%__MODULE__{cells: cells} = grid, id) do
    cell = Map.fetch!(cells, id)

    # Horizontal weave: moving east–west, the crossing must be linked N-S only
    horizontal_candidates =
      for {_dir, neighbour_id, beyond_dir} <- [
            {:east, cell.east, :east},
            {:west, cell.west, :west}
          ],
          not is_nil(neighbour_id),
          beyond_id = step(cells, neighbour_id, beyond_dir),
          not is_nil(beyond_id),
          can_weave_horizontal?(grid, neighbour_id),
          not visited?(grid, beyond_id, grid.links) do
        {beyond_id, neighbour_id, :north_south}
      end

    # Vertical weave: moving north–south, the crossing must be linked E-W only
    vertical_candidates =
      for {_dir, neighbour_id, beyond_dir} <- [
            {:north, cell.north, :north},
            {:south, cell.south, :south}
          ],
          not is_nil(neighbour_id),
          beyond_id = step(cells, neighbour_id, beyond_dir),
          not is_nil(beyond_id),
          can_weave_vertical?(grid, neighbour_id),
          not visited?(grid, beyond_id, grid.links) do
        {beyond_id, neighbour_id, :east_west}
      end

    horizontal_candidates ++ vertical_candidates
  end

  @doc """
  Record that `cell_id` is a crossing with the given `over_direction`.
  """
  @spec add_crossing(t(), id(), :north_south | :east_west) :: t()
  def add_crossing(%__MODULE__{crossings: crossings} = grid, cell_id, over_direction) do
    %{grid | crossings: Map.put(crossings, cell_id, %{over: over_direction})}
  end

  @doc """
  Return true if `cell_id` is a crossing cell.
  """
  @spec crossing?(t(), id()) :: boolean()
  def crossing?(%__MODULE__{crossings: crossings}, cell_id) do
    Map.has_key?(crossings, cell_id)
  end

  @doc """
  Return the crossing metadata for `cell_id`, or `nil` if not a crossing.
  """
  @spec crossing_for(t(), id()) :: %{over: :north_south | :east_west} | nil
  def crossing_for(%__MODULE__{crossings: crossings}, cell_id) do
    Map.get(crossings, cell_id)
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # Canonical pair ordering so {a,b} and {b,a} map to the same key
  defp canonical(a, b) when a <= b, do: {a, b}
  defp canonical(a, b), do: {b, a}

  # Has the cell at `id` been linked to at least one other cell?
  defp visited?(%__MODULE__{}, id, links) do
    Enum.any?(links, fn {a, b} -> a == id or b == id end)
  end

  # Step from `id` in the given direction, returning the neighbour's id or nil
  defp step(cells, id, :north), do: cells[id] && cells[id].north
  defp step(cells, id, :south), do: cells[id] && cells[id].south
  defp step(cells, id, :east), do: cells[id] && cells[id].east
  defp step(cells, id, :west), do: cells[id] && cells[id].west

  # A cell can be woven through horizontally (E-W tunnel) when it is already
  # visited and only has passages on the N-S axis (not yet linked E-W).
  defp can_weave_horizontal?(grid, id) do
    cell = grid.cells[id]

    visited?(grid, id, grid.links) and
      not crossing?(grid, id) and
      not (not is_nil(cell.east) and linked?(grid, id, cell.east)) and
      not (not is_nil(cell.west) and linked?(grid, id, cell.west))
  end

  # A cell can be woven through vertically (N-S tunnel) when it is already
  # visited and only has passages on the E-W axis (not yet linked N-S).
  defp can_weave_vertical?(grid, id) do
    cell = grid.cells[id]

    visited?(grid, id, grid.links) and
      not crossing?(grid, id) and
      not (not is_nil(cell.north) and linked?(grid, id, cell.north)) and
      not (not is_nil(cell.south) and linked?(grid, id, cell.south))
  end
end
