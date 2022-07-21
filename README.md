# TLDYDX

This is an application suite for consuming data from DYDX public facing APIs.  You will install Postgres, install Elixir, and pull this repo.  You will compile the repo, and run cleaner, builder, looper.  This will build a data set.  If doing a min (demo) run, wait 30 mins, and then you can use iex -S mix to invoke a quick terminal, to migrate some processed data.

## Installation


### Postgres
#### Sourced:

taken from: https://ubuntu.com/server/docs/databases-postgresql  


#### Steps:  

#### Ubuntu cmd line:  

sudo apt install postgresql  

sudo -u postgres psql  


#### Inside Psql:  

create database tradellama;  

ALTER USER postgres with encrypted password 'Z3tonium';  

#### validate

sudo -u postgres psql tradellama



### Elixir

note, had to force this at aws ubuntu, ubuntu 22.04, and still didn't work, so make aws 20.04 - for 1.13, newest ubuntu maps to 1.12  

lsb_release -a    

#### Sourced:

https://elixir-lang.org/install.html#gnulinux  

#### Steps:  
#### Ubuntu cmd line:  

wget https://packages.erlang-solutions.com/erlang-solutions_2.0_all.deb && sudo dpkg -i erlang-solutions_2.0_all.deb  

sudo apt-get update  

sudo apt-get install esl-erlang  

sudo apt-get install elixir  


### This Repo First Time
#### Ubuntu cmd line:  


git clone https://github.com/dosterthebernese/tldydx  

cd tldydx  

#### first time you will be prompted to install Hex, say yes, and same with rebar3

mix deps.get  

mix compile  

### To run on production  

mid Dmn --cleaner  

mix Dmn --builder  

mix Dmn --looper

nohup mix Dmn --looper &

#### useful to know

mix.deps.update --all  

mix.deps.clean --all  

mix deps.get  

mix compile  

### IEX Usage (when you know what you're doing and want to play)

iex -S mix  

TLDYDX.markets()  

a_day_we_know_processed = DateTime.new(~D[2022-07-14], ~T[23:59:59.000], "Etc/UTC")  

TLDYDX.get_dydx("BTC-USD") 

TLDYDX.get_dydx("BTC-USD", a_day_we_know_processed)  

### for a quick demo, use min (10 min and 5 min)  

TLDYDX.get_dydx_min("BTC-USD")  

note that you'll need to wait 20 mins, before data (plus minus 10 etc) will start to generate results  


### To dump from prod for analytics local  

sudo -u postgres pg_dump -d tradellama -t dydx > dydx.sql  

scp -i "newllamaataws.pem" ubuntu@ec2-54-165-222-209.compute-1.amazonaws.com:/home/ubuntu/dumps/dydx.sql .  

sudo -u postgres psql -d tradellama -f dydx.sql  


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



