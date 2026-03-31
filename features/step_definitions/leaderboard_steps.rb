Given("I am viewing a league leaderboard") do
  ensure_logged_in_user
  @league = create(:league)
  visit league_leaderboard_path(@league)
end

Then("I should see the leaderboard") do
  expect(page).to have_content("LEADERBOARD")
end
