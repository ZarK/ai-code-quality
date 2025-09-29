#!/usr/bin/env python3
"""Tests for main.py"""

import subprocess
import sys
from main import greet, calculate_sum


def test_greet() -> None:
    """Test the greet function."""
    assert greet("Alice") == "Hello, Alice!"
    assert greet("Bob") == "Hello, Bob!"


def test_calculate_sum() -> None:
    """Test the calculate_sum function."""
    assert calculate_sum([1, 2, 3]) == 6
    assert calculate_sum([]) == 0
    assert calculate_sum([10]) == 10


def test_main_execution() -> None:
    """Test the main execution block."""
    result = subprocess.run(
        [sys.executable, "main.py"],
        capture_output=True,
        text=True,
        cwd="test-projects/python",
    )
    assert result.returncode == 0
    assert "Hello, World!" in result.stdout
    assert "Sum: 15" in result.stdout
