# TLDYDX

This is an application suite for consuming data from DYDX public facing APIs.  

## Installation

You need Mongo  

https://www.mongodb.com/docs/manual/tutorial/install-mongodb-on-ubuntu/  

sudo systemctl start mongod  

sudo systemctl stop mongod  


Or because seems not prime time, you can use postgres  

https://ubuntu.com/server/docs/databases-postgresql  

sudo apt install postgresql  

sudo -u postgres psql  

create database tradellama  

sudo -u postgres psql tradellama

ALTER USER postgres with encrypted password 'Z3tonium';  

I ended up using postgres  


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

mix.deps.update --all  

mix.deps.clean --all  

mix deps.get  

mix compile  


