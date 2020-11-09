defmodule SpicybotTest do
  use ExUnit.Case
  doctest Spicybot

  test "greets the world" do
    assert Spicybot.hello() == :world
  end
end
