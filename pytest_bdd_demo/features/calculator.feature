Feature: Calculator
  As a user
  I want to use a calculator
  So that I can perform basic arithmetic operations

Scenario: Add two numbers
  Given I have a calculator
  When I enter "5" and "3" into the calculator
  And I press add
  Then the result should be "8" on the screen

Scenario: Subtract two numbers
  Given I have a calculator
  When I enter "10" and "4" into the calculator
  And I press subtract
  Then the result should be "6" on the screen