"""
Module to contain all tests pertaining to traffic simulator.
"""
from napp import write_populate_script, write_ping_test, write_curl_test


def test_population_creation(tmp_path, test_case_json):
    """
    Test if the population creation script correctly adds UEs with slice information.
    
    Parameters
    -----------
        tmp_path: Pytest fixture
            creates a temporary path that gets cleared post pytest.
        
        test_case_json: Pytest fixture
            json file that simulates the actual test case json used in the traffic simulation.
    
    Outputs
    --------
        None (Pytest)
    """

    direct = tmp_path / "sub"
    direct.mkdir()
    test_file = direct / "test_script.sh"

    write_populate_script(script_file=test_file, test_case_file=test_case_json)

    with open(test_file, "r") as read_file:
        script_truth = read_file.read()
    assert (
        script_truth
        == "open5gs-dbctl add_ue_with_slice 999700000000001 465B5CE8B199B49FAA5F0A2EE238A6BC E8ED289DEBA952E4283B54E88E6183CA internet 1 111111 \n"
    )


def test_ping_script_creation(tmp_path, test_case_json):
    """
    Test if the ping script correctly adds ping per UE to a .sh file.
    Inputs:
        tmp_path: Fixture
            creates a temporary path that gets cleared post pytest.
        test_case_json: Fixture
            json file that simulates the actual test case json used in the traffic simulation.
    Outputs: None (pytest)
    """
    direct = tmp_path / "sub"
    direct.mkdir()
    test_file = direct / "test_script.sh"

    write_ping_test(script_file=test_file, test_case_file=test_case_json)
    
    with open(test_file, "r") as read_file:
        script_truth = read_file.read()
    assert "ping -I uesimtun0" in script_truth


def test_curl_script_creation(tmp_path, test_case_json):
    """
    Test if the curl script correctly adds curl per UE to a .sh file.
    Inputs:
        tmp_path: Fixture
            creates a temporary path that gets cleared post pytest.
        test_case_json: Fixture
            json file that simulates the actual test case json used in the traffic simulation.
    Outputs: None (pytest)
    """
    direct = tmp_path / "sub"
    direct.mkdir()
    test_file = direct / "test_script.sh"

    write_curl_test(script_file=test_file, test_case_file=test_case_json)

    with open(test_file, "r") as read_file:
        script_truth = read_file.read()
    assert "curl --output /dev/null --interface uesimtun0" in script_truth
