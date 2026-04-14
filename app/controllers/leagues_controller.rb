class LeaguesController < ApplicationController
  before_action :set_league, only: [ :show, :edit, :update, :destroy ]
  before_action :load_leagues_index_data, only: [ :index, :refresh ]

  def index
  end

  def refresh
    render :refresh, layout: false
  end

  def show
    # League details/actions now live on /leagues expandable cards to reduce context switching.
    redirect_to leagues_path(anchor: "league-#{@league.id}")
  end

  def new
    @league = League.new
  end

  def edit
  end

  def create
    @league = League.new(league_params)
    @league.enforce_management_time_rules = true
    # League leader is the user who created the league (even though UI creation is typically admin-only).
    @league.creator = current_user
    if @league.save
      redirect_to @league, notice: "League was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    @league.enforce_management_time_rules = true
    if @league.update(league_params)
      redirect_to @league, notice: "League was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @league.destroy
    redirect_to leagues_url, notice: "League was successfully destroyed."
  end

  private

  def load_leagues_index_data
    now = Time.current
    league_scope = League
      .left_joins(:league_memberships)
      .group("leagues.id")
      .select("leagues.*, COUNT(league_memberships.id) AS memberships_count")
      # Preload users through memberships so "My team members" can render without N+1 queries.
      .preload(teams: { team_memberships: :user })

    @current_or_upcoming_leagues = league_scope
      .where("end_date >= ?", now)
      .order(end_date: :asc, start_date: :asc, id: :asc)

    @past_leagues = league_scope
      .where("end_date < ?", now)
      .yield_self do |scope|
        if params[:search].present?
          apply_fuzzy_search(scope, [ "leagues.name" ], params[:search])
        else
          scope
        end
      end
      .order(start_date: :desc, id: :desc)
      .page(params[:page])
      .per(10)

    visible_league_ids = @current_or_upcoming_leagues.map(&:id) + @past_leagues.map(&:id)
    @portfolio_by_league_id = current_user.portfolios.where(league_id: visible_league_ids).index_by(&:league_id)

    # Reuse preloaded memberships from ApplicationController nav context.
    @membership_by_league_id = current_user.league_memberships.index_by(&:league_id)
    @team_membership_by_league_id = TeamMembership.where(user_id: current_user.id).index_by(&:league_id)
  end

  def set_league
    @league = League.find(params[:id])
  end

  def league_params
    params.require(:league).permit(
      :name, :description, :starting_capital, :start_date, :end_date,
      :max_participants, :handling_fee_proportion, :minimum_final_balance,
      :team_mode, :team_max_participants, :team_min_participants, :rules
    )
  end
end
