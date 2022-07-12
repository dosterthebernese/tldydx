defmodule Mix.Tasks.Dmn do
  @moduledoc "Printed when the user requests 'mix help echo'"
  @shortdoc "Echoes arguments"

  use Mix.Task

  @impl Mix.Task

  def run(args) do
    TLDYDX.loop_markets()
    # Mix.shell().info(Enum.join(args, " "))
  end
end
