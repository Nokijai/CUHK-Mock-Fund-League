Given("I have a portfolio") do
  @user = create(:user)
  @league = create(:league)
  @portfolio = create(:portfolio, user: @user, league: @league)
end

When("I visit my portfolio") do
  visit portfolio_path(@portfolio)
end
