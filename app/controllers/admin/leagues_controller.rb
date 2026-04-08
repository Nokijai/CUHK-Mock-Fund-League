class Admin::LeaguesController < Admin::BaseController
  before_action :set_league, only: [ :edit, :update, :destroy ]

  def index
    @leagues = League.search_and_paginate(
      params[:search],
      %w[name],
      page: params[:page],
      per_page: 10
    )
  end

  def new
    @league = League.new
  end

  def create
    @league = League.new(league_params)
    # League leader is the creating user (admin creates leagues via this UI).
    @league.creator = current_user
    if @league.save
      redirect_to admin_leagues_path, notice: "League created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @league.update(league_params)
      redirect_to admin_leagues_path, notice: "League updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @league.destroy
    redirect_to admin_leagues_path, notice: "League deleted successfully."
  end

  private

  def set_league
    # Preload teams + members for admin roster moderation UI.
    @league = League.includes(teams: { team_memberships: :user }).find(params[:id])
  end

  def league_params
    # starting_capital + rule fields only on create; see League immutability validations.
    if action_name == "create"
      params.require(:league).permit(
        :name, :description, :start_date, :end_date, :starting_capital,
        :max_participants, :handling_fee_proportion, :minimum_final_balance,
        :team_mode, :team_max_participants, :team_min_participants
      )
    else
      params.require(:league).permit(:name, :description, :start_date, :end_date)
    end
  end
end
