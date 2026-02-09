Feature: League Creation
  As an organization admin
  I want to create a new league with custom rules
  So that I can host a trading competition

  Scenario: View leagues list
    Given I am on the home page
    When I visit the leagues page
    Then I should see "Leagues"
