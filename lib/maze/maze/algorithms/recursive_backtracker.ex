defmodule Maze.Algorithms.RecursiveBacktracker do
  @moduledoc """
  Recursive Backtracker (depth-first search) maze generator with optional
  weaving support.

  Weaving lets the algorithm carve passages that cross over/under existing
  passages, creating a more complex, three-dimensional-looking maze.
  """

  alias Maze.Grid

  @default_weave_probability 0.3

  @doc """
  Run the algorithm on `grid` and return the modified grid.

  Options:
    - `:start` — starting cell id `{row, col}` (default: `{0, 0}`)
    - `:weave_probability` — float `0.0–1.0` controlling how often a weave
      move is attempted when available (default: `#{@default_weave_probability}`)
  """
  @spec on(Grid.t(), keyword()) :: Grid.t()
  def on(%Grid{} = grid, opts \\ []) do
    start = Keyword.get(opts, :start, {0, 0})
    weave_prob = Keyword.get(opts, :weave_probability, @default_weave_probability)

    run(grid, [start], weave_prob)
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  # Stack is empty — done.
  defp run(grid, [], _weave_prob), do: grid

  defp run(grid, [current | rest], weave_prob) do
    candidates = select_candidates(grid, current, weave_prob)

    if candidates == [] do
      run(grid, rest, weave_prob)
    else
      chosen = Enum.random(candidates)
      {new_grid, next_cell} = apply_move(grid, current, chosen)
      run(new_grid, [next_cell, current | rest], weave_prob)
    end
  end

  # Select the candidate move list for the current cell.
  # Normal neighbours are always preferred; weaves are included with probability
  # weave_prob when the cell has no unvisited direct neighbours.
  defp select_candidates(grid, id, weave_prob) do
    normal = Grid.unvisited_neighbours(grid, id)
    weaves = Grid.weave_candidates(grid, id)

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

  # Apply a normal move: link current → neighbour_id.
  defp apply_move(grid, current, neighbour_id)
       when is_tuple(neighbour_id) and tuple_size(neighbour_id) == 2 do
    new_grid = Grid.link(grid, current, neighbour_id)
    {new_grid, neighbour_id}
  end

  # Apply a weave move: {beyond_id, crossing_id, over_direction}.
  defp apply_move(grid, current, {beyond_id, crossing_id, over_direction}) do
    new_grid =
      grid
      |> Grid.add_crossing(crossing_id, over_direction)
      |> Grid.link(current, crossing_id)
      |> Grid.link(crossing_id, beyond_id)

    {new_grid, beyond_id}
  end
end
