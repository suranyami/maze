defmodule Maze.Algorithms.RecursiveBacktrackerTest do
  use ExUnit.Case, async: true

  alias Maze.Algorithms.RecursiveBacktracker
  alias Maze.Grid

  describe "on/2" do
    test "generates a maze where all cells are reachable from start" do
      rows = 8
      cols = 8
      grid = Grid.new(rows, cols) |> RecursiveBacktracker.on()

      all_ids = for r <- 0..(rows - 1), c <- 0..(cols - 1), do: {r, c}
      reachable = flood_fill(grid, {0, 0})

      assert MapSet.new(all_ids) == reachable
    end

    test "creates a spanning tree (exactly rows*cols - 1 links)" do
      rows = 6
      cols = 6
      grid = Grid.new(rows, cols) |> RecursiveBacktracker.on(weave_probability: 0.0)

      # A perfect maze (spanning tree) has exactly n-1 passages for n cells.
      # With weaving disabled, every crossing also adds exactly one extra link
      # (we add 2 links for the tunnel but it's still one logical connection).
      # With weave_probability: 0.0 there should be no crossings.
      assert MapSet.size(grid.links) == rows * cols - 1
      assert map_size(grid.crossings) == 0
    end

    test "creates weave crossings when weave_probability > 0" do
      # Run multiple times to avoid flakiness — at least one run should produce crossings
      results =
        for _ <- 1..20 do
          Grid.new(10, 10) |> RecursiveBacktracker.on(weave_probability: 0.8)
        end

      assert Enum.any?(results, fn g -> map_size(g.crossings) > 0 end)
    end

    test "custom start cell works" do
      grid = Grid.new(5, 5) |> RecursiveBacktracker.on(start: {2, 2})
      all_ids = for r <- 0..4, c <- 0..4, do: {r, c}
      reachable = flood_fill(grid, {2, 2})
      assert MapSet.new(all_ids) == reachable
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Flood-fill from `start`, following open passages, and return all visited ids.
  defp flood_fill(grid, start) do
    do_flood(grid, [start], MapSet.new([start]))
  end

  defp do_flood(_grid, [], visited), do: visited

  defp do_flood(grid, [current | queue], visited) do
    cell = grid.cells[current]

    neighbours =
      [cell.north, cell.south, cell.east, cell.west]
      |> Enum.reject(&is_nil/1)
      |> Enum.filter(fn id ->
        Grid.linked?(grid, current, id) and not MapSet.member?(visited, id)
      end)

    new_visited = Enum.reduce(neighbours, visited, &MapSet.put(&2, &1))
    do_flood(grid, queue ++ neighbours, new_visited)
  end
end
