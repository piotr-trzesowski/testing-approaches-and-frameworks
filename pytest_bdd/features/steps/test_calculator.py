from pytest_bdd import scenarios, given, when, then, parsers
from calculator import Calculator
import logging

scenarios('calculator.feature')
logger = logging.getLogger(__name__)

@given("I have a calculator", target_fixture="calculator")
def calculator():
    logger.info("Creating calculator instance")
    return Calculator()

@when(parsers.parse('I enter "{a}" and "{b}" into the calculator'))
def enter_numbers(calculator, a, b):
    calculator.a = float(a)
    calculator.b = float(b)
    logger.info("Entered numbers: a=%s, b=%s", calculator.a, calculator.b)

@when("I press add")
def press_add(calculator):
    calculator.result = calculator.add(calculator.a, calculator.b)
    logger.info("Performed addition: %s + %s = %s", calculator.a, calculator.b, calculator.result)

@when("I press subtract")
def press_subtract(calculator):
    calculator.result = calculator.subtract(calculator.a, calculator.b)
    logger.info("Performed subtraction: %s - %s = %s", calculator.a, calculator.b, calculator.result)

@then(parsers.parse('the result should be "{expected}" on the screen'))
def verify_result(calculator, expected):
    logger.info("Verifying result: expected=%s, actual=%s", expected, calculator.result)
    assert calculator.result == float(expected)