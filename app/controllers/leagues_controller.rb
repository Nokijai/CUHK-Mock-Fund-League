class LeaguesController < ApplicationController
  before_action :set_league, only: [ :show, :edit, :update, :destroy ]

  def index
    @leagues = League.includes(:league_memberships).order(start_date: :asc, id: :asc)
    # Build quick lookup maps for current user membership/action rendering on index cards.
    @membership_by_league_id = current_user.league_memberships.where(league_id: @leagues.map(&:id)).index_by(&:league_id)
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
    params.require(:league).permit(:name, :description, :starting_capital, :start_date, :end_date, :rules)
  end
end
