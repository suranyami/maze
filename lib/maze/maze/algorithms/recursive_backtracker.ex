defmodule Maze.Algorithms.RecursiveBacktracker do
  @moduledoc """
  Recursive Backtracker (depth-first search) maze generator.

  Works with any grid module that implements:
    - `unvisited_neighbours/2`
    - `weave_candidates/2`
    - `link/3`

  Weaving support (over/under crossings) is available for grid modules that
  also implement `add_crossing/3`.  For hex and triangular grids,
  `weave_candidates/2` returns `[]` so weaving never occurs.
  """

  @default_weave_probability 0.3

  @doc """
  Run the algorithm on `grid` and return the modified grid.

  The grid module is detected automatically from the struct type.

  Options:
    - `:start` — starting cell id `{row, col}` (default: `{0, 0}`)
    - `:weave_probability` — float `0.0–1.0` controlling how often a weave
      move is attempted when available (default: `#{@default_weave_probability}`)
  """
  @spec on(struct(), keyword()) :: struct()
  def on(%{__struct__: grid_mod} = grid, opts \\ []) do
    start = Keyword.get(opts, :start, {0, 0})
    weave_prob = Keyword.get(opts, :weave_probability, @default_weave_probability)

    run(grid, grid_mod, [start], weave_prob)
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  # Stack is empty — done.
  defp run(grid, _mod, [], _weave_prob), do: grid

  defp run(grid, mod, [current | rest], weave_prob) do
    candidates = select_candidates(grid, mod, current, weave_prob)

    if candidates == [] do
      run(grid, mod, rest, weave_prob)
    else
      chosen = Enum.random(candidates)
      {new_grid, next_cell} = apply_move(grid, mod, current, chosen)
      run(new_grid, mod, [next_cell, current | rest], weave_prob)
    end
  end

  # Select the candidate move list for the current cell.
  # Normal neighbours are always preferred; weaves are included with probability
  # weave_prob when the cell has no unvisited direct neighbours.
  defp select_candidates(grid, mod, id, weave_prob) do
    normal = mod.unvisited_neighbours(grid, id)
    weaves = mod.weave_candidates(grid, id)

    cond do
      normal != [] and weaves == [] ->
        normal

      normal != [] ->
        if :rand.uniform() <= weave_prob, do: normal ++ weaves, else: normal

      weaves != [] and :rand.uniform() <= weave_prob ->
        weaves

      true ->
        []
    end
  end

  # Apply a weave move: {beyond_id, crossing_id, over_direction}.
  defp apply_move(grid, mod, current, {beyond_id, crossing_id, over_direction})
       when over_direction in [:north_south, :east_west] do
    new_grid =
      grid
      |> mod.add_crossing(crossing_id, over_direction)
      |> mod.link(current, crossing_id)
      |> mod.link(crossing_id, beyond_id)

    {new_grid, beyond_id}
  end

  # Apply a normal move: link current → neighbour_id.
  defp apply_move(grid, mod, current, neighbour_id) do
    new_grid = mod.link(grid, current, neighbour_id)
    {new_grid, neighbour_id}
  end
end
