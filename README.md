# CUHK Mock-Fund League

Rails 8.1 app with:

- PostgreSQL
- Devise authentication
- Solid Queue workers + recurring jobs
- Market data fetch pipeline (`python` + `yfinance`)

## Runtime Stack

- Ruby: `3.4.4` (see `.ruby-version`)
- Rails: `8.1.x`
- Database: PostgreSQL
- Queue: Solid Queue (DB-backed)
- Python deps: `requirements.txt` (`yfinance`, `pandas`)

## Local Hosting (Docker)

Use this for local development on your own machine.

### Start from zero

```bash
docker compose down -v --remove-orphans
docker compose up --build
```

App URL: `http://localhost:3000`

### Useful local commands

```bash
# Check service status
docker compose ps

# Follow worker logs (jobs service)
docker compose logs -f jobs

# Follow web logs
docker compose logs -f web
```

Note: Solid Queue worker logs are configured to STDOUT in development, so `docker compose logs -f jobs` should show scheduler/worker activity.

## Required Environment Variables (Production)

Set these before booting app/worker:

- `RAILS_ENV=production`
- `RAILS_MASTER_KEY=<your master key>`
- `DATABASE_URL=postgres://USER:PASS@HOST:5432/DBNAME`

Optional but recommended:

- `QUEUE_DATABASE_URL` (defaults to `DATABASE_URL`)
- `CACHE_DATABASE_URL` (defaults to `DATABASE_URL`)
- `CABLE_DATABASE_URL` (defaults to `DATABASE_URL`)
- `RAILS_MAX_THREADS=3`
- `WEB_CONCURRENCY=1`
- `JOB_CONCURRENCY=3`
- `PORT=3000` (or platform-provided)
- `RAILS_LOG_LEVEL=info`
- `SOLID_QUEUE_IN_PUMA=1` (run jobs in web process; usually keep `0` when using separate worker)
- `MARKET_DATA_PYTHON_BIN=/opt/market-data-venv/bin/python`

## First-Time Cloud Server Setup (Ubuntu VM)

Run once on a fresh server.

### 1) Install system packages

```bash
sudo apt-get update
sudo apt-get install -y git curl build-essential libpq-dev postgresql-client \
  libyaml-dev pkg-config python3 python3-venv libjemalloc2 libvips
```

### 2) Install rbenv + Ruby 3.4.4

```bash
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(rbenv init -)"' >> ~/.bashrc
source ~/.bashrc
rbenv install 3.4.4
rbenv global 3.4.4
gem install bundler
```

### 3) Clone project

```bash
git clone <your-repo-url> /var/www/cuhk-mock-fund-league
cd /var/www/cuhk-mock-fund-league
bundle config set without 'development test'
bundle install
```

### 4) Create Python virtual environment for market data

```bash
python3 -m venv /opt/market-data-venv
/opt/market-data-venv/bin/pip install --upgrade pip
/opt/market-data-venv/bin/pip install -r requirements.txt
```

### 5) Export environment variables

Example:

```bash
export RAILS_ENV=production
export RAILS_MASTER_KEY='<your-master-key>'
export DATABASE_URL='postgres://USER:PASS@HOST:5432/DBNAME'
export MARKET_DATA_PYTHON_BIN='/opt/market-data-venv/bin/python'
export RAILS_MAX_THREADS=3
export WEB_CONCURRENCY=1
export JOB_CONCURRENCY=3
```

Persist them in your process manager (`systemd`, platform env settings, or `/etc/environment`).

### 6) First-time DB setup + assets

```bash
bundle exec rails db:prepare
bundle exec rails db:migrate:queue
SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile
```

### 7) Start app + worker

Use `Procfile` process model:

- `release`: `bundle exec rails db:migrate db:migrate:queue`
- `web`: `bundle exec puma -C config/puma.rb`
- `worker`: `bundle exec bin/jobs`

Manual start example:

```bash
# terminal 1
bundle exec puma -C config/puma.rb

# terminal 2
bundle exec bin/jobs
```

## First Deploy Checklist (Must Run in Order)

```bash
cd /var/www/cuhk-mock-fund-league
git fetch origin
git checkout <deploy-branch>
git pull
bundle install
/opt/market-data-venv/bin/pip install -r requirements.txt
bundle exec rails db:migrate
bundle exec rails db:migrate:queue
SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile
```

Then restart:

- web process (`puma`)
- worker process (`bin/jobs`)

## Ongoing Deploy Commands (Every Release)

```bash
git pull
bundle install
/opt/market-data-venv/bin/pip install -r requirements.txt
bundle exec rails db:migrate
bundle exec rails db:migrate:queue
SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile
```

Restart app and worker after successful commands.

## Health and Smoke Checks

- Health check endpoint: `GET /up`
- Verify routes:
  ```bash
  bundle exec rails routes
  ```
- Verify jobs worker is running:
  - process exists for `bin/jobs`
  - recurring tasks from `config/recurring.yml` are being enqueued

## API Guide (`/api/v1`)

Authentication note:

- API controllers inherit app authentication (`before_action :authenticate_user!`)
- Current API auth is session/cookie based (Devise), not token/JWT.

### Leagues

- `GET /api/v1/leagues`  
  List leagues.
- `GET /api/v1/leagues/:id`  
  League details (includes members).
- `POST /api/v1/leagues`  
  Create league.
- `PATCH /api/v1/leagues/:id`  
  Update league.
- `DELETE /api/v1/leagues/:id`  
  Delete league.

### League Memberships (RESTful nested resource)

- `POST /api/v1/leagues/:league_id/memberships`  
  Join league (body includes `user_id`).
- `DELETE /api/v1/leagues/:league_id/memberships/:user_id`  
  Leave league.

### League Leaderboard

- `GET /api/v1/leagues/:league_id/leaderboard`  
  Read ranked standings for one league.

### Trades (RESTful nested resource)

- `POST /api/v1/portfolios/:portfolio_id/trades`  
  Create/execute trade under a portfolio.

Sample request body:

```json
{
  "trade": {
    "symbol": "AAPL",
    "trade_type": "buy",
    "order_type": "market",
    "quantity": 10,
    "price": 150.0
  }
}
```

### Stocks

- `GET /api/v1/stocks/:symbol`  
  Quote for symbol from DB-backed price service.
- `GET /api/v1/stocks/:symbol?interval=1h&limit=200`  
  Quote + candle data for requested interval.

## Queue and Recurring Jobs Notes

- Queue config: `config/queue.yml`
- Recurring schedule: `config/recurring.yml`
- In production:
  - run separate worker process (`bin/jobs`) **or**
  - set `SOLID_QUEUE_IN_PUMA=1` to run queue inside puma plugin

## Docker Deployment (Alternative)

This repo includes production Docker support.

```bash
docker build -t cuhk_mock_fund_league .
docker run -d -p 80:80 \
  -e RAILS_MASTER_KEY='<your-master-key>' \
  -e DATABASE_URL='postgres://USER:PASS@HOST:5432/DBNAME' \
  --name cuhk_mock_fund_league \
  cuhk_mock_fund_league
```

For container platforms, keep release step equivalent to:

```bash
bundle exec rails db:migrate db:migrate:queue
```

## Setup Guide (Run and Test)

Use these commands for TA/demo setup from a clean local environment:

```bash
docker compose down -v --remove-orphans
docker compose up --build -d
docker compose exec web bundle exec rails db:prepare
docker compose exec web bundle exec rails db:migrate
docker compose exec web bundle exec rails db:migrate:queue
```

Run test suites:

```bash
# RSpec test suite
docker compose exec web bundle exec rspec

# Cucumber feature tests (if needed)
docker compose exec web bundle exec cucumber
```

## Implemented Features and Ownership

The table below is used for individual contribution evaluation.

| Feature Name                            | Primary Developer (Name) | Secondary Developer | Notes                                                                         |
| --------------------------------------- | ------------------------ | ------------------- | ----------------------------------------------------------------------------- |
| User Authentication and Role Control    | Funnywai                 | Nokijai             | Based on git shortlog for auth-related files (Devise/user controllers/models) |
| League Management                       | Nokijai                  | jeremyting0727      | Based on git shortlog for leagues + league memberships files                  |
| Portfolio and Trading Engine            | Nokijai                  | tylertam228         | Based on git shortlog for portfolios/trades controllers and models            |
| Leaderboard and Ranking                 | Nokijai                  | tylertam228         | Based on git shortlog for leaderboard controllers/helpers/views/CSS           |
| Market Data Integration                 | Nokijai                  | Funnywai            | Based on git shortlog for stocks/services/Python fetch scripts                |
| Social Features (Friends and Messaging) | Ethannggggg              | x                   | Only one contributor found in git shortlog for social feature files           |
| Team and Membership Management          | Nokijai                  | jeremyting0727      | Based on git shortlog for team membership + league team files                 |
| API Endpoints (`/api/v1`)               | Ethannggggg              | Nokijai             | Based on git shortlog for app/controllers/api                                 |

## SimpleCov Report Screenshot

Include a screenshot of your SimpleCov coverage report in the repository (for example: `docs/simplecov-report.png`) and keep it updated.

![SimpleCov Coverage Report](docs/simplecov-report.png)
