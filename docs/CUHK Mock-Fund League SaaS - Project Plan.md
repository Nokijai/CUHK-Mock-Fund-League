# CUHK Mock-Fund League SaaS - Project Plan

## Project Overview

**Project Name:** CUHK Mock-Fund League SaaS Platform

**Description:** A virtual investment competition platform where organizations can host trading contests with custom rules. Each competition (League) has its own participants, rules, and starting capital.

**Team Size:** 4-5 students

**Tech Stack:** Ruby on Rails 7+, PostgreSQL, RSpec, Cucumber, GitHub Actions

**Deployment:** Public Cloud (Heroku/AWS)

---

## Core Features

### 1. Virtual Trading System

- **Buy/Sell Execution:** Users can execute virtual trades for stocks
- **Order Types:** Market orders, limit orders
- **Real-time Price Data Integration:** Connect to financial data API (e.g., Alpha Vantage, Yahoo Finance)
- **Trade History:** Complete audit trail of all transactions

### 2. Portfolio Management

- **Portfolio Valuation:** Real-time calculation of portfolio worth
- **Holdings Display:** Show current positions, quantities, and values
- **Cash Balance Tracking:** Monitor available cash and invested capital
- **Performance Metrics:** Calculate returns, gains/losses

### 3. League Management (SaaS Component)

- **League Creation:** Organizations can create custom competitions
- **Custom Rules Configuration:**
    - Starting capital amount
    - Trading restrictions (e.g., sector limits, position sizes)
    - Competition duration
    - Allowed instruments
- **Participant Management:** Invite/register users to specific leagues
- **League Isolation:** Each league operates independently

### 4. Leaderboard & Rankings

- **Real-time Rankings:** Display participant standings by portfolio value
- **Performance Metrics:** Show returns, win rates, trade frequency
- **Historical Rankings:** Track performance over time

### 5. Compliance & Disclaimers

- **Virtual Trading Notice:** Clear messaging that this is virtual trading only
- **User Agreement:** Terms of service for platform usage

---

## Technical Requirements

### Mandatory Components

**Framework:** Ruby on Rails 7+

**Database:** PostgreSQL (recommended for production scalability)

**Testing:**

- **Unit Tests:** RSpec
- **BDD Tests:** Cucumber
- **CI/CD:** GitHub Actions integration

**Version Control:** GitHub (private repo with TAs as collaborators)

**Deployment:** Publicly accessible via Heroku or AWS

---

## Development Approach

### Agile Methodology

- **Sprint Duration:** 1-2 weeks
- **Working Software Focus:** Prioritize functional features over extensive documentation
- **Iterative Development:** Build incrementally with regular deployments

### Test-Driven Development (TDD)

- Write tests before implementation
- Ensure high code coverage
- Automated testing in CI/CD pipeline

### Behavior-Driven Development (BDD)

- Define user stories and acceptance criteria
- Write Cucumber scenarios for key features
- Collaborate on feature specifications

---

## Project Timeline & Milestones

### Phase 1: Foundation (Weeks 1-2)

**Goal:** Set up project infrastructure and core models

**Tasks:**

- [ ]  Set up Rails project with Ruby 7+
- [ ]  Configure PostgreSQL database
- [ ]  Set up GitHub repository and invite TAs
- [ ]  Configure GitHub Actions for CI/CD
- [ ]  Set up RSpec and Cucumber
- [ ]  Deploy basic app to Heroku/AWS
- [ ]  Create core models: User, League, Portfolio, Trade

**Deliverable:** Deployed skeleton app with passing tests

---

### Phase 2: User Authentication & League Management (Weeks 3-4)

**Goal:** Implement multi-tenancy and league creation

**Tasks:**

- [ ]  User registration and authentication (Devise)
- [ ]  League creation interface
- [ ]  League configuration (starting capital, rules)
- [ ]  User roles (Admin, Participant)
- [ ]  League invitation system
- [ ]  Basic league dashboard

**User Stories:**

- As an organization admin, I can create a new league with custom rules
- As a user, I can register and join a league via invitation
- As a participant, I can view my league dashboard

**Deliverable:** Working league management system with authentication

---

### Phase 3: Virtual Trading Engine (Weeks 5-6)

**Goal:** Core trading functionality

**Tasks:**

- [ ]  Integrate financial data API
- [ ]  Stock search and price display
- [ ]  Buy/Sell order execution
- [ ]  Portfolio calculation logic
- [ ]  Cash balance management
- [ ]  Trade validation (sufficient funds, valid quantities)
- [ ]  Transaction history display

**User Stories:**

- As a participant, I can search for stocks and view current prices
- As a participant, I can buy stocks if I have sufficient cash
- As a participant, I can sell stocks I own
- As a participant, I can view my transaction history

**Deliverable:** Fully functional trading system

---

### Phase 4: Portfolio Valuation & Leaderboard (Weeks 7-8)

**Goal:** Real-time portfolio tracking and rankings

**Tasks:**

- [ ]  Portfolio valuation algorithm
- [ ]  Background job for periodic valuation updates
- [ ]  Leaderboard calculation and display
- [ ]  Performance metrics (ROI, gains/losses)
- [ ]  Historical performance charts
- [ ]  League-specific leaderboards

**User Stories:**

- As a participant, I can view my real-time portfolio value
- As a participant, I can see my ranking on the leaderboard
- As an admin, I can view all participant performances

**Deliverable:** Complete ranking and valuation system

---

### Phase 5: Polish & Compliance (Weeks 9-10)

**Goal:** UI/UX improvements and compliance features

**Tasks:**

- [ ]  Responsive design improvements
- [ ]  Add virtual trading disclaimers throughout app
- [ ]  Terms of service and user agreement
- [ ]  Email notifications for trades
- [ ]  League results and winner declaration
- [ ]  Admin analytics dashboard
- [ ]  Performance optimization
- [ ]  Security audit

**Deliverable:** Production-ready application

---

### Phase 6: Final Testing & Documentation (Weeks 11-12)

**Goal:** Comprehensive testing and project wrap-up

**Tasks:**

- [ ]  Complete test coverage review
- [ ]  End-to-end testing scenarios
- [ ]  Load testing
- [ ]  Bug fixes and refinements
- [ ]  README documentation
- [ ]  Deployment guide
- [ ]  Final presentation preparation

**Deliverable:** Fully tested and documented application

---

## Team Roles & Responsibilities

### Suggested Role Distribution (4-5 person team)

**Full-Stack Developer 1:** League Management & Authentication

- User authentication system
- League CRUD operations
- Multi-tenancy implementation

**Full-Stack Developer 2:** Trading Engine

- API integration for stock prices
- Trade execution logic
- Portfolio calculations

**Full-Stack Developer 3:** Leaderboard & Analytics

- Ranking algorithms
- Performance metrics
- Data visualization

**Full-Stack Developer 4:** UI/UX & Testing

- Frontend design and responsiveness
- Test writing (RSpec & Cucumber)
- CI/CD maintenance

**Optional 5th Member:** DevOps & Documentation

- Deployment management
- Performance optimization
- Documentation

*Note: All team members should contribute to testing and Git commits regularly*

---

## Rails Project Structure

```
mock-fund-league/
│
├── app/
│   ├── controllers/
│   │   ├── application_controller.rb
│   │   ├── home_controller.rb
│   │   ├── leagues_controller.rb
│   │   ├── league_memberships_controller.rb
│   │   ├── portfolios_controller.rb
│   │   ├── trades_controller.rb
│   │   ├── leaderboards_controller.rb
│   │   ├── stocks_controller.rb
│   │   └── api/
│   │       └── v1/
│   │           ├── trades_controller.rb
│   │           └── stock_prices_controller.rb
│   │
│   ├── models/
│   │   ├── application_record.rb
│   │   ├── user.rb
│   │   ├── league.rb
│   │   ├── league_membership.rb
│   │   ├── portfolio.rb
│   │   ├── holding.rb
│   │   ├── trade.rb
│   │   ├── stock_price.rb
│   │   └── concerns/
│   │       ├── validatable.rb
│   │       └── tradeable.rb
│   │
│   ├── views/
│   │   ├── layouts/
│   │   │   ├── application.html.erb
│   │   │   └── _navigation.html.erb
│   │   ├── home/
│   │   │   └── index.html.erb
│   │   ├── leagues/
│   │   │   ├── index.html.erb
│   │   │   ├── show.html.erb
│   │   │   ├── new.html.erb
│   │   │   ├── edit.html.erb
│   │   │   └── _form.html.erb
│   │   ├── portfolios/
│   │   │   ├── show.html.erb
│   │   │   └── _holdings.html.erb
│   │   ├── trades/
│   │   │   ├── index.html.erb
│   │   │   ├── new.html.erb
│   │   │   └── _trade_form.html.erb
│   │   ├── leaderboards/
│   │   │   └── show.html.erb
│   │   └── shared/
│   │       ├── _disclaimer.html.erb
│   │       └── _errors.html.erb
│   │
│   ├── services/
│   │   ├── stock_price_service.rb
│   │   ├── trade_execution_service.rb
│   │   ├── portfolio_valuation_service.rb
│   │   ├── leaderboard_service.rb
│   │   └── league_rules_validator.rb
│   │
│   ├── jobs/
│   │   ├── portfolio_valuation_job.rb
│   │   ├── stock_price_update_job.rb
│   │   └── leaderboard_update_job.rb
│   │
│   ├── mailers/
│   │   ├── application_mailer.rb
│   │   ├── user_mailer.rb
│   │   └── league_mailer.rb
│   │
│   ├── helpers/
│   │   ├── application_helper.rb
│   │   ├── portfolios_helper.rb
│   │   ├── trades_helper.rb
│   │   └── leaderboards_helper.rb
│   │
│   └── assets/
│       ├── stylesheets/
│       │   ├── application.css
│       │   ├── leagues.scss
│       │   ├── portfolios.scss
│       │   ├── trades.scss
│       │   └── leaderboards.scss
│       ├── javascript/
│       │   ├── application.js
│       │   ├── controllers/
│       │   │   ├── trade_controller.js
│       │   │   ├── portfolio_controller.js
│       │   │   └── leaderboard_controller.js
│       │   └── components/
│       │       ├── stock_search.js
│       │       └── chart.js
│       └── images/
│
├── config/
│   ├── application.rb
│   ├── database.yml
│   ├── routes.rb
│   ├── environments/
│   │   ├── development.rb
│   │   ├── test.rb
│   │   └── production.rb
│   ├── initializers/
│   │   ├── devise.rb
│   │   └── stock_api.rb
│   └── locales/
│       └── en.yml
│
├── db/
│   ├── migrate/
│   │   ├── 20260209_create_users.rb
│   │   ├── 20260209_create_leagues.rb
│   │   ├── 20260209_create_league_memberships.rb
│   │   ├── 20260209_create_portfolios.rb
│   │   ├── 20260209_create_holdings.rb
│   │   ├── 20260209_create_trades.rb
│   │   └── 20260209_create_stock_prices.rb
│   ├── schema.rb
│   └── seeds.rb
│
├── spec/
│   ├── rails_helper.rb
│   ├── spec_helper.rb
│   ├── models/
│   │   ├── user_spec.rb
│   │   ├── league_spec.rb
│   │   ├── portfolio_spec.rb
│   │   ├── holding_spec.rb
│   │   ├── trade_spec.rb
│   │   └── stock_price_spec.rb
│   ├── controllers/
│   │   ├── leagues_controller_spec.rb
│   │   ├── portfolios_controller_spec.rb
│   │   ├── trades_controller_spec.rb
│   │   └── leaderboards_controller_spec.rb
│   ├── services/
│   │   ├── stock_price_service_spec.rb
│   │   ├── trade_execution_service_spec.rb
│   │   ├── portfolio_valuation_service_spec.rb
│   │   └── leaderboard_service_spec.rb
│   ├── jobs/
│   │   ├── portfolio_valuation_job_spec.rb
│   │   └── stock_price_update_job_spec.rb
│   ├── requests/
│   │   ├── leagues_spec.rb
│   │   ├── portfolios_spec.rb
│   │   └── trades_spec.rb
│   ├── factories/
│   │   ├── users.rb
│   │   ├── leagues.rb
│   │   ├── portfolios.rb
│   │   ├── holdings.rb
│   │   └── trades.rb
│   └── support/
│       ├── factory_bot.rb
│       ├── database_cleaner.rb
│       └── devise.rb
│
├── features/
│   ├── support/
│   │   └── env.rb
│   ├── step_definitions/
│   │   ├── user_steps.rb
│   │   ├── league_steps.rb
│   │   ├── trading_steps.rb
│   │   └── leaderboard_steps.rb
│   └── scenarios/
│       ├── user_registration.feature
│       ├── league_creation.feature
│       ├── trade_execution.feature
│       ├── portfolio_view.feature
│       └── leaderboard_display.feature
│
├── lib/
│   ├── tasks/
│   │   ├── portfolio.rake
│   │   └── stock_prices.rake
│   └── api_clients/
│       ├── alpha_vantage_client.rb
│       └── yahoo_finance_client.rb
│
├── public/
│   ├── 404.html
│   ├── 422.html
│   ├── 500.html
│   └── favicon.ico
│
├── .github/
│   └── workflows/
│       ├── ci.yml
│       └── deploy.yml
│
├── .gitignore
├── Gemfile
├── Gemfile.lock
├── Rakefile
├── README.md
├── config.ru
└── .env.example
```

### Key Directory Explanations

**app/controllers/**

Handles HTTP requests and responses. Organized by resource (leagues, portfolios, trades). API controllers in `api/v1/` namespace for potential future API access.

**app/models/**

ActiveRecord models representing database tables. Concerns folder for shared behavior (validations, trade logic).

**app/services/**

Business logic layer. Each service handles a specific domain operation:

- `StockPriceService`: Fetches and caches stock prices from external API
- `TradeExecutionService`: Validates and executes buy/sell orders
- `PortfolioValuationService`: Calculates current portfolio worth
- `LeaderboardService`: Computes rankings and standings
- `LeagueRulesValidator`: Validates trades against league-specific rules

**app/jobs/**

Background jobs using ActiveJob (with Sidekiq or similar):

- `PortfolioValuationJob`: Periodic portfolio value updates
- `StockPriceUpdateJob`: Refresh stock prices from API
- `LeaderboardUpdateJob`: Recalculate rankings

**app/views/**

ERB templates for HTML rendering. Partials (prefixed with `_`) for reusable components.

**spec/**

RSpec test files mirroring the app structure:

- `models/`: Unit tests for models
- `controllers/`: Controller action tests
- `services/`: Business logic tests
- `requests/`: Integration tests
- `factories/`: FactoryBot test data generators

**features/**

Cucumber BDD feature files and step definitions:

- `.feature` files: Human-readable scenarios
- `step_definitions/`: Ruby code implementing feature steps

**lib/**

Custom libraries and rake tasks:

- `api_clients/`: Wrappers for external API integrations
- `tasks/`: Custom rake commands for maintenance

**.github/workflows/**

GitHub Actions CI/CD configuration:

- `ci.yml`: Run tests on pull requests
- `deploy.yml`: Deploy to production on merge

---

## Database Schema Overview

### Core Models

**User**

- email, password, name, role

**League**

- name, description, starting_capital, start_date, end_date, rules (JSON)

**LeagueMembership**

- user_id, league_id, joined_at

**Portfolio**

- user_id, league_id, cash_balance, total_value

**Holding**

- portfolio_id, symbol, quantity, average_cost

**Trade**

- portfolio_id, symbol, trade_type (buy/sell), quantity, price, executed_at

**StockPrice** (cache)

- symbol, price, updated_at

---

## API Integration Options

### Stock Price Data Providers

**Option 1: Alpha Vantage** (Recommended)

- Free tier: 500 calls/day
- Real-time and historical data
- API key required

**Option 2: Yahoo Finance API**

- Unofficial but widely used
- Free access
- Good for prototyping

**Option 3: IEX Cloud**

- Free tier available
- Reliable and well-documented
- Production-ready

---

## Testing Strategy

### Unit Tests (RSpec)

- Model validations
- Business logic
- Helper methods
- Service objects

### Integration Tests (RSpec)

- Controller actions
- API endpoints
- Database interactions

### Feature Tests (Cucumber)

- User registration and login
- League creation workflow
- Trading execution flow
- Leaderboard display
- Complete user journeys

### GitHub Actions Pipeline

```yaml
- Run RSpec tests
- Run Cucumber tests
- Code coverage check (>80%)
- Deploy to staging on PR merge
- Deploy to production on main merge
```

---

## Deployment Checklist

### Heroku Deployment

- [ ]  Create Heroku app
- [ ]  Add PostgreSQL addon
- [ ]  Configure environment variables (API keys)
- [ ]  Set up automatic deployments from GitHub
- [ ]  Configure custom domain (optional)
- [ ]  Enable SSL

### AWS Deployment (Alternative)

- [ ]  Set up EC2 instance or Elastic Beanstalk
- [ ]  Configure RDS PostgreSQL
- [ ]  Set up Load Balancer
- [ ]  Configure S3 for assets
- [ ]  Set up CloudFront CDN
- [ ]  Configure environment variables

---

## Risk Mitigation

### Risk 1: API Rate Limits

**Mitigation:** Cache stock prices, implement smart refresh strategy, use multiple API providers as fallback

### Risk 2: Complex League Rules

**Mitigation:** Start with basic rules (starting capital only), iterate with advanced rules in later phases

### Risk 3: Real-time Performance

**Mitigation:** Use background jobs for heavy calculations, implement caching strategy, optimize database queries

### Risk 4: Git Audit Requirements

**Mitigation:** Enforce regular commits, use meaningful commit messages, ensure all team members contribute equally

### Risk 5: TDD/BDD Learning Curve

**Mitigation:** Allocate extra time in Phase 1 for learning, pair programming sessions, code reviews

---

## Success Criteria

✅ **Functional Requirements**

- Users can register and join leagues
- Organizations can create custom leagues
- Participants can execute virtual trades
- Portfolio values update in real-time
- Leaderboard displays accurate rankings

✅ **Technical Requirements**

- Ruby on Rails 7+ framework
- PostgreSQL database
- RSpec and Cucumber tests with >80% coverage
- GitHub Actions CI/CD pipeline
- Publicly accessible deployment

✅ **Agile Requirements**

- Regular Git commits from all team members
- Working software at each sprint
- Iterative development visible in Git history

✅ **Compliance**

- Clear "Virtual Trading Only" disclaimers
- Terms of service implemented

---

## Resources & References

### Documentation

- **Rails Guides:** [https://guides.rubyonrails.org/](https://guides.rubyonrails.org/)
- **RSpec Documentation:** [https://rspec.info/](https://rspec.info/)
- **Cucumber Documentation:** [https://cucumber.io/docs/](https://cucumber.io/docs/)

### Tutorials

- **TDD with Rails:** Search for "Rails TDD tutorial"
- **BDD with Cucumber:** Rails + Cucumber integration guides
- **Financial APIs:** Alpha Vantage documentation

### Tools

- **Project Management:** GitHub Projects, Trello
- **Communication:** Slack, Discord
- **Code Review:** GitHub Pull Requests

---

## Next Steps

1. **Team Formation:** Assemble your 4-5 person team
2. **Role Assignment:** Distribute roles based on strengths
3. **Repository Setup:** Create GitHub repo and invite TAs
4. **Kickoff Meeting:** Review this plan and adjust timeline
5. **Sprint 1 Planning:** Define first sprint user stories
6. **Start Coding:** Begin Phase 1 tasks

---

> **Important Reminder:** Your development history will be audited. Ensure regular, meaningful commits from all team members throughout the project. Focus on working software over lengthy documentation!
>