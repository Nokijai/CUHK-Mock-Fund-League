# Devise test helpers - configure after devise:install
RSpec.configure do |config|
  # Use spaces (not tabs) so RuboCop Layout/IndentationStyle passes in CI.
  config.include Devise::Test::ControllerHelpers, type: :controller
  config.include Devise::Test::IntegrationHelpers, type: :request
end
