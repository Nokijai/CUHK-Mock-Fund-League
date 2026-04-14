class Admin::LeaguesController < Admin::BaseController
  before_action :set_league, only: [ :edit, :update, :destroy ]
  before_action :ensure_league_editable, only: [ :edit, :update, :destroy ]

  def index
    @leagues = League.all

    @search_query = params[:search].to_s.strip
    if @search_query.present?
      @leagues = apply_fuzzy_search(@leagues, [ "name" ], @search_query)
    end

    @start_after = params[:start_after].to_s.strip
    if @start_after.present?
      begin
        start_after_date = Date.iso8601(@start_after)
        @leagues = @leagues.where("start_date >= ?", start_after_date.beginning_of_day)
      rescue ArgumentError
        # Ignore invalid start date filter input and render unfiltered by start date.
      end
    end

    @end_before = params[:end_before].to_s.strip
    if @end_before.present?
      begin
        end_before_date = Date.iso8601(@end_before)
        @leagues = @leagues.where("end_date <= ?", end_before_date.end_of_day)
      rescue ArgumentError
        # Ignore invalid end date filter input and render unfiltered by end date.
      end
    end

    @leagues = @leagues.order(start_date: :desc, id: :desc).page(params[:page]).per(10)
  end

  def new
    @league = League.new
  end

  def create
    @league = League.new(league_params)
    @league.enforce_management_time_rules = true
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
    @league.enforce_management_time_rules = true
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
    params.require(:league).permit(
      :name, :description, :start_date, :end_date, :starting_capital,
      :max_participants, :handling_fee_proportion, :minimum_final_balance,
      :team_mode, :team_max_participants, :team_min_participants
    )
  end

  def ensure_league_editable
    return if @league.start_date.blank? || @league.start_date > Time.current

    redirect_to admin_leagues_path, alert: "Started or ended leagues cannot be edited or deleted."
  end
end
