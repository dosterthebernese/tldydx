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

  # if you don't pass it a proper date, and default to now, it'll always error, as the future numbers are not in place.
  def get_dydx(asset_pair, {:ok, ltdate} \\ DateTime.now("Etc/UTC")) do
    {:ok, pid} = Postgrex.start_link(@pgcreds)
    ### go back from start 24 hours for your rows to iterate
    gtedate = DateTime.add(ltdate, -@seconds24h, :second)
    ### for max, following 30 mins for data
    subservient_ltdate = DateTime.add(ltdate, @seconds30min, :second)
    ### for min, prior 2 hours for data
    subservient_gtedate = DateTime.add(gtedate, -@seconds2h, :second)

    IO.puts("  The bottom of the range to iterate is:  #{gtedate}")
    IO.puts("     The top of the range to iterate is:  #{ltdate}")
    IO.puts("The bottom of the lookback for stats is:  #{subservient_gtedate}")
    IO.puts("  The top of the lookahead for stats is:  #{subservient_ltdate}")

    # you are going to iterate this
    quotes = get_dydx_range(pid, asset_pair, gtedate, ltdate)
    IO.puts("            number of rows: " <> " " <> "#{inspect(quotes.num_rows)}")

    # rather than hit the database per each quote above, get the widest range you need, and then "walk" the appropriate ranges.
    subservient_quotes = get_dydx_range(pid, asset_pair, subservient_gtedate, subservient_ltdate)
    IO.puts("subservient number of rows: " <> " " <> "#{inspect(subservient_quotes.num_rows)}")

    # need the 24 hours you are iterating, plus the 30 mins forward and 2 hours back
    if subservient_quotes.num_rows <
         quotes.num_rows + @seconds30min + @seconds2h - @margin_of_error do
      raise "Oh no, not enough data yet!"
    end

    ### un comment me when you're feeling dumb
    #    raise "for now just read the stats above and grok"

    pp_row = fn rowwi ->
      {row, index} = rowwi
      IO.inspect(row)

      parent_id = Enum.at(row, 0)
      parent_price = Enum.at(row, 1)

      ### this stuff is fun to sanity check yourself...the time in current row should sandwich
      # IO.puts("#{parent_id} #{parent_price} #{index}")
      # prior_five_prices = Enum.slice(subservient_quotes.rows, index - 5, 5)
      # following_five_prices = Enum.slice(subservient_quotes.rows, index + 1, 5)
      # IO.inspect(prior_five_prices)
      # IO.inspect(following_five_prices)

      # its an index from the iterated rows, but you want to start at the backend of the subservient rows
      trailing_rows_2h = Enum.slice(subservient_quotes.rows, index, @seconds2h)
      trailing_rows_1h = Enum.slice(subservient_quotes.rows, index + @seconds1h, @seconds1h)

      future_10min_price =
        Enum.at(Enum.at(subservient_quotes.rows, index + @seconds2h + @seconds10min), 1)

      future_30min_price =
        Enum.at(Enum.at(subservient_quotes.rows, index + @seconds2h + @seconds30min), 1)

      index_prices_last_2_hours = Enum.map(trailing_rows_2h, &Enum.at(&1, 1))
      index_prices_last_1_hour = Enum.map(trailing_rows_1h, &Enum.at(&1, 1))
      stats_map2h = Statistex.statistics(index_prices_last_2_hours)
      stats_map1h = Statistex.statistics(index_prices_last_1_hour)

      delta_10min = (future_10min_price - parent_price) / parent_price * 100.0
      delta_30min = (future_30min_price - parent_price) / parent_price * 100.0

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
    end

    Enum.each(Enum.with_index(quotes.rows), &pp_row.(&1))

    Process.exit(pid, :shutdown)
  end

  # if you don't pass it a proper date, and default to now, it'll always error, as the future numbers are not in place.
  def get_dydx_min(asset_pair, {:ok, ltdate} \\ DateTime.now("Etc/UTC")) do
    {:ok, pid} = Postgrex.start_link(@pgcreds)
    ### go back from start 30 mins for your rows to iterate
    gtedate = DateTime.add(ltdate, -@seconds30min, :second)
    ### for max, following 10 mins for data
    subservient_ltdate = DateTime.add(ltdate, @seconds10min, :second)
    ### for min, prior 10 mins for data
    subservient_gtedate = DateTime.add(gtedate, -@seconds10min, :second)

    IO.puts("  The bottom of the range to iterate is:  #{gtedate}")
    IO.puts("     The top of the range to iterate is:  #{ltdate}")
    IO.puts("The bottom of the lookback for stats is:  #{subservient_gtedate}")
    IO.puts("  The top of the lookahead for stats is:  #{subservient_ltdate}")

    # you are going to iterate this
    quotes = get_dydx_range(pid, asset_pair, gtedate, ltdate)
    IO.puts("            number of rows: " <> " " <> "#{inspect(quotes.num_rows)}")

    # rather than hit the database per each quote above, get the widest range you need, and then "walk" the appropriate ranges.
    subservient_quotes = get_dydx_range(pid, asset_pair, subservient_gtedate, subservient_ltdate)
    IO.puts("subservient number of rows: " <> " " <> "#{inspect(subservient_quotes.num_rows)}")

    # need the 30 mins you are iterating, plus the 10 forward and 10 back
    if subservient_quotes.num_rows <
         quotes.num_rows + @seconds10min + @seconds10min - @margin_of_error do
      raise "Oh no, not enough data yet!"
    end

    ### un comment me when you're feeling dumb
    #    raise "for now just read the stats above and grok"

    pp_row = fn rowwi ->
      {row, index} = rowwi
      IO.inspect(row)

      parent_id = Enum.at(row, 0)
      parent_price = Enum.at(row, 1)

      ### this stuff is fun to sanity check yourself...the time in current row should sandwich
      # IO.puts("#{parent_id} #{parent_price} #{index}")
      # prior_five_prices = Enum.slice(subservient_quotes.rows, index - 5, 5)
      # following_five_prices = Enum.slice(subservient_quotes.rows, index + 1, 5)
      # IO.inspect(prior_five_prices)
      # IO.inspect(following_five_prices)

      trailing_rows_10 = Enum.slice(subservient_quotes.rows, index, @seconds10min)
      trailing_rows_5 = Enum.slice(subservient_quotes.rows, index + @seconds5min, @seconds5min)

      future_5min_price =
        Enum.at(Enum.at(subservient_quotes.rows, index + @seconds10min + @seconds5min), 1)

      future_10min_price =
        Enum.at(Enum.at(subservient_quotes.rows, index + @seconds10min + @seconds10min), 1)

      index_prices_last_10_mins = Enum.map(trailing_rows_10, &Enum.at(&1, 1))
      index_prices_last_5_mins = Enum.map(trailing_rows_5, &Enum.at(&1, 1))
      stats_map10min = Statistex.statistics(index_prices_last_10_mins)
      stats_map5min = Statistex.statistics(index_prices_last_5_mins)

      delta_5min = (future_5min_price - parent_price) / parent_price * 100.0
      delta_10min = (future_10min_price - parent_price) / parent_price * 100.0

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
    end

    Enum.each(Enum.with_index(quotes.rows), &pp_row.(&1))

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
