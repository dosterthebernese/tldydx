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
  @seconds2h 7200
  @seconds1h 3600
  @seconds10min 600
  @seconds5min 300
  @seconds30min 1800
  @margin_of_error 100
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
           "SELECT id, index_price, oracle_price, asset_pair, as_of FROM dydx WHERE asset_pair like $1 and as_of >= $2 and as_of < $3 order by as_of asc",
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
      parent_id = Enum.at(row, 0)
      parent_price = Enum.at(row, 1)
      inner_ltdate = Enum.at(row, 4)
      future_date10min = DateTime.add(inner_ltdate, @seconds10min, :second)
      future_date30min = DateTime.add(inner_ltdate, @seconds30min, :second)
      inner_gtedate = DateTime.add(inner_ltdate, -@seconds2h, :second)
      inner_quotes = get_dydx_range(pid, asset_pair, inner_gtedate, inner_ltdate)

      future_quotes10m =
        get_dydx_range(
          pid,
          asset_pair,
          future_date10min,
          DateTime.add(future_date10min, 5, :second)
        )

      future_quotes30m =
        get_dydx_range(
          pid,
          asset_pair,
          future_date30min,
          DateTime.add(future_date30min, 5, :second)
        )

      if inner_quotes.num_rows >= @seconds2h - @margin_of_error &&
           inner_quotes.num_rows <= @seconds2h + @margin_of_error &&
           future_quotes30m.num_rows >= 1 do
        index_prices = Enum.map(inner_quotes.rows, &Enum.at(&1, 1))
        index_prices_last_hour = Enum.slice(index_prices, @seconds1h, @seconds2h)
        stats_map2h = Statistex.statistics(index_prices)
        stats_map1h = Statistex.statistics(index_prices_last_hour)

        future_10min_price = Enum.at(Enum.at(future_quotes10m.rows, 0), 1)
        future_30min_price = Enum.at(Enum.at(future_quotes30m.rows, 0), 1)

        delta_10min = (future_10min_price - parent_price) / parent_price * 100.0
        delta_30min = (future_30min_price - parent_price) / parent_price * 100.0

        IO.puts("\ntwo hours prior: #{inspect(stats_map2h)}")
        IO.puts("\n one hour prior: #{inspect(stats_map1h)}\n\n")
        IO.puts("\n   10 min alist: #{inspect(future_quotes10m)}\n\n")
        IO.puts("\n   10 min after: #{inspect(future_10min_price)}\n\n")
        IO.puts("\n   10 min delta: #{inspect(delta_10min)}\n\n")
        IO.puts("\n   30 min alist: #{inspect(future_quotes30m)}\n\n")
        IO.puts("\n   30 min after: #{inspect(future_30min_price)}\n\n")
        IO.puts("\n   30 min delta: #{inspect(delta_30min)}\n\n")

        Postgrex.query(
          pid,
          "INSERT INTO dydxd (dydx_id, trailing_2h_average, trailing_2h_standard_deviation, trailing_2h_variance, trailing_2h_sample_size, trailing_1h_average, trailing_1h_standard_deviation, trailing_1h_variance, trailing_1h_sample_size, future_10min_price, future_30min_price, delta_10min, delta_30min) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)",
          [
            parent_id,
            stats_map2h.average,
            stats_map2h.standard_deviation,
            stats_map2h.variance,
            stats_map2h.sample_size,
            stats_map1h.average,
            stats_map1h.standard_deviation,
            stats_map1h.variance,
            stats_map1h.sample_size,
            future_10min_price,
            future_30min_price,
            delta_10min,
            delta_30min
          ]
        )
      else
        IO.puts(
          "Not enough predecessor trades in the database, or future quotes: " <>
            Integer.to_string(inner_quotes.num_rows) <>
            Integer.to_string(future_quotes30m.num_rows) <>
            " in prior and forward respectively.  Likely related to startup or a crash.  Note, this allows for +- 100 margin of error (seconds off, gap in http return in db)"
        )
      end
    end

    Enum.each(quotes.rows, &pp_row.(&1))

    Process.exit(pid, :shutdown)
  end

  def get_dydx_min(asset_pair, {:ok, ltdate} \\ DateTime.now("Etc/UTC")) do
    {:ok, pid} = Postgrex.start_link(@pgcreds)
    gtedate = DateTime.add(ltdate, -@seconds24h, :second)
    IO.puts(gtedate)
    IO.puts(ltdate)
    quotes = get_dydx_range(pid, asset_pair, gtedate, ltdate)
    IO.puts("number of rows: " <> " " <> "#{inspect(quotes.num_rows)}")

    pp_row = fn row ->
      parent_id = Enum.at(row, 0)
      parent_price = Enum.at(row, 1)
      inner_ltdate = Enum.at(row, 4)
      future_date5min = DateTime.add(inner_ltdate, @seconds5min, :second)
      future_date10min = DateTime.add(inner_ltdate, @seconds10min, :second)
      inner_gtedate = DateTime.add(inner_ltdate, -@seconds10min, :second)
      inner_quotes = get_dydx_range(pid, asset_pair, inner_gtedate, inner_ltdate)

      future_quotes5m =
        get_dydx_range(
          pid,
          asset_pair,
          future_date5min,
          DateTime.add(future_date5min, 5, :second)
        )

      future_quotes10m =
        get_dydx_range(
          pid,
          asset_pair,
          future_date10min,
          DateTime.add(future_date10min, 5, :second)
        )

      if inner_quotes.num_rows >= @seconds10min - @margin_of_error &&
           inner_quotes.num_rows <= @seconds10min + @margin_of_error &&
           future_quotes10m.num_rows >= 1 do
        index_prices = Enum.map(inner_quotes.rows, &Enum.at(&1, 1))
        index_prices_last_five_mins = Enum.slice(index_prices, @seconds5min, @seconds10min)
        stats_map10min = Statistex.statistics(index_prices)
        stats_map5min = Statistex.statistics(index_prices_last_five_mins)

        future_5min_price = Enum.at(Enum.at(future_quotes5m.rows, 0), 1)
        future_10min_price = Enum.at(Enum.at(future_quotes10m.rows, 0), 1)

        delta_5min = (future_5min_price - parent_price) / parent_price * 100.0
        delta_10min = (future_10min_price - parent_price) / parent_price * 100.0

        # IO.puts("\ntwo hours prior: #{inspect(stats_map2h)}")
        # IO.puts("\n one hour prior: #{inspect(stats_map1h)}\n\n")
        # IO.puts("\n   10 min alist: #{inspect(future_quotes10m)}\n\n")
        # IO.puts("\n   10 min after: #{inspect(future_10min_price)}\n\n")
        # IO.puts("\n   10 min delta: #{inspect(delta_10min)}\n\n")
        # IO.puts("\n   30 min alist: #{inspect(future_quotes30m)}\n\n")
        # IO.puts("\n   30 min after: #{inspect(future_30min_price)}\n\n")
        # IO.puts("\n   30 min delta: #{inspect(delta_30min)}\n\n")

        Postgrex.query(
          pid,
          "INSERT INTO dydxdmin (dydx_id, trailing_10min_average, trailing_10min_standard_deviation, trailing_10min_variance, trailing_10min_sample_size, trailing_5min_average, trailing_5min_standard_deviation, trailing_5min_variance, trailing_5min_sample_size, future_5min_price, future_10min_price, delta_5min, delta_10min) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)",
          [
            parent_id,
            stats_map10min.average,
            stats_map10min.standard_deviation,
            stats_map10min.variance,
            stats_map10min.sample_size,
            stats_map5min.average,
            stats_map5min.standard_deviation,
            stats_map5min.variance,
            stats_map5min.sample_size,
            future_5min_price,
            future_10min_price,
            delta_5min,
            delta_10min
          ]
        )
      else
        IO.puts(
          "Not enough predecessor trades in the database, or future quotes: " <>
            Integer.to_string(inner_quotes.num_rows) <>
            Integer.to_string(future_quotes10m.num_rows) <>
            " in prior and forward respectively.  Likely related to startup or a crash.  Note, this allows for +- 100 margin of error (seconds off, gap in http return in db)"
        )
      end
    end

    Enum.each(quotes.rows, &pp_row.(&1))

    Process.exit(pid, :shutdown)
  end

  def build_derivative_database() do
    {:ok, pid} = Postgrex.start_link(@pgcreds)

    query1 =
      Postgrex.prepare!(
        pid,
        "",
        "CREATE TABLE dydxd (dydx_id int references dydx(id), trailing_2h_average float, trailing_2h_standard_deviation float, trailing_2h_variance float, trailing_2h_sample_size integer, trailing_1h_average float, trailing_1h_standard_deviation float, trailing_1h_variance float, trailing_1h_sample_size integer, future_10min_price float, future_30min_price float, delta_10min float, delta_30min float)"
      )

    Postgrex.execute(pid, query1, [])

    query2 =
      Postgrex.prepare!(
        pid,
        "",
        "CREATE TABLE dydxdmin (dydx_id int references dydx(id), trailing_10min_average float, trailing_10min_standard_deviation float, trailing_10min_variance float, trailing_10min_sample_size integer, trailing_5min_average float, trailing_5min_standard_deviation float, trailing_5min_variance float, trailing_5min_sample_size integer, future_5min_price float, future_10min_price float, delta_5min float, delta_10min float)"
      )

    Postgrex.execute(pid, query2, [])
  end

  def build_database() do
    {:ok, pid} = Postgrex.start_link(@pgcreds)

    query =
      Postgrex.prepare!(
        pid,
        "",
        "CREATE TABLE dydx (id serial primary key, asset_pair text, base_asset text, quote_asset text, index_price float, oracle_price float, price_change_24h float, volume_24h float, trades_24h float, open_interest float, asset_resolution float, as_of timestamptz)"
      )

    Postgrex.execute(pid, query, [])
  end

  def clean_database() do
    {:ok, pid} = Postgrex.start_link(@pgcreds)

    query = Postgrex.prepare!(pid, "", "DROP TABLE dydx")
    Postgrex.execute(pid, query, [])
  end

  def clean_derivative_database() do
    {:ok, pid} = Postgrex.start_link(@pgcreds)

    query1 = Postgrex.prepare!(pid, "", "DROP TABLE dydxd")
    Postgrex.execute(pid, query1, [])
    query2 = Postgrex.prepare!(pid, "", "DROP TABLE dydxdmin")
    Postgrex.execute(pid, query2, [])
  end

  def optimize_database() do
    {:ok, pid} = Postgrex.start_link(@pgcreds)

    query1 =
      Postgrex.prepare!(
        pid,
        "",
        "create unique index asset_pair_as_of_idx on dydx (asset_pair, as_of)"
      )

    Postgrex.execute(pid, query1, [])

    query2 =
      Postgrex.prepare!(
        pid,
        "",
        "create index as_of_idx on dydx (as_of)"
      )

    Postgrex.execute(pid, query2, [])
  end

  def orderbook_markets() do
    markets_keys()
  end
end
