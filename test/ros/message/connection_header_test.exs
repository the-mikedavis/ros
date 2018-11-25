defmodule ROS.Message.ConnectionHeaderTest do
  use ExUnit.Case

  import ROS.Message.ConnectionHeader, only: [parse: 1]

  describe "parse a conn header from a" do
    test "subscriber" do
      data = RealData.conn_header_from_subscriber()

      assert parse(data) ==
               %ROS.Message.ConnectionHeader{
                 callerid: "/listener_9489_1536626375574",
                 md5sum: "992ce8a1687cec8c8bd883ec73ca41d1",
                 message_definition: "string data\n",
                 topic: "/chatter",
                 type: "std_msgs/String"
               }
    end

    test "multiarray subscriber" do
      data = RealData.another_huge_conn_header()

      assert parse(data) ==
               %ROS.Message.ConnectionHeader{
                 callerid: "/talker_13944_1539641597410",
                 md5sum: "1d99f79f8b325b44fee908053e9c945b",
                 message_definition:
                   "# Please look at the MultiArrayLayout message definition for\n# documentation on all multiarrays.\n\nMultiArrayLayout  layout        # specification of data layout\nint32[]           data          # array of data\n\n\n================================================================================\nMSG: std_msgs/MultiArrayLayout\n# The multiarray declares a generic multi-dimensional array of a\n# particular data type.  Dimensions are ordered from outer most\n# to inner most.\n\nMultiArrayDimension[] dim # Array of dimension properties\nuint32 data_offset        # padding elements at front of data\n\n# Accessors should ALWAYS be written in terms of dimension stride\n# and specified outer-most dimension first.\n# \n# multiarray(i,j,k) = data[data_offset + dim_stride[1]*i + dim_stride[2]*j + k]\n#\n# A standard, 3-channel 640x480 image with interleaved color channels\n# would be specified as:\n#\n# dim[0].label  = \"height\"\n# dim[0].size   = 480\n# dim[0].stride = 3*640*480 = 921600  (note dim[0] stride is just size of image)\n# dim[1].label  = \"width\"\n# dim[1].size   = 640\n# dim[1].stride = 3*640 = 1920\n# dim[2].label  = \"channel\"\n# dim[2].size   = 3\n# dim[2].stride = 3\n#\n# multiarray(i,j,k) refers to the ith row, jth column, and kth channel.\n\n================================================================================\nMSG: std_msgs/MultiArrayDimension\nstring label   # label of given dimension\nuint32 size    # size of given dimension (in type units)\nuint32 stride  # stride of given dimension",
                 topic: "/chatter",
                 type: "std_msgs/Int32MultiArray"
               }
    end
  end
end
