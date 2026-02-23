defmodule Maze.TriGridTest do
  use ExUnit.Case, async: true

  alias Maze.Algorithms.RecursiveBacktracker
  alias Maze.TriGrid

  describe "new/2" do
    test "builds a grid with the correct dimensions" do
      grid = TriGrid.new(4, 6)
      assert grid.rows == 4
      assert grid.cols == 6
      assert map_size(grid.cells) == 24
    end

    test "upright orientation is (row + col) % 2 == 0" do
      grid = TriGrid.new(4, 6)
      assert grid.cells[{0, 0}].upright == true
      assert grid.cells[{0, 1}].upright == false
      assert grid.cells[{1, 0}].upright == false
      assert grid.cells[{1, 1}].upright == true
    end

    test "upright cell {0,0} has east and south neighbours only" do
      grid = TriGrid.new(4, 6)
      cell = grid.cells[{0, 0}]
      assert cell.upright == true
      assert cell.east == {0, 1}
      assert cell.west == nil
      assert cell.south == {1, 0}
      assert cell.north == nil
    end

    test "inverted cell {0,1} has east, west, no north neighbour (top row)" do
      grid = TriGrid.new(4, 6)
      cell = grid.cells[{0, 1}]
      assert cell.upright == false
      assert cell.east == {0, 2}
      assert cell.west == {0, 0}
      # top row inverted cell has no north (r-1 = -1 is out of bounds)
      assert cell.north == nil
    end

    test "interior upright cell has east, west, south" do
      grid = TriGrid.new(4, 6)
      # {1,1} is upright (1+1=2, even)
      cell = grid.cells[{1, 1}]
      assert cell.upright == true
      assert cell.east == {1, 2}
      assert cell.west == {1, 0}
      assert cell.south == {2, 1}
      assert cell.north == nil
    end

    test "interior inverted cell has east, west, north" do
      grid = TriGrid.new(4, 6)
      # {1,0} is inverted (1+0=1, odd)
      cell = grid.cells[{1, 0}]
      assert cell.upright == false
      assert cell.west == nil
      assert cell.east == {1, 1}
      assert cell.north == {0, 0}
      assert cell.south == nil
    end
  end

  describe "link/3 and linked?/3" do
    test "linking two cells makes them mutually linked" do
      grid = TriGrid.new(3, 4)
      grid = TriGrid.link(grid, {0, 0}, {0, 1})
      assert TriGrid.linked?(grid, {0, 0}, {0, 1})
      assert TriGrid.linked?(grid, {0, 1}, {0, 0})
    end

    test "unlinked cells are not linked" do
      grid = TriGrid.new(3, 4)
      refute TriGrid.linked?(grid, {0, 0}, {1, 0})
    end
  end

  describe "unvisited_neighbours/2" do
    test "returns only valid neighbours in a fresh grid" do
      grid = TriGrid.new(4, 6)
      # {1,1} upright: east={1,2}, west={1,0}, south={2,1}
      neighbours = TriGrid.unvisited_neighbours(grid, {1, 1})
      assert {1, 0} in neighbours
      assert {1, 2} in neighbours
      assert {2, 1} in neighbours
      assert length(neighbours) == 3
    end

    test "visited (linked) cells are excluded" do
      grid = TriGrid.new(4, 6)
      grid = TriGrid.link(grid, {1, 1}, {1, 2})
      neighbours = TriGrid.unvisited_neighbours(grid, {1, 1})
      refute {1, 2} in neighbours
    end
  end

  describe "weave_candidates/2" do
    test "always returns empty list" do
      grid = TriGrid.new(5, 6)
      assert TriGrid.weave_candidates(grid, {2, 2}) == []
    end
  end

  describe "RecursiveBacktracker integration" do
    test "all cells reachable from start in a tri maze" do
      rows = 5
      cols = 8
      grid = TriGrid.new(rows, cols) |> RecursiveBacktracker.on()

      all_ids = for r <- 0..(rows - 1), c <- 0..(cols - 1), do: {r, c}
      reachable = flood_fill(grid, {0, 0})

      assert MapSet.new(all_ids) == reachable
    end

    test "tri maze is a spanning tree (n-1 links for n cells)" do
      rows = 4
      cols = 6
      grid = TriGrid.new(rows, cols) |> RecursiveBacktracker.on()
      assert MapSet.size(grid.links) == rows * cols - 1
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp flood_fill(grid, start) do
    do_flood(grid, [start], MapSet.new([start]))
  end

  defp do_flood(_grid, [], visited), do: visited

  defp do_flood(grid, [current | queue], visited) do
    cell = grid.cells[current]

    neighbours =
      [cell.east, cell.west, cell.north, cell.south]
      |> Enum.reject(&is_nil/1)
      |> Enum.filter(fn id ->
        TriGrid.linked?(grid, current, id) and not MapSet.member?(visited, id)
      end)

    new_visited = Enum.reduce(neighbours, visited, &MapSet.put(&2, &1))
    do_flood(grid, queue ++ neighbours, new_visited)
  end
end
