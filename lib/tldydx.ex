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
  @a_little_sumpin 10
  @markets URI.parse("https://api.dydx.exchange/v3/markets")
  @orderbook URI.parse("https://api.dydx.exchange/v3/orderbook")

  # @pgcredsProd [
  #   hostname: System.fetch_env!("GCPPOSTGRESIP"),
  #   username: System.fetch_env!("GCPPOSTGRESUSER"),
  #   password: System.fetch_env!("GCPPOSTGRESPASSWORD"),
  #   database: System.fetch_env!("GCPPOSTGRESDB")
  # ]

  def wtf do
    get_pg_creds()
  end

  defp get_pg_creds do
    [
      hostname: System.fetch_env!("LOCALPOSTGRESIP"),
      username: System.fetch_env!("LOCALPOSTGRESUSER"),
      password: System.fetch_env!("LOCALPOSTGRESPASSWORD"),
      database: System.fetch_env!("LOCALPOSTGRESDB")
    ]

    # [
    #   hostname: System.fetch_env!("GCPPOSTGRESIP"),
    #   username: System.fetch_env!("GCPPOSTGRESUSER"),
    #   password: System.fetch_env!("GCPPOSTGRESPASSWORD"),
    #   database: System.fetch_env!("GCPPOSTGRESDB")
    # ]
  end

  def hello do
    IO.inspect(System.fetch_env!("GCPPOSTGRESIP") == "This is a\nmultiline value.")
    IO.inspect(System.fetch_env!("GCPPOSTGRESIP") == "35.226.13.55")
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
    {:ok, pid} = Postgrex.start_link(get_pg_creds())

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
  def get_dydx(
        asset_pair,
        iterate_range \\ @seconds30min,
        back_and_forward_range \\ @seconds10min,
        {:ok, ltdateraw} \\ DateTime.now("Etc/UTC")
      ) do
    #    back_and_forward_range_halved = @seconds10min / 2
    # need as integer dummy
    back_and_forward_range_halved = div(back_and_forward_range, 2)
    ltdate = DateTime.add(ltdateraw, -(back_and_forward_range + @a_little_sumpin), :second)

    {:ok, pid} = Postgrex.start_link(get_pg_creds())
    gtedate = DateTime.add(ltdate, -iterate_range, :second)
    subservient_ltdate = DateTime.add(ltdate, back_and_forward_range + @a_little_sumpin, :second)
    subservient_gtedate = DateTime.add(gtedate, -back_and_forward_range, :second)

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

    # need the mins you are iterating, plus the forward and back
    if subservient_quotes.num_rows <
         quotes.num_rows + back_and_forward_range + back_and_forward_range - @margin_of_error do
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

      trailing_rows_bigger = Enum.slice(subservient_quotes.rows, index, back_and_forward_range)

      IO.puts(index + back_and_forward_range_halved)

      trailing_rows_halved =
        Enum.slice(
          subservient_quotes.rows,
          index + back_and_forward_range_halved,
          back_and_forward_range_halved
        )

      future_halved =
        Enum.at(
          Enum.at(
            subservient_quotes.rows,
            index + back_and_forward_range + back_and_forward_range_halved
          ),
          1
        )

      future_bigger =
        Enum.at(
          Enum.at(
            subservient_quotes.rows,
            index + back_and_forward_range + back_and_forward_range
          ),
          1
        )

      index_prices_bigger = Enum.map(trailing_rows_bigger, &Enum.at(&1, 1))
      index_prices_halved = Enum.map(trailing_rows_halved, &Enum.at(&1, 1))
      stats_map_bigger = Statistex.statistics(index_prices_bigger)
      stats_map_halved = Statistex.statistics(index_prices_halved)

      delta_bigger = (future_bigger - parent_price) / parent_price * 100.0
      delta_halved = (future_halved - parent_price) / parent_price * 100.0

      pres =
        Postgrex.query(
          pid,
          "INSERT INTO dydxd (dydx_id, bfr, trailing_average, trailing_standard_deviation, trailing_variance, trailing_sample_size, trailing_halved_average, trailing_halved_standard_deviation, trailing_halved_variance, trailing_halved_sample_size, future_halved_price, future_price, delta, delta_halved) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14)",
          [
            parent_id,
            back_and_forward_range,
            stats_map_bigger.average,
            stats_map_bigger.standard_deviation,
            stats_map_bigger.variance,
            stats_map_bigger.sample_size,
            stats_map_halved.average,
            stats_map_halved.standard_deviation,
            stats_map_halved.variance,
            stats_map_halved.sample_size,
            future_halved,
            future_bigger,
            delta_halved,
            delta_bigger
          ]
        )

      IO.inspect(pres)
    end

    Enum.each(Enum.with_index(quotes.rows), &pp_row.(&1))

    Process.exit(pid, :shutdown)
  end

  def build_derivative_database() do
    {:ok, pid} = Postgrex.start_link(get_pg_creds())

    query1 =
      Postgrex.prepare!(
        pid,
        "",
        "CREATE TABLE dydxd (dydx_id int references dydx(id), bfr int, trailing_average float, trailing_standard_deviation float, trailing_variance float, trailing_sample_size integer, trailing_halved_average float, trailing_halved_standard_deviation float, trailing_halved_variance float, trailing_halved_sample_size integer, future_price float, future_halved_price float, delta float, delta_halved float)"
      )

    Postgrex.execute(pid, query1, [])
  end

  def build_database() do
    {:ok, pid} = Postgrex.start_link(get_pg_creds())

    query =
      Postgrex.prepare!(
        pid,
        "",
        "CREATE TABLE dydx (id serial primary key, asset_pair text, base_asset text, quote_asset text, index_price float, oracle_price float, price_change_24h float, volume_24h float, trades_24h float, open_interest float, asset_resolution float, as_of timestamptz)"
      )

    Postgrex.execute(pid, query, [])
  end

  def clean_database() do
    {:ok, pid} = Postgrex.start_link(get_pg_creds())

    query = Postgrex.prepare!(pid, "", "DROP TABLE dydx")
    Postgrex.execute(pid, query, [])
  end

  def clean_derivative_database() do
    {:ok, pid} = Postgrex.start_link(get_pg_creds())

    query1 = Postgrex.prepare!(pid, "", "DROP TABLE dydxd")
    Postgrex.execute(pid, query1, [])
  end

  def optimize_database() do
    {:ok, pid} = Postgrex.start_link(get_pg_creds())

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
