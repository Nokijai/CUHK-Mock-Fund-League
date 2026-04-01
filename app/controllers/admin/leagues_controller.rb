class Admin::LeaguesController < Admin::BaseController
  before_action :set_league, only: [:edit, :update, :destroy]

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
    @league = League.find(params[:id])
  end

  def league_params
    params.require(:league).permit(:name, :description, :start_date, :end_date, :starting_capital)
  end
end
