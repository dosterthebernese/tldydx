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

  test "get_one_dydx" do
    {:ok, conn} = Mongo.start_link(url: "mongodb://localhost:27017/tradellama")
    result = Mongo.find_one(conn, "dydx", %{})
    # IO.puts("#{inspect(result)}\n")
    assert(is_float(result["index_price"]))
  end
end
