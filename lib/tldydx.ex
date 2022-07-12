defmodule TLDYDX do
  @moduledoc """
  Documentation for `TLDYDX`.
  """

  @doc """
  Hello world.

  ## Examples

      iex> TLDYDX.hello()
      :world

  """

  @markets URI.parse("https://api.dydx.exchange/v3/markets")
  @orderbook URI.parse("https://api.dydx.exchange/v3/orderbook")

  def hello do
    :world
  end

  defp gurler_markets() do
    URI.parse(
      @markets
      |> to_string()
    )
  end

  defp gurler(gurls) do
    URI.parse(
      URI.merge(
        @orderbook,
        gurls
      )
      |> to_string()
    )
  end

  def markets() do
    gurl = gurler_markets()

    # IO.puts(gurl)

    case HTTPoison.get(gurl) do
      {:ok,
       %HTTPoison.Response{
         status_code: 200,
         body: body
       }} ->
        Poison.decode!(body)["markets"]

      {:ok, %HTTPoison.Response{status_code: 404}} ->
        IO.puts("Not found :(")

      {:error, %HTTPoison.Error{reason: reason}} ->
        IO.inspect(reason)
    end
  end

  def markets_keys() do
    Enum.sort(Map.keys(markets()))
  end

  def snapshot_markets() do
    {:ok, pid} =
      Postgrex.start_link(
        hostname: "localhost",
        username: "postgres",
        password: "Z3tonium",
        database: "tradellama"
      )

    pp_mkt = fn mkt ->
      {m, md} = mkt

      {_step_size, _stuff} = Float.parse(md["stepSize"])
      {_tick_size, _stuff} = Float.parse(md["tickSize"])
      {index_price, _stuff} = Float.parse(md["indexPrice"])
      {oracle_price, _stuff} = Float.parse(md["oraclePrice"])
      {price_change_24h, _stuff} = Float.parse(md["priceChange24H"])
      {volume_24h, _stuff} = Float.parse(md["volume24H"])
      {trades_24h, _stuff} = Float.parse(md["trades24H"])
      {open_interest, _stuff} = Float.parse(md["openInterest"])
      {asset_resolution, _stuff} = Float.parse(md["assetResolution"])
      {:ok, ndt} = DateTime.now("Etc/UTC")

      Postgrex.query(
        pid,
        "INSERT INTO dydx (asset_pair, base_asset, quote_asset, index_price, oracle_price, price_change_24h, volume_24h, trades_24h, open_interest, asset_resolution, as_of) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)",
        [
          m,
          md["baseAsset"],
          md["quoteAsset"],
          index_price,
          oracle_price,
          price_change_24h,
          volume_24h,
          trades_24h,
          open_interest,
          asset_resolution,
          ndt
        ]
      )
    end

    Enum.each(markets(), &pp_mkt.(&1))
    Process.exit(pid, :shutdown)
  end

  def get_dydx(asset_pair) do
    {:ok, pid} =
      Postgrex.start_link(
        hostname: "localhost",
        username: "postgres",
        password: "Z3tonium",
        database: "tradellama"
      )

    case Postgrex.prepare_execute(
           pid,
           "",
           "SELECT index_price, oracle_price, asset_pair, as_of FROM dydx WHERE asset_pair like $1 order by as_of",
           [
             "%#{asset_pair}%"
           ]
         ) do
      {:ok, _qry, res} ->
        IO.puts("ok" <> " " <> "#{inspect(res.rows)}")

        pp_row = fn row ->
          IO.puts("#{inspect(row)}")
        end

        Enum.each(res.rows, &pp_row.(&1))
        index_prices = Enum.map(res.rows, &Enum.at(&1, 0))
        Enum.each(index_prices, fn ip -> IO.puts(ip) end)
        stats_map = Statistex.statistics(index_prices)
        IO.puts("#{inspect(stats_map)}")

      {:error, %Postgrex.Error{}} ->
        IO.puts("end")
    end

    Process.exit(pid, :shutdown)
  end

  def build_database() do
    {:ok, pid} =
      Postgrex.start_link(
        hostname: "localhost",
        username: "postgres",
        password: "Z3tonium",
        database: "tradellama"
      )

    query =
      Postgrex.prepare!(
        pid,
        "",
        "CREATE TABLE dydx (id serial, asset_pair text, base_asset text, quote_asset text, index_price float, oracle_price float, price_change_24h float, volume_24h float, trades_24h float, open_interest float, asset_resolution float, as_of timestamptz)"
      )

    Postgrex.execute(pid, query, [])
  end

  def clean_database() do
    {:ok, pid} =
      Postgrex.start_link(
        hostname: "localhost",
        username: "postgres",
        password: "Z3tonium",
        database: "tradellama"
      )

    query = Postgrex.prepare!(pid, "", "DROP TABLE dydx")
    Postgrex.execute(pid, query, [])
  end

  def orderbook_markets() do
    markets_keys()
  end
end
