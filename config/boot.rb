ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.
require "bootsnap/setup" # Speed up boot time by caching expensive operations.

# Load .env file for local development only (not in test/CI environments)
if (ENV["RAILS_ENV"] || ENV["RACK_ENV"] || "development") == "development" && !ENV["CI"]
  require "dotenv"
  env_path = File.expand_path("../.env", __dir__)
  Dotenv.load(env_path) if File.exist?(env_path)
end
