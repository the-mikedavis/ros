defmodule MyRosProject.MixProject do
  use Mix.Project

  def project do
    [
      app: :my_ros_project,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      msg: messages(),
      srv: srvs()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {MyRosProject.Application, []}
    ]
  end

  defp deps do
    [
      # use the hex/git path in your project, not this
      # this is just for my local dev setup
      {:ros, path: "../../../"}
    ]
  end

  defp messages do
    [
      "sensor_msgs/Image",
      {:pattern, "std_msgs"}
    ]
  end

  defp srvs do
    [
      {:pattern, "rospy_tutorials"}
    ]
  end
end
