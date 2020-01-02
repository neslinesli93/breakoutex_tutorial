defmodule BreakoutexWeb.Live.Blocks do
  @moduledoc """
  Module that contains the definitions of all the block types,
  as well as functions to init the board
  """

  alias BreakoutexWeb.Live.Helpers

  # Expressed in multiple of basic units
  @brick_length 3

  @spec build_board(list(list(String.t())), number(), number()) :: [map()]
  def build_board(grid, width, height) do
    {_, blocks} =
      Enum.reduce(grid, {0, []}, fn row, {y_idx, acc} ->
        {_, blocks} =
          Enum.reduce(row, {0, acc}, fn
            "X", {x_idx, acc} ->
              {x_idx + 1, [wall(x_idx, y_idx, width, height) | acc]}

            "0", {x_idx, acc} ->
              {x_idx + 1, [empty(x_idx, y_idx, width, height) | acc]}

            "D", {x_idx, acc} ->
              {x_idx + 1, [floor(x_idx, y_idx, width, height) | acc]}

            b, {x_idx, acc} ->
              {x_idx + 1, [brick(b, @brick_length, x_idx, y_idx, width, height) | acc]}
          end)

        {y_idx + 1, blocks}
      end)

    blocks
  end

  @spec wall(number(), number(), number(), number()) :: map()
  defp wall(x_idx, y_idx, width, height) do
    %{
      type: :wall,
      left: Helpers.coordinate(x_idx, width),
      top: Helpers.coordinate(y_idx, height),
      width: width,
      height: height
    }
  end

  @spec floor(number(), number(), number(), number()) :: map()
  defp floor(x_idx, y_idx, width, height) do
    %{
      type: :floor,
      left: Helpers.coordinate(x_idx, width),
      top: Helpers.coordinate(y_idx, height),
      width: width,
      height: height
    }
  end

  @spec empty(number(), number(), number(), number()) :: map()
  defp empty(x_idx, y_idx, width, height) do
    %{
      type: :empty,
      left: Helpers.coordinate(x_idx, width),
      top: Helpers.coordinate(y_idx, height),
      width: width,
      height: height
    }
  end

  @spec brick(String.t(), number(), number(), number(), number(), number()) :: map()
  defp brick(color, brick_length, x_idx, y_idx, width, height) do
    %{
      type: :brick,
      color: get_color(color),
      width: width * brick_length,
      height: height,
      id: UUID.uuid4(),
      visible: true,
      left: Helpers.coordinate(x_idx, width),
      top: Helpers.coordinate(y_idx, height),
      right: Helpers.coordinate(x_idx, width) + width * brick_length,
      bottom: Helpers.coordinate(y_idx, height) + height
    }
  end

  @spec get_color(String.t()) :: String.t()
  defp get_color("r"), do: "red"
  defp get_color("b"), do: "blue"
  defp get_color("g"), do: "green"
  defp get_color("y"), do: "yellow"
  defp get_color("o"), do: "orange"
  defp get_color("p"), do: "purple"
  defp get_color("t"), do: "turquoise"
  defp get_color("w"), do: "white"
end
