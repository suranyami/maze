defmodule Maze.TriCell do
  @moduledoc """
  Represents a single cell in a triangular maze grid.

  Triangular cells alternate between upright (△) and inverted (▽) orientations:

    - `upright: true`  (△) when `rem(row + col, 2) == 0`
    - `upright: false` (▽) when `rem(row + col, 2) == 1`

  Neighbours:
    - Both orientations: `east` {r, c+1} and `west` {r, c-1}
    - Upright  △: `south` {r+1, c}  (the inverted cell directly below)
    - Inverted ▽: `north` {r-1, c}  (the upright cell directly above)

  Unused direction fields are `nil`.
  """

  @type id :: {non_neg_integer(), non_neg_integer()}

  @type t :: %__MODULE__{
          row: non_neg_integer(),
          col: non_neg_integer(),
          upright: boolean(),
          east: id() | nil,
          west: id() | nil,
          north: id() | nil,
          south: id() | nil
        }

  defstruct row: 0, col: 0, upright: true, east: nil, west: nil, north: nil, south: nil
end
