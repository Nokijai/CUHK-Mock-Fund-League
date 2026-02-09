Given("there is a league") do
  @league = create(:league)
end

When("I visit the leagues page") do
  visit leagues_path
end

Given("I am on the league creation page") do
  visit new_league_path
end
