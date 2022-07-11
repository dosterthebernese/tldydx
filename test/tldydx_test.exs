defmodule TLDYDXTest do
  use ExUnit.Case
  doctest TLDYDX

  test "greets the world" do
    assert TLDYDX.hello() == :world
  end

  test "market pairs has not changed" do
    mkts = TLDYDX.markets()
    assert Enum.count(mkts) == 38
  end
end
