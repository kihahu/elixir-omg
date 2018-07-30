# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# By default, the umbrella project as well as each child
# application will require this configuration file, ensuring
# they all use the same configuration. While one could
# configure all applications here, we prefer to delegate
# back to each application for organization purposes.
import_config "../apps/*/config/config.exs"

# Sample configuration (overrides the imported configuration above):

config :logger, :console,
  # :info,
  level: :debug,
  # :infinity,
  truncate: 500_000,
  format: {OmiseGO.API.LoggerExt, :format},
  # format: "$date $time [$level] $metadata⋅$message⋅\n",
  metadata: [:module, :function, :line]

# config :logger,
#  compile_time_purge_matching: [
#    [application: :foo],
#    [module: Bar, function: "foo/3", level_lower_than: :error]
#  ]
import_config "#{Mix.env()}.exs"
