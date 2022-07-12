# TLDYDX

This is an application suite for consuming data from DYDX public facing APIs.  

## Installation

https://ubuntu.com/server/docs/databases-postgresql  

sudo apt install postgresql  

sudo -u postgres psql  

sudo -u postgres psql tradellama

create database tradellama;  

ALTER USER postgres with encrypted password 'Z3tonium';  

I ended up using postgres  


You need elixir  

note, had to force this at aws ubuntu, ubuntu 22.04, and still didn't work, so make aws 20.04 - for 1.13, newest ubuntu maps to 1.12  

lsb_release -a    

https://elixir-lang.org/install.html#gnulinux  

wget https://packages.erlang-solutions.com/erlang-solutions_2.0_all.deb && sudo dpkg -i erlang-solutions_2.0_all.deb  

sudo apt-get update  

sudo apt-get install esl-erlang  

sudo apt-get install elixir  

git clone https://github.com/dosterthebernese/tldydx  

You need to run  

first time you will be prompted to install Hex, say yes, same rebar3

mix deps.get  

mix compile  

iex -S mix  

TLDYDX.markets()  

mix.deps.update --all  

mix.deps.clean --all  

mix deps.get  

mix compile  

### To run on production  

There is a task, Dmn, so you can run  

nohup mix Dmn --looper &


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



