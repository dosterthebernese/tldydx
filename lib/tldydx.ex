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

  @seconds24h 86400
  @seconds12h 43200
  @seconds6h 21600
  @seconds3h 10800
  @seconds1h 3600
  @markets URI.parse("https://api.dydx.exchange/v3/markets")
  @orderbook URI.parse("https://api.dydx.exchange/v3/orderbook")
  @pgcreds [
    hostname: "localhost",
    username: "postgres",
    password: "Z3tonium",
    database: "tradellama"
  ]

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
    {:ok, pid} = Postgrex.start_link(@pgcreds)

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

  defp get_dydx_range(pid, asset_pair, gtedate, ltdate) do
    IO.puts(asset_pair <> " " <> inspect(gtedate) <> " " <> inspect(ltdate))

    case Postgrex.prepare_execute(
           pid,
           "",
           "SELECT index_price, oracle_price, asset_pair, as_of FROM dydx WHERE asset_pair like $1 and as_of >= $2 and as_of < $3 order by as_of asc",
           [
             "%#{asset_pair}%",
             gtedate,
             ltdate
           ]
         ) do
      {:ok, _qry, res} ->
        res

      {:error, %Postgrex.Error{}} ->
        IO.puts("Error!")
        Process.exit(pid, :shutdown)
    end
  end

  def get_dydx(asset_pair, {:ok, ltdate} \\ DateTime.now("Etc/UTC")) do
    {:ok, pid} = Postgrex.start_link(@pgcreds)
    gtedate = DateTime.add(ltdate, -@seconds24h, :second)
    IO.puts(gtedate)
    IO.puts(ltdate)
    quotes = get_dydx_range(pid, asset_pair, gtedate, ltdate)
    IO.puts("number of rows: " <> " " <> "#{inspect(quotes.num_rows)}")

    pp_row = fn row ->
      inner_ltdate = Enum.at(row, 3)
      inner_gtedate = DateTime.add(inner_ltdate, -@seconds3h, :second)
      inner_quotes = get_dydx_range(pid, asset_pair, inner_gtedate, inner_ltdate)
      index_prices = Enum.map(inner_quotes.rows, &Enum.at(&1, 0))

      if inner_quotes.num_rows >= @seconds1h do
        stats_map = Statistex.statistics(index_prices)
        IO.puts("#{inspect(stats_map)}")
      else
        IO.puts(
          "Not enough predecessor trades in the database: " <>
            Integer.to_string(inner_quotes.num_rows) <>
            " rows.  Likely related to startup or a crash."
        )
      end
    end

    Enum.each(quotes.rows, &pp_row.(&1))

    Process.exit(pid, :shutdown)

    # case Postgrex.prepare_execute(
    #        pid,
    #        "",
    #        "SELECT index_price, oracle_price, asset_pair, as_of FROM dydx WHERE asset_pair like $1 and as_of < $2 order by as_of asc",
    #        [
    #          "%#{asset_pair}%",
    #          as_of
    #        ]
    #      ) do
    #   {:ok, _qry, res} ->
    #     IO.puts("ok" <> " " <> "#{inspect(res.num_rows)}")

    #     pp_row = fn row ->
    #       get_dydx_recursive(pid, asset_pair, {:ok, Enum.at(row, 3)})
    #     end

    #     Enum.each(res.rows, &pp_row.(&1))
    #     index_prices = Enum.map(res.rows, &Enum.at(&1, 0))
    #     # Enum.each(index_prices, fn ip -> IO.puts(ip) end)
    #     if res.num_rows > 0 do
    #       stats_map = Statistex.statistics(index_prices)
    #       IO.puts("#{inspect(stats_map)}")
    #     end

    #   {:error, %Postgrex.Error{}} ->
    #     IO.puts("end")
    # end
  end

  def build_database() do
    {:ok, pid} = Postgrex.start_link(@pgcreds)

    query =
      Postgrex.prepare!(
        pid,
        "",
        "CREATE TABLE dydx (id serial, asset_pair text, base_asset text, quote_asset text, index_price float, oracle_price float, price_change_24h float, volume_24h float, trades_24h float, open_interest float, asset_resolution float, as_of timestamptz)"
      )

    Postgrex.execute(pid, query, [])
  end

  def clean_database() do
    {:ok, pid} = Postgrex.start_link(@pgcreds)

    query = Postgrex.prepare!(pid, "", "DROP TABLE dydx")
    Postgrex.execute(pid, query, [])
  end

  def orderbook_markets() do
    markets_keys()
  end
end
