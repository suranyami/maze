defmodule Maze.HexCell do
  @moduledoc """
  Represents a single cell in a hexagonal maze grid.

  Uses six directions for a pointy-top hexagon layout with odd-r offset
  (odd rows are shifted right by half a hex width):

      NW  NE
    W      E
      SW  SE
  """

  @type id :: {non_neg_integer(), non_neg_integer()}

  @type t :: %__MODULE__{
          row: non_neg_integer(),
          col: non_neg_integer(),
          northwest: id() | nil,
          northeast: id() | nil,
          east: id() | nil,
          southeast: id() | nil,
          southwest: id() | nil,
          west: id() | nil
        }

  defstruct row: 0,
            col: 0,
            northwest: nil,
            northeast: nil,
            east: nil,
            southeast: nil,
            southwest: nil,
            west: nil
end
