"""
Define fixtures and configuration
that can be reused throughout pytest without redefinition.
It also defines the configurations for pytest.
"""

import json
import pathlib
import pytest


@pytest.fixture
def test_case_json(request):
    file = pathlib.Path(request.node.fspath.strpath)
    test_case_json = file.with_name('static_test_case_values.json')
    return test_case_json
