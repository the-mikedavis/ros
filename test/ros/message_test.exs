defmodule ROS.MessageTest do
  use ExUnit.Case
  doctest ROS.Message

  import ROS.Message

  test "std_msgs/Int32MultiArray deserialization" do
    data =
      <<0, 0, 0, 0, 0, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0>>

    assert %StdMsgs.Int32MultiArray{data: [0, 0, 0]} ==
             deserialize(data, StdMsgs.Int32MultiArray)
  end
end
