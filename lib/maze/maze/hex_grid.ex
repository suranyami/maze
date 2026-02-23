defmodule Maze.HexGrid do
  @moduledoc """
  A hexagonal maze grid using odd-r offset coordinates with pointy-top hexagons.

  Odd rows are shifted right by half a hex width:

      Row 0 (even):  [0,0]  [0,1]  [0,2]
      Row 1 (odd):     [1,0]  [1,1]  [1,2]
      Row 2 (even):  [2,0]  [2,1]  [2,2]

  Neighbour directions for even vs odd rows:

      Even row {r, c}:  NW={r-1,c-1}  NE={r-1,c}  E={r,c+1}  SE={r+1,c}  SW={r+1,c-1}  W={r,c-1}
      Odd row  {r, c}:  NW={r-1,c}    NE={r-1,c+1} E={r,c+1}  SE={r+1,c+1} SW={r+1,c}   W={r,c-1}
  """

  alias Maze.HexCell

  @type id :: HexCell.id()

  @type t :: %__MODULE__{
          rows: pos_integer(),
          cols: pos_integer(),
          cells: %{id() => HexCell.t()},
          links: MapSet.t()
        }

  defstruct rows: 0, cols: 0, cells: %{}, links: MapSet.new()

  @directions [:northwest, :northeast, :east, :southeast, :southwest, :west]

  @doc """
  Build a new hex grid of `rows × cols` cells with all neighbours wired up.
  """
  @spec new(pos_integer(), pos_integer()) :: t()
  def new(rows, cols) do
    cells =
      for r <- 0..(rows - 1), c <- 0..(cols - 1), into: %{} do
        {{r, c}, %HexCell{row: r, col: c}}
      end

    grid = %__MODULE__{rows: rows, cols: cols, cells: cells}

    Enum.reduce(cells, grid, fn {{r, c} = id, _cell}, acc ->
      odd = rem(r, 2) == 1

      raw = %{
        northwest: if(odd, do: {r - 1, c}, else: {r - 1, c - 1}),
        northeast: if(odd, do: {r - 1, c + 1}, else: {r - 1, c}),
        east: {r, c + 1},
        southeast: if(odd, do: {r + 1, c + 1}, else: {r + 1, c}),
        southwest: if(odd, do: {r + 1, c}, else: {r + 1, c - 1}),
        west: {r, c - 1}
      }

      valid =
        Map.new(raw, fn {dir, nid} ->
          {dir, if(Map.has_key?(cells, nid), do: nid, else: nil)}
        end)

      updated = struct(acc.cells[id], valid)
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
  def unvisited_neighbours(%__MODULE__{cells: cells, links: links} = _grid, id) do
    cell = Map.fetch!(cells, id)

    @directions
    |> Enum.map(&Map.get(cell, &1))
    |> Enum.reject(&is_nil/1)
    |> Enum.reject(&visited?(&1, links))
  end

  @doc "Hex grids do not support weaving — always returns an empty list."
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
