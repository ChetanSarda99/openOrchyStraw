"""Tests for calculator — these define the EXPECTED correct behavior.

The agent should fix calculator.py so all these tests pass.
"""

import pytest
from calculator import add, subtract, multiply, divide, average


def test_add():
    assert add(2, 3) == 5
    assert add(-1, 1) == 0
    assert add(0, 0) == 0


def test_subtract():
    assert subtract(5, 3) == 2
    assert subtract(0, 0) == 0


def test_multiply():
    assert multiply(3, 4) == 12
    assert multiply(-2, 3) == -6
    assert multiply(0, 100) == 0


def test_divide():
    assert divide(10, 3) == pytest.approx(3.3333, rel=1e-3)
    assert divide(1, 2) == 0.5
    assert divide(-6, 2) == -3.0


def test_divide_by_zero():
    with pytest.raises(ValueError, match="cannot divide by zero"):
        divide(1, 0)


def test_average():
    assert average([1, 2, 3]) == pytest.approx(2.0)
    assert average([10]) == 10.0
    assert average([0, 0, 0]) == 0.0


def test_average_empty():
    with pytest.raises(ValueError, match="empty"):
        average([])
