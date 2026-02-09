Given("I am on the home page") do
  visit root_path
end

Given("I am a registered user") do
  @user = create(:user)
end

Then("I should see {string}") do |text|
  expect(page).to have_content(text)
end
