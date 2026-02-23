defmodule MazeWeb.MazeLive do
  @moduledoc """
  LiveView for displaying and regenerating mazes.

  Supports four grid types:
    - rectangular  — inset wall rendering, optional weaving
    - hexagonal    — pointy-top hex cells
    - triangular   — alternating up/down triangles
    - spectre      — aperiodic Smith–Myers–Kaplan–Goodman-Strauss monotile
  """

  use MazeWeb, :live_view

  alias Maze.Algorithms.RecursiveBacktracker
  alias Maze.Grid
  alias Maze.HexGrid
  alias Maze.SpectreGrid
  alias Maze.TriGrid
  alias MazeWeb.Components.HexMazeSvg
  alias MazeWeb.Components.MazeSvg
  alias MazeWeb.Components.SpectreMazeSvg
  alias MazeWeb.Components.TriMazeSvg

  @default_rows 30
  @default_cols 40
  @default_cell_size 25
  @default_weave_probability 0.3
  @default_grid_type :rectangular
  @default_show_shadows true
  @default_spectre_depth 3

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:rows, @default_rows)
      |> assign(:cols, @default_cols)
      |> assign(:cell_size, @default_cell_size)
      |> assign(:weave_probability, @default_weave_probability)
      |> assign(:grid_type, @default_grid_type)
      |> assign(:show_shadows, @default_show_shadows)
      |> assign(:spectre_depth, @default_spectre_depth)
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
            <label class="text-sm font-medium">Grid type</label>
            <select name="grid_type" class="select select-bordered">
              <option value="rectangular" selected={@grid_type == :rectangular}>Rectangular</option>
              <option value="hex" selected={@grid_type == :hex}>Hexagonal</option>
              <option value="tri" selected={@grid_type == :tri}>Triangular</option>
              <option value="spectre" selected={@grid_type == :spectre}>Spectre (aperiodic)</option>
            </select>
          </div>

          <div :if={@grid_type != :spectre} class="flex flex-col gap-1">
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

          <div :if={@grid_type != :spectre} class="flex flex-col gap-1">
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
              min="5"
              max="60"
              class="input input-bordered w-24"
            />
          </div>

          <div :if={@grid_type == :rectangular} class="flex flex-col gap-1">
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

          <div :if={@grid_type == :spectre} class="flex flex-col gap-1">
            <label class="text-sm font-medium">Depth (2–4)</label>
            <input
              type="number"
              name="spectre_depth"
              value={@spectre_depth}
              min="2"
              max="4"
              class="input input-bordered w-20"
            />
          </div>

          <button type="submit" class="btn btn-primary">Apply</button>
        </form>

        <div class="flex gap-2 items-center">
          <button phx-click="regenerate" class="btn btn-secondary">Regenerate</button>
          <button id="download-svg-btn" phx-hook=".DownloadSvg" class="btn btn-outline">
            Download SVG
          </button>
          <button
            :if={@grid_type == :rectangular}
            phx-click="toggle_shadows"
            class="btn btn-ghost btn-sm"
          >
            Shadows: {if @show_shadows, do: "on", else: "off"}
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
          <%= case @grid_type do %>
            <% :rectangular -> %>
              <MazeSvg.render grid={@grid} cell_size={@cell_size} show_shadows={@show_shadows} />
            <% :hex -> %>
              <HexMazeSvg.render grid={@grid} cell_size={@cell_size} />
            <% :tri -> %>
              <TriMazeSvg.render grid={@grid} cell_size={@cell_size} />
            <% :spectre -> %>
              <SpectreMazeSvg.render grid={@grid} cell_size={@cell_size} />
          <% end %>
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
  def handle_event("toggle_shadows", _params, socket) do
    {:noreply, assign(socket, :show_shadows, not socket.assigns.show_shadows)}
  end

  @impl true
  def handle_event("update_params", params, socket) do
    grid_type = parse_grid_type(params["grid_type"])

    socket =
      socket
      |> assign(:grid_type, grid_type)
      |> assign(:rows, parse_int(params["rows"], @default_rows, 5, 500))
      |> assign(:cols, parse_int(params["cols"], @default_cols, 5, 500))
      |> assign(:cell_size, parse_int(params["cell_size"], @default_cell_size, 5, 60))
      |> assign(
        :weave_probability,
        parse_float(params["weave_probability"], @default_weave_probability, 0.0, 1.0)
      )
      |> assign(
        :spectre_depth,
        parse_int(params["spectre_depth"], @default_spectre_depth, 2, 4)
      )
      |> generate_maze()

    {:noreply, socket}
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp generate_maze(socket) do
    %{
      rows: rows,
      cols: cols,
      grid_type: grid_type,
      weave_probability: weave_prob,
      spectre_depth: spectre_depth
    } = socket.assigns

    grid =
      case grid_type do
        :rectangular ->
          rows
          |> Grid.new(cols)
          |> RecursiveBacktracker.on(weave_probability: weave_prob)

        :hex ->
          rows
          |> HexGrid.new(cols)
          |> RecursiveBacktracker.on(weave_probability: 0.0)

        :tri ->
          rows
          |> TriGrid.new(cols)
          |> RecursiveBacktracker.on(weave_probability: 0.0)

        :spectre ->
          spectre_depth
          |> SpectreGrid.new()
          |> RecursiveBacktracker.on(start: 0, weave_probability: 0.0)
      end

    assign(socket, :grid, grid)
  end

  defp parse_grid_type("hex"), do: :hex
  defp parse_grid_type("tri"), do: :tri
  defp parse_grid_type("spectre"), do: :spectre
  defp parse_grid_type(_), do: :rectangular

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
