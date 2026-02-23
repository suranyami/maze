defmodule Maze.SpectreGridTest do
  use ExUnit.Case, async: true

  alias Maze.SpectreGrid
  alias Maze.Algorithms.RecursiveBacktracker

  describe "new/1" do
    test "depth 2 produces a non-empty grid" do
      grid = SpectreGrid.new(2)
      assert map_size(grid.cells) > 0
    end

    test "depth 2 has roughly 50 tiles" do
      grid = SpectreGrid.new(2)
      # The exact count varies by Gamma expansion; ~48–54 is typical
      assert map_size(grid.cells) in 40..70
    end

    test "depth 3 has more tiles than depth 2" do
      g2 = SpectreGrid.new(2)
      g3 = SpectreGrid.new(3)
      assert map_size(g3.cells) > map_size(g2.cells)
    end

    test "every cell has 14 neighbor slots" do
      grid = SpectreGrid.new(2)

      Enum.each(grid.cells, fn {_id, cell} ->
        assert length(cell.neighbors) == 14
      end)
    end

    test "adjacency is symmetric" do
      grid = SpectreGrid.new(2)

      Enum.each(grid.cells, fn {id, cell} ->
        cell.neighbors
        |> Enum.reject(&is_nil/1)
        |> Enum.each(fn nbr_id ->
          assert id in grid.cells[nbr_id].neighbors,
                 "cell #{id} lists #{nbr_id} as neighbor but not vice versa"
        end)
      end)
    end

    test "every vertex list has 14 entries" do
      grid = SpectreGrid.new(2)

      Enum.each(grid.cells, fn {_id, cell} ->
        assert length(cell.vertices) == 14
      end)
    end
  end

  describe "link/3 and linked?/3" do
    test "initially no cells are linked" do
      grid = SpectreGrid.new(2)

      Enum.each(grid.cells, fn {id, cell} ->
        cell.neighbors
        |> Enum.reject(&is_nil/1)
        |> Enum.each(fn nbr ->
          refute SpectreGrid.linked?(grid, id, nbr)
        end)
      end)
    end

    test "link creates a bidirectional passage" do
      grid = SpectreGrid.new(2)
      [{id1, _}, {id2, _} | _] = Enum.to_list(grid.cells)
      linked = SpectreGrid.link(grid, id1, id2)
      assert SpectreGrid.linked?(linked, id1, id2)
      assert SpectreGrid.linked?(linked, id2, id1)
    end
  end

  describe "unvisited_neighbours/2" do
    test "unlinked neighbors are unvisited" do
      grid = SpectreGrid.new(2)
      {id, cell} = Enum.find(grid.cells, fn {_, c} -> Enum.any?(c.neighbors, &(!is_nil(&1))) end)
      unvisited = SpectreGrid.unvisited_neighbours(grid, id)
      expected = cell.neighbors |> Enum.reject(&is_nil/1) |> Enum.uniq()
      assert Enum.sort(unvisited) == Enum.sort(expected)
    end

    test "linked neighbor is no longer unvisited" do
      grid = SpectreGrid.new(2)
      {id, cell} = Enum.find(grid.cells, fn {_, c} -> Enum.any?(c.neighbors, &(!is_nil(&1))) end)
      nbr = cell.neighbors |> Enum.reject(&is_nil/1) |> hd()
      linked = SpectreGrid.link(grid, id, nbr)
      refute nbr in SpectreGrid.unvisited_neighbours(linked, id)
    end
  end

  describe "weave_candidates/2" do
    test "always returns empty list" do
      grid = SpectreGrid.new(2)

      Enum.each(grid.cells, fn {id, _} ->
        assert SpectreGrid.weave_candidates(grid, id) == []
      end)
    end
  end

  describe "RecursiveBacktracker integration" do
    test "maze is fully connected (all cells reachable)" do
      grid = SpectreGrid.new(2) |> RecursiveBacktracker.on(start: 0, weave_probability: 0.0)

      all_ids = MapSet.new(Map.keys(grid.cells))

      reachable =
        bfs(grid, 0)

      assert MapSet.equal?(reachable, all_ids),
             "#{MapSet.size(all_ids) - MapSet.size(reachable)} cells not reachable"
    end

    test "link count equals cell_count - 1 (spanning tree)" do
      grid = SpectreGrid.new(2) |> RecursiveBacktracker.on(start: 0, weave_probability: 0.0)
      cell_count = map_size(grid.cells)
      link_count = MapSet.size(grid.links)
      assert link_count == cell_count - 1
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp bfs(grid, start) do
    bfs_loop(grid, [start], MapSet.new([start]))
  end

  defp bfs_loop(_grid, [], visited), do: visited

  defp bfs_loop(grid, [id | queue], visited) do
    neighbors =
      grid.cells[id].neighbors
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
      |> Enum.filter(&SpectreGrid.linked?(grid, id, &1))
      |> Enum.reject(&MapSet.member?(visited, &1))

    new_visited = Enum.reduce(neighbors, visited, &MapSet.put(&2, &1))
    bfs_loop(grid, queue ++ neighbors, new_visited)
  end
end
