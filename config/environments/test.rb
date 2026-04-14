# The test environment is used exclusively to run your application's
# test suite. You never need to work with it otherwise. Remember that
# your test database is "scratch space" for the test suite and is wiped
# and recreated between test runs. Don't rely on the data there!

Rails.application.configure do
  # When dotenv-rails loads `.env` in tests, it may contain Docker service hostnames (db).
  # Local test runs should use localhost unless explicitly overridden.
  #
  # IMPORTANT: prevent accidental truncation/purge of the development database when running
  # `db:test:*` tasks. Rails merges the special DATABASE_URL env var into the test connection
  # config unless we clear it.
  unless ENV["ALLOW_DATABASE_URL_IN_TEST"] == "true"
    %w[DATABASE_URL QUEUE_DATABASE_URL CACHE_DATABASE_URL CABLE_DATABASE_URL].each { |k| ENV.delete(k) }
  end

  unless File.exist?("/.dockerenv") || ENV["CI"].present?
    ENV["PGHOST"] = "localhost" if ENV["PGHOST"].to_s == "db"

    %w[DATABASE_URL QUEUE_DATABASE_URL CACHE_DATABASE_URL CABLE_DATABASE_URL].each do |key|
      next unless ENV[key].to_s.include?("@db")
      ENV.delete(key)
    end
  end

  # When running tests inside Docker, Postgres is normally reachable via the compose service hostname.
  # Use a dedicated env var so local (non-docker) test runs keep defaulting to localhost.
  ENV["PGHOST_TEST"] ||= "db" if File.exist?("/.dockerenv")

  # Configure 'rails notes' to inspect Cucumber files
  config.annotations.register_directories("features")
  config.annotations.register_extensions("feature") { |tag| /#\s*(#{tag}):?\s*(.*)$/ }

  # Settings specified here will take precedence over those in config/application.rb.

  # While tests run files are not watched, reloading is not necessary.
  config.enable_reloading = false

  # Eager loading loads your entire application. When running a single test locally,
  # this is usually not necessary, and can slow down your test suite. However, it's
  # recommended that you enable it in continuous integration systems to ensure eager
  # loading is working properly before deploying your code.
  config.eager_load = ENV["CI"].present?

  # Configure public file server for tests with cache-control for performance.
  config.public_file_server.headers = { "cache-control" => "public, max-age=3600" }

  # Request specs often hit `www.example.com` (Rack::Test default). Disable host authorization in test.
  config.hosts.clear

  # Show full error reports.
  config.consider_all_requests_local = true
  config.cache_store = :null_store

  # Render exception templates for rescuable exceptions and raise for other exceptions.
  config.action_dispatch.show_exceptions = :rescuable

  # Disable request forgery protection in test environment.
  config.action_controller.allow_forgery_protection = false

  # Store uploaded files on the local file system in a temporary directory.
  config.active_storage.service = :test

  # Tell Action Mailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  config.action_mailer.delivery_method = :test
  # Specs assert on ActionMailer::Base.deliveries; enable deliveries in test.
  config.action_mailer.perform_deliveries = true

  # Set host to be used by links generated in mailer templates.
  config.action_mailer.default_url_options = { host: "example.com" }

  # Request specs use www.example.com by default; allow it to avoid HostAuthorization 403s.
  config.hosts << "www.example.com"
  config.hosts << "example.com"

  # Print deprecation notices to the stderr.
  config.active_support.deprecation = :stderr

  # Raises error for missing translations.
  # config.i18n.raise_on_missing_translations = true

  # Annotate rendered view with file names.
  # config.action_view.annotate_rendered_view_with_filenames = true

  # Raise error when a before_action's only/except options reference missing actions.
  config.action_controller.raise_on_missing_callback_actions = true
end
