def ensure_logged_in_user
  # Most pages are authenticated; keep scenarios focused on page behavior.
  @user ||= create(:user)
  login_as(@user, scope: :user)
end

Given("I am on the home page") do
  ensure_logged_in_user
  visit root_path
end

Given("I am a registered user") do
  @user = create(:user)
end

Then("I should see {string}") do |text|
  expect(page).to have_content(text)
end
