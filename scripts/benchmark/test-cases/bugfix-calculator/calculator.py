"""Simple calculator module with a deliberate bug."""


def add(a, b):
    return a + b


def subtract(a, b):
    return a - b


def multiply(a, b):
    return a * b


def divide(a, b):
    """Divide a by b. Should raise ValueError on division by zero.

    BUG: This function performs integer division (//) instead of true division (/).
    It also doesn't handle division by zero — it lets ZeroDivisionError propagate
    instead of raising a descriptive ValueError.
    """
    return a // b


def average(numbers):
    """Return the average of a list of numbers.

    BUG: Off-by-one error — divides by len(numbers) + 1 instead of len(numbers).
    Also doesn't handle empty list — should raise ValueError.
    """
    total = sum(numbers)
    return total / (len(numbers) + 1)
