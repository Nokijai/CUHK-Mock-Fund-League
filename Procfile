release: bundle exec rails db:migrate db:migrate:queue
web: bundle exec puma -C config/puma.rb
worker: bundle exec bin/jobs
