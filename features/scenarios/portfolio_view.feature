Feature: Portfolio View
  As a participant
  I want to view my portfolio
  So that I can see my holdings and performance

  Scenario: View portfolio holdings
    Given I have a portfolio
    When I visit my portfolio
    Then I should see "Cash Balance"
