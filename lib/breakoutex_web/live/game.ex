defmodule BreakoutexWeb.Live.Game do
  @moduledoc """
  Main module, contains the entry point for the live view socket and
  all the game logic
  """

  use Phoenix.LiveView

  alias Phoenix.LiveView.Socket
  alias BreakoutexWeb.Live.{Blocks, Helpers}

  # Time in ms that schedules the game loop
  @tick 16
  # Width in pixels, used as the base for every type of block: bricks, paddle, walls, etc.
  # Every length param is expressed as an integer multiple of the basic unit
  @unit 20

  @board_rows 21
  @board_cols 26

  @level [
    ~w(X X X X X X X X X X X X X X X X X X X X X X X X X X),
    ~w(X 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 X),
    ~w(X 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 X),
    ~w(X r 0 0 r 0 0 r 0 0 r 0 0 r 0 0 r 0 0 r 0 0 r 0 0 X),
    ~w(X b 0 0 b 0 0 b 0 0 b 0 0 b 0 0 b 0 0 b 0 0 b 0 0 X),
    ~w(X g 0 0 g 0 0 g 0 0 g 0 0 g 0 0 g 0 0 g 0 0 g 0 0 X),
    ~w(X o 0 0 o 0 0 o 0 0 o 0 0 o 0 0 o 0 0 o 0 0 o 0 0 X),
    ~w(X p 0 0 p 0 0 p 0 0 p 0 0 p 0 0 p 0 0 p 0 0 p 0 0 X),
    ~w(X y 0 0 y 0 0 y 0 0 y 0 0 y 0 0 y 0 0 y 0 0 y 0 0 X),
    ~w(X 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 X),
    ~w(X 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 X),
    ~w(X 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 X),
    ~w(X 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 X),
    ~w(X 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 X),
    ~w(X 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 X),
    ~w(X 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 X),
    ~w(X 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 X),
    ~w(X 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 X),
    ~w(X 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 X),
    ~w(X 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 X),
    ~w(X 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 X),
    ~w(D D D D D D D D D D D D D D D D D D D D D D D D D D)
  ]

  # Coordinates of the top-left vertex of the paddle. They are relative to the board matrix
  @paddle_left 11
  @paddle_top 18
  # Paddle length/height expressed in basic units
  @paddle_length 5
  @paddle_height 1
  # Misc
  @paddle_speed 5

  @left_keys ["ArrowLeft", "KeyA"]
  @right_keys ["ArrowRight", "KeyD"]

  def render(assigns) do
    BreakoutexWeb.GameView.render("index.html", assigns)
  end

  @spec mount(map(), Socket.t()) :: {:ok, Socket.t()}
  def mount(_session, socket) do
    state = %{
      unit: @unit,
      tick: @tick,
      paddle: %{
        width: @paddle_length * @unit,
        height: @paddle_height * @unit,
        # Coordinates of the box surrounding the paddle
        left: Helpers.coordinate(@paddle_left, @unit),
        top: Helpers.coordinate(@paddle_top, @unit),
        right: Helpers.coordinate(@paddle_left + @paddle_length, @unit),
        bottom: Helpers.coordinate(@paddle_top + @paddle_height, @unit),
        # Misc
        direction: :stationary,
        speed: @paddle_speed,
        length: @paddle_length
      }
    }

    socket =
      socket
      |> assign(state)
      |> assign(:blocks, Blocks.build_board(@level, state.unit, state.unit))

    if connected?(socket) do
      {:ok, schedule_tick(socket)}
    else
      {:ok, socket}
    end
  end

  @spec schedule_tick(Socket.t()) :: Socket.t()
  defp schedule_tick(socket) do
    Process.send_after(self(), :tick, socket.assigns.tick)
    socket
  end

  @spec handle_info(atom(), Socket.t()) :: {:noreply, Socket.t()} | {:stop, Socket.t()}
  def handle_info(:tick, socket) do
    new_socket =
      socket
      |> game_loop()
      |> schedule_tick()

    {:noreply, new_socket}
  end

  @spec handle_event(String.t(), map(), Socket.t()) ::
          {:noreply, Socket.t()} | {:stop, Socket.t()}
  def handle_event("keydown", %{"code" => code}, socket) do
    {:noreply, on_input(socket, code)}
  end

  def handle_event("keyup", %{"code" => code}, socket) do
    {:noreply, on_stop_input(socket, code)}
  end

  @spec game_loop(Socket.t()) :: Socket.t()
  defp game_loop(socket) do
    socket
    |> advance_paddle()
  end

  @spec advance_paddle(Socket.t()) :: Socket.t()
  defp advance_paddle(%{assigns: %{paddle: paddle, unit: unit}} = socket) do
    case paddle.direction do
      :left -> assign(socket, :paddle, move_paddle_left(paddle, unit))
      :right -> assign(socket, :paddle, move_paddle_right(paddle, unit))
      :stationary -> socket
    end
  end

  @spec move_paddle_left(map(), number()) :: map()
  defp move_paddle_left(paddle, unit) do
    new_left = max(unit, paddle.left - paddle.speed)

    %{paddle | left: new_left, right: paddle.right - (paddle.left - new_left)}
  end

  @spec move_paddle_right(map(), number()) :: map()
  defp move_paddle_right(paddle, unit) do
    new_left = min(paddle.left + paddle.speed, unit * (@board_cols - paddle.length - 1))

    %{paddle | left: new_left, right: paddle.right + (new_left - paddle.left)}
  end

  # Handle keydown events
  @spec on_input(Socket.t(), String.t()) :: Socket.t()
  defp on_input(socket, key) when key in @left_keys,
    do: move_paddle(socket, :left)

  defp on_input(socket, key) when key in @right_keys,
    do: move_paddle(socket, :right)

  defp on_input(socket, _), do: socket

  # Handle keyup events
  @spec on_stop_input(Socket.t(), String.t()) :: Socket.t()
  defp on_stop_input(socket, key) when key in @left_keys,
    do: stop_paddle(socket, :left)

  defp on_stop_input(socket, key) when key in @right_keys,
    do: stop_paddle(socket, :right)

  defp on_stop_input(socket, _), do: socket

  @spec move_paddle(Socket.t(), :left | :right) :: Socket.t()
  defp move_paddle(%{assigns: %{paddle: paddle}} = socket, direction) do
    if paddle.direction == direction do
      socket
    else
      assign(socket, :paddle, %{paddle | direction: direction})
    end
  end

  @spec stop_paddle(Socket.t(), :left | :right) :: Socket.t()
  defp stop_paddle(%{assigns: %{paddle: paddle}} = socket, direction) do
    if paddle.direction == direction do
      assign(socket, :paddle, %{paddle | direction: :stationary})
    else
      socket
    end
  end
end
