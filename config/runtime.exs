import Config
config :iex, default_prompt: ">>>"

if Config.config_env() == :dev do
  DotenvParser.load_file(".env")
end
