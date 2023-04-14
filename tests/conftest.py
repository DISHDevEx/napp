"""
Define fixtures and configuration that can be reused throughout pytest without redefinition.
It also defines the configurations for pytest.
"""

import pathlib
import pytest


@pytest.fixture
def test_case_json(request):
    """
    Fixture that allows a static json file to emulate test case json that is used in traffic simulator. 
    """
    file = pathlib.Path(request.node.fspath.strpath)
    test_case_json = file.with_name("static_test_case_values.json")
    return test_case_json
