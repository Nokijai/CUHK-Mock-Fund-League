Feature: Trade Execution
  As a participant
  I want to execute virtual trades
  So that I can build my portfolio

  Scenario: View portfolio
    Given I have a portfolio
    When I visit my portfolio
    Then I should see "Portfolio"
