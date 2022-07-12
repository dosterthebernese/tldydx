defmodule Mix.Tasks.Dmn do
  @moduledoc "Printed when the user requests 'mix help echo'"
  @shortdoc "Echoes arguments"

  use Mix.Task

  @impl Mix.Task

  @an_absurdly_high_number 10_000_000_000

  def run(args) do
    case OptionParser.parse(args,
           strict: [looper: :boolean, cleaner: :boolean, builder: :boolean, snapper: :boolean]
         ) do
      {[looper: true], _, _} ->
        Application.ensure_all_started(:hackney)
        Application.ensure_all_started(:postgrex)

        Stream.iterate(0, &(&1 + 1))
        |> Enum.reduce_while(0, fn i, acc ->
          if i > @an_absurdly_high_number do
            {:halt, acc}
          else
            IO.puts(Integer.to_string(i) <> " " <> Integer.to_string(acc))
            Process.sleep(1000)
            Task.start(fn -> TLDYDX.snapshot_markets() end)
            {:cont, acc + 1}
          end
        end)

      {[snapper: true], _, _} ->
        Application.ensure_all_started(:hackney)
        Application.ensure_all_started(:postgrex)
        TLDYDX.snapshot_markets()

      {[cleaner: true], _, _} ->
        Application.ensure_all_started(:postgrex)
        TLDYDX.clean_database()

      {[builder: true], _, _} ->
        Application.ensure_all_started(:postgrex)
        TLDYDX.build_database()

      _ ->
        IO.puts(
          "I do not understand:  #{inspect(OptionParser.parse(args, strict: [looper: :boolean]))}"
        )
    end

    # Mix.shell().info(Enum.join(args, " "))
  end
end
