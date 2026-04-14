Given("I have a portfolio") do
  # This scenario needs a user with both membership and portfolio access.
  @user = create(:user)
  @league = create(:league, start_date: 1.day.ago, end_date: 1.day.from_now)
  create(:league_membership, user: @user, league: @league)
  @portfolio = create(:portfolio, user: @user, league: @league)
  login_as(@user, scope: :user)
end

When("I visit my portfolio") do
  ensure_logged_in_user
  visit portfolio_path(@portfolio)
end
