defmodule MazeWeb.MazeLive do
  @moduledoc """
  LiveView for displaying and regenerating mazes.

  Renders a rectangular maze with weaving using the Recursive Backtracker
  algorithm.  Users can adjust grid size, cell size, and weave probability
  and click "Regenerate" to produce a new maze.
  """

  use MazeWeb, :live_view

  alias Maze.Algorithms.RecursiveBacktracker
  alias Maze.Grid
  alias MazeWeb.Components.MazeSvg

  @default_rows 30
  @default_cols 40
  @default_cell_size 25
  @default_weave_probability 0.3

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:rows, @default_rows)
      |> assign(:cols, @default_cols)
      |> assign(:cell_size, @default_cell_size)
      |> assign(:weave_probability, @default_weave_probability)
      |> generate_maze()

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="space-y-6">
        <h1 class="text-2xl font-bold">Maze Generator</h1>

        <form phx-submit="update_params" class="flex flex-wrap gap-4 items-end">
          <div class="flex flex-col gap-1">
            <label class="text-sm font-medium">Rows</label>
            <input
              type="number"
              name="rows"
              value={@rows}
              min="5"
              max="500"
              class="input input-bordered w-20"
            />
          </div>

          <div class="flex flex-col gap-1">
            <label class="text-sm font-medium">Cols</label>
            <input
              type="number"
              name="cols"
              value={@cols}
              min="5"
              max="500"
              class="input input-bordered w-20"
            />
          </div>

          <div class="flex flex-col gap-1">
            <label class="text-sm font-medium">Cell size (px)</label>
            <input
              type="number"
              name="cell_size"
              value={@cell_size}
              min="10"
              max="60"
              class="input input-bordered w-24"
            />
          </div>

          <div class="flex flex-col gap-1">
            <label class="text-sm font-medium">Weave probability</label>
            <input
              type="number"
              name="weave_probability"
              value={@weave_probability}
              min="0"
              max="1"
              step="0.05"
              class="input input-bordered w-24"
            />
          </div>

          <button type="submit" class="btn btn-primary">Apply</button>
        </form>

        <div class="flex gap-2">
          <button phx-click="regenerate" class="btn btn-secondary">Regenerate</button>
          <button id="download-svg-btn" phx-hook=".DownloadSvg" class="btn btn-outline">
            Download SVG
          </button>
        </div>

        <script :type={Phoenix.LiveView.ColocatedHook} name=".DownloadSvg">
          export default {
            mounted() {
              this.el.addEventListener("click", () => {
                const svg = document.querySelector("#maze-svg svg")
                const xml = new XMLSerializer().serializeToString(svg)
                const blob = new Blob([xml], { type: "image/svg+xml;charset=utf-8" })
                const url = URL.createObjectURL(blob)
                const a = document.createElement("a")
                a.href = url
                a.download = "maze.svg"
                document.body.appendChild(a)
                a.click()
                document.body.removeChild(a)
                URL.revokeObjectURL(url)
              })
            }
          }
        </script>

        <div id="maze-svg" class="overflow-auto">
          <MazeSvg.render grid={@grid} cell_size={@cell_size} />
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("regenerate", _params, socket) do
    {:noreply, generate_maze(socket)}
  end

  @impl true
  def handle_event("update_params", params, socket) do
    socket =
      socket
      |> assign(:rows, parse_int(params["rows"], @default_rows, 5, 500))
      |> assign(:cols, parse_int(params["cols"], @default_cols, 5, 500))
      |> assign(:cell_size, parse_int(params["cell_size"], @default_cell_size, 10, 60))
      |> assign(
        :weave_probability,
        parse_float(params["weave_probability"], @default_weave_probability, 0.0, 1.0)
      )
      |> generate_maze()

    {:noreply, socket}
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp generate_maze(socket) do
    grid =
      socket.assigns.rows
      |> Grid.new(socket.assigns.cols)
      |> RecursiveBacktracker.on(weave_probability: socket.assigns.weave_probability)

    assign(socket, :grid, grid)
  end

  defp parse_int(value, default, min, max) do
    case Integer.parse(to_string(value)) do
      {n, ""} -> n |> max(min) |> min(max)
      _ -> default
    end
  end

  defp parse_float(value, default, min, max) do
    case Float.parse(to_string(value)) do
      {f, ""} -> f |> max(min) |> min(max)
      _ -> default
    end
  end
end
