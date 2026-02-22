defmodule Maze.Cell do
  @moduledoc """
  Represents a single cell in the maze grid.

  Each cell knows its position (row, col) and its neighbours in the four
  cardinal directions. Neighbour fields hold the cell id `{row, col}` of
  the adjacent cell, or `nil` when the cell is on the grid boundary.
  """

  @type id :: {non_neg_integer(), non_neg_integer()}

  @type t :: %__MODULE__{
          row: non_neg_integer(),
          col: non_neg_integer(),
          north: id() | nil,
          south: id() | nil,
          east: id() | nil,
          west: id() | nil
        }

  defstruct row: 0, col: 0, north: nil, south: nil, east: nil, west: nil
end
