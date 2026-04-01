ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.
require "bootsnap/setup" # Speed up boot time by caching expensive operations.

# Load local .env only in development, never in test/CI.
env_file = File.expand_path("../.env", __dir__)
rails_env = ENV.fetch("RAILS_ENV", ENV.fetch("RACK_ENV", "development"))
if rails_env == "development" && !ENV["CI"] && File.exist?(env_file)
  require "dotenv"
<<<<<<< HEAD
  Dotenv.load(env_file)
=======
  env_path = File.expand_path("../.env", __dir__)
  Dotenv.load(env_path) if File.exist?(env_path)
>>>>>>> 67b1954 (Update config/boot.rb)
end
