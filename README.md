# TLDYDX

This is an application suite for consuming data from DYDX public facing APIs.  

## Installation

You need Mongo  

https://www.mongodb.com/docs/manual/tutorial/install-mongodb-on-ubuntu/


You need elixir  

https://elixir-lang.org/install.html#gnulinux  


If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `tldydx` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:tldydx, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/tldydx>.

You need to run  

mix deps.get  

mix compile  

iex -S mix  

TLDYDX.markets()  
