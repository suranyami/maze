defmodule Maze.HexGridTest do
  use ExUnit.Case, async: true

  alias Maze.Algorithms.RecursiveBacktracker
  alias Maze.HexGrid

  describe "new/2" do
    test "builds a grid with the correct dimensions" do
      grid = HexGrid.new(4, 5)
      assert grid.rows == 4
      assert grid.cols == 5
      assert map_size(grid.cells) == 20
    end

    test "top-left corner {0,0} has no northwest or west neighbour" do
      grid = HexGrid.new(4, 5)
      cell = grid.cells[{0, 0}]
      assert cell.northwest == nil
      assert cell.west == nil
    end

    test "interior cell in even row has all six neighbours" do
      grid = HexGrid.new(5, 5)
      # {2, 2} is an even row interior cell
      cell = grid.cells[{2, 2}]
      # Even row: NW={r-1,c-1}, NE={r-1,c}, E={r,c+1}, SE={r+1,c}, SW={r+1,c-1}, W={r,c-1}
      assert cell.northwest == {1, 1}
      assert cell.northeast == {1, 2}
      assert cell.east == {2, 3}
      assert cell.southeast == {3, 2}
      assert cell.southwest == {3, 1}
      assert cell.west == {2, 1}
    end

    test "interior cell in odd row has all six neighbours" do
      grid = HexGrid.new(5, 5)
      # {1, 2} is an odd row interior cell
      cell = grid.cells[{1, 2}]
      # Odd row: NW={r-1,c}, NE={r-1,c+1}, E={r,c+1}, SE={r+1,c+1}, SW={r+1,c}, W={r,c-1}
      assert cell.northwest == {0, 2}
      assert cell.northeast == {0, 3}
      assert cell.east == {1, 3}
      assert cell.southeast == {2, 3}
      assert cell.southwest == {2, 2}
      assert cell.west == {1, 1}
    end
  end

  describe "link/3 and linked?/3" do
    test "linking two cells makes them mutually linked" do
      grid = HexGrid.new(3, 3)
      grid = HexGrid.link(grid, {0, 0}, {0, 1})
      assert HexGrid.linked?(grid, {0, 0}, {0, 1})
      assert HexGrid.linked?(grid, {0, 1}, {0, 0})
    end

    test "unlinked cells are not linked" do
      grid = HexGrid.new(3, 3)
      refute HexGrid.linked?(grid, {0, 0}, {1, 0})
    end
  end

  describe "unvisited_neighbours/2" do
    test "returns only valid neighbours in a fresh grid" do
      grid = HexGrid.new(3, 3)

      # Corner cell {0,0} in even row: NE={-1,0}→nil, NW={-1,-1}→nil, E={0,1}, SE={1,0}, SW={1,-1}→nil, W={0,-1}→nil
      neighbours = HexGrid.unvisited_neighbours(grid, {0, 0})
      assert {0, 1} in neighbours
      assert {1, 0} in neighbours
      # No nil neighbours
      refute nil in neighbours
    end

    test "visited (linked) cells are excluded" do
      grid = HexGrid.new(4, 4)
      grid = HexGrid.link(grid, {1, 1}, {0, 1})
      neighbours = HexGrid.unvisited_neighbours(grid, {1, 1})
      # {0,1} is now visited (linked), should not appear
      refute {0, 1} in neighbours
    end
  end

  describe "weave_candidates/2" do
    test "always returns empty list" do
      grid = HexGrid.new(5, 5)
      assert HexGrid.weave_candidates(grid, {2, 2}) == []
    end
  end

  describe "RecursiveBacktracker integration" do
    test "all cells reachable from start in a hex maze" do
      rows = 6
      cols = 6
      grid = HexGrid.new(rows, cols) |> RecursiveBacktracker.on()

      all_ids = for r <- 0..(rows - 1), c <- 0..(cols - 1), do: {r, c}
      reachable = flood_fill(grid, {0, 0})

      assert MapSet.new(all_ids) == reachable
    end

    test "hex maze is a spanning tree (n-1 links for n cells)" do
      rows = 5
      cols = 5
      grid = HexGrid.new(rows, cols) |> RecursiveBacktracker.on()
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
      [:northwest, :northeast, :east, :southeast, :southwest, :west]
      |> Enum.map(&Map.get(cell, &1))
      |> Enum.reject(&is_nil/1)
      |> Enum.filter(fn id ->
        HexGrid.linked?(grid, current, id) and not MapSet.member?(visited, id)
      end)

    new_visited = Enum.reduce(neighbours, visited, &MapSet.put(&2, &1))
    do_flood(grid, queue ++ neighbours, new_visited)
  end
end
