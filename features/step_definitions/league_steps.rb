Given("there is a league") do
  ensure_logged_in_user
  @league = create(:league)
end

When("I visit the leagues page") do
  ensure_logged_in_user
  visit leagues_path
end

Given("I am on the league creation page") do
  ensure_logged_in_user
  visit new_league_path
end
