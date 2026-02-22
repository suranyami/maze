defmodule Maze.GridTest do
  use ExUnit.Case, async: true

  alias Maze.Grid

  describe "new/2" do
    test "builds a grid with the correct dimensions" do
      grid = Grid.new(3, 4)
      assert grid.rows == 3
      assert grid.cols == 4
      assert map_size(grid.cells) == 12
    end

    test "corner cell {0,0} has south and east neighbours only" do
      grid = Grid.new(3, 4)
      cell = grid.cells[{0, 0}]
      assert cell.north == nil
      assert cell.west == nil
      assert cell.south == {1, 0}
      assert cell.east == {0, 1}
    end

    test "interior cell has all four neighbours" do
      grid = Grid.new(3, 4)
      cell = grid.cells[{1, 2}]
      assert cell.north == {0, 2}
      assert cell.south == {2, 2}
      assert cell.west == {1, 1}
      assert cell.east == {1, 3}
    end

    test "bottom-right corner has north and west neighbours only" do
      grid = Grid.new(3, 4)
      cell = grid.cells[{2, 3}]
      assert cell.north == {2 - 1, 3}
      assert cell.west == {2, 3 - 1}
      assert cell.south == nil
      assert cell.east == nil
    end
  end

  describe "link/3 and linked?/3" do
    test "linking two cells makes them mutually linked" do
      grid = Grid.new(3, 3)
      grid = Grid.link(grid, {0, 0}, {0, 1})
      assert Grid.linked?(grid, {0, 0}, {0, 1})
      assert Grid.linked?(grid, {0, 1}, {0, 0})
    end

    test "unlinked cells are not linked" do
      grid = Grid.new(3, 3)
      refute Grid.linked?(grid, {0, 0}, {1, 0})
    end
  end

  describe "unvisited_neighbours/2" do
    test "all neighbours are unvisited in a fresh grid" do
      grid = Grid.new(3, 3)
      neighbours = Grid.unvisited_neighbours(grid, {1, 1})
      assert length(neighbours) == 4
      assert {0, 1} in neighbours
      assert {2, 1} in neighbours
      assert {1, 0} in neighbours
      assert {1, 2} in neighbours
    end

    test "linked cells are no longer unvisited" do
      grid = Grid.new(3, 3)
      grid = Grid.link(grid, {1, 1}, {0, 1})
      neighbours = Grid.unvisited_neighbours(grid, {1, 1})
      refute {0, 1} in neighbours
    end

    test "already-visited neighbours are excluded" do
      grid = Grid.new(3, 3)
      # Visit {1,0} by linking it elsewhere
      grid = Grid.link(grid, {1, 0}, {2, 0})
      neighbours = Grid.unvisited_neighbours(grid, {1, 1})
      refute {1, 0} in neighbours
    end
  end

  describe "crossing operations" do
    test "add_crossing records the crossing direction" do
      grid = Grid.new(5, 5)
      grid = Grid.add_crossing(grid, {2, 2}, :north_south)
      assert Grid.crossing?(grid, {2, 2})
      assert Grid.crossing_for(grid, {2, 2}) == %{over: :north_south}
    end

    test "non-crossing cells return false/nil" do
      grid = Grid.new(5, 5)
      refute Grid.crossing?(grid, {0, 0})
      assert Grid.crossing_for(grid, {0, 0}) == nil
    end
  end

  describe "weave_candidates/2" do
    test "returns empty list when no candidates exist in a fresh grid" do
      # In a fresh grid, no cell is visited, so no weave candidates
      grid = Grid.new(5, 5)
      assert Grid.weave_candidates(grid, {0, 0}) == []
    end

    test "returns a candidate when intermediate cell is linked N-S only" do
      grid = Grid.new(5, 5)
      # Link {1,1} north–south so it can be woven through horizontally
      grid = Grid.link(grid, {1, 1}, {0, 1})
      # From {1,0} looking east, {1,1} is the intermediate (linked N-S)
      # and {1,2} is unvisited beyond
      candidates = Grid.weave_candidates(grid, {1, 0})
      # Should find a weave through {1,1} to {1,2}
      assert {{1, 2}, {1, 1}, :north_south} in candidates
    end

    test "returns a candidate when intermediate cell is linked E-W only" do
      grid = Grid.new(5, 5)
      # Link {1,1} east–west so it can be woven through vertically
      grid = Grid.link(grid, {1, 1}, {1, 0})
      # From {0,1} looking south, {1,1} is the intermediate (linked E-W)
      # and {2,1} is unvisited beyond
      candidates = Grid.weave_candidates(grid, {0, 1})
      assert {{2, 1}, {1, 1}, :east_west} in candidates
    end

    test "does not offer already-visited beyond cell as candidate" do
      grid = Grid.new(5, 5)
      grid = Grid.link(grid, {1, 1}, {0, 1})
      # Visit {1,2}
      grid = Grid.link(grid, {1, 2}, {2, 2})
      candidates = Grid.weave_candidates(grid, {1, 0})
      refute {{1, 2}, {1, 1}, :north_south} in candidates
    end
  end
end
