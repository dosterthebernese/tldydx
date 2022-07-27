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

#### postgres .env file

please create in main dir

GCPPOSTGRESIP=<get from gcp or localhost if on local machine etc>  
GCPPOSTGRESUSER="postgres"  
GCPPOSTGRESPASSWORD=<you need to set one>  
GCPPOSTGRESDB="tradellama"  



### To run on production  

mix Dmn --cleaner  

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

a_day_we_know_processed = DateTime.new(~D[2022-07-26], ~T[23:59:59.000], "Etc/UTC")  

TLDYDX.get_dydx("BTC-USD") 

TLDYDX.get_dydx("BTC-USD", a_day_we_know_processed)  




### for a quick demo, use defaults...it goes 10 mins earlier than now, for a range of 30 mins, with 10 back 10 forward

TLDYDX.get_dydx_min("BTC-USD")  


### To dump from prod for analytics local  

sudo -u postgres pg_dump -d tradellama -t dydx > dydx.sql  

scp -i "newllamaataws.pem" ubuntu@ec2-54-165-222-209.compute-1.amazonaws.com:/home/ubuntu/dumps/dydx.sql .  

sudo -u postgres psql -d tradellama -f dydx.sql  

the google version  

sudo -u postgres pg_dump -h 35.226.13.55 -d tradellama -t dydx > dydx.sql  

sudo -u postgres psql -d tradellama -f dydx.sql  



### To dump JUST the data

sudo -u postgres pg_dump --column-inserts --data-only --table=dydx tradellama > dydxdump.sql

### GCP postgres stuff

get your public ip  

dig +short myip.opendns.com @resolver1.opendns.com.  

on my home ubuntu, had to do this  

dig -4 +short myip.opendns.com @resolver1.opendns.com.

you will get your pub IP - add it to the GCP postgres cloud sql authorized networks  

sanity check  

psql "sslmode=disable dbname=postgres user=postgres hostaddr=35.226.13.55"  


### and since latest postges, from https://techviewleo.com/how-to-install-postgresql-database-on-ubuntu/  

sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'

wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -  

sudo apt -y update  

sudo apt -y install postgresql-14  

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



