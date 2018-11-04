defmodule MyRosProjectTest do
  use ExUnit.Case
  doctest MyRosProject

  test "greets the world" do
    assert MyRosProject.hello() == :world
  end
end
