ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.
require "bootsnap/setup" # Speed up boot time by caching expensive operations.

# Load .env file for local development
env_file = File.expand_path("../../.env", __dir__)

if %w[development test].include?(ENV.fetch("RAILS_ENV", "development")) && File.exist?(env_file)
  require "dotenv"
  Dotenv.load(env_file)
end
