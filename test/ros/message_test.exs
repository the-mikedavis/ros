defmodule ROS.MessageTest do
  use ExUnit.Case
  doctest ROS.Message

  import ROS.Message, only: [deserialize: 2]

  describe "std_msgs deserialization," do
    test "Int32MultiArray" do
      data =
        <<0, 0, 0, 0, 0, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
          0>>

      assert %StdMsgs.Int32MultiArray{data: [0, 0, 0]} ==
               deserialize(data, StdMsgs.Int32MultiArray)
    end

    test "Expanding Strings" do
      data =
        RealData.pub_sending_expanded_strings()
        |> Enum.map(&deserialize(&1, StdMsgs.String))

      expanding_strings =
        0..17
        |> Enum.map(&repeat("a", &1))
        |> Enum.map(fn str -> %StdMsgs.String{data: str} end)

      assert data == expanding_strings
    end

    test "ColorRGBA" do
      assert deserialize(RealData.pub_sending_color(), StdMsgs.ColorRGBA) ==
               %StdMsgs.ColorRGBA{r: 22.0, g: 33.0, b: 44.0, a: 0.0}
    end
  end

  defp repeat(character, times) when times >= 0 do
    _repeat(character, times, "")
  end

  defp _repeat(_char, 0, acc), do: acc
  defp _repeat(char, t, acc), do: _repeat(char, t - 1, acc <> char)
end
