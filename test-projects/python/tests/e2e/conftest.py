"""
Mock conftest.py for pytest E2E tests.

This file serves as a marker for pytest E2E test detection in the aiq quality pipeline.
In a real project, this would contain pytest configuration and fixtures for end-to-end tests.

The presence of this file helps aiq detect that the project uses pytest for E2E testing,
allowing it to run the appropriate test commands during the quality pipeline.

Common fixtures defined in conftest.py files include:
- Database connections and cleanup
- Test user accounts and authentication
- API clients for backend testing
- Browser instances for UI testing
- Test data setup and teardown
"""

import pytest  # noqa: F401 - Required for pytest configuration
