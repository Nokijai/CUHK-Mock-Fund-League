Given("I am viewing a league leaderboard") do
  @league = create(:league)
  visit league_leaderboard_path(@league)
end

Then("I should see the leaderboard") do
  expect(page).to have_content("Leaderboard")
end
