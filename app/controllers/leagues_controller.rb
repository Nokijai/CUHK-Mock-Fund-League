class LeaguesController < ApplicationController
  before_action :set_league, only: [ :show, :edit, :update, :destroy ]

  def index
    # Use counter cache via left_joins + select to avoid loading all membership rows.
    @leagues = League
      .left_joins(:league_memberships)
      .group("leagues.id")
      .select("leagues.*, COUNT(league_memberships.id) AS memberships_count")
      # Preload users through memberships so "My team members" can render without N+1 queries.
      .includes(teams: { team_memberships: :user })
      .order(start_date: :asc, id: :asc)
    # Reuse preloaded memberships from ApplicationController nav context.
    @membership_by_league_id = current_user.league_memberships.index_by(&:league_id)
    @team_membership_by_league_id = TeamMembership.where(user_id: current_user.id).index_by(&:league_id)
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
    # League leader is the user who created the league (even though UI creation is typically admin-only).
    @league.creator = current_user
    if @league.save
      redirect_to @league, notice: "League was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
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

  def set_league
    @league = League.find(params[:id])
  end

  def league_params
    if action_name == "create"
      params.require(:league).permit(:name, :description, :starting_capital, :start_date, :end_date, :rules)
    else
      params.require(:league).permit(:name, :description, :start_date, :end_date)
    end
  end
end
