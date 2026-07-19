import pathlib

import textutils


def test_registry_lists_every_module():
    pkg_dir = pathlib.Path(textutils.__file__).parent
    modules = sorted(
        p.stem for p in pkg_dir.glob("*.py") if p.stem != "__init__"
    )
    assert sorted(textutils.REGISTRY) == modules, (
        "textutils.REGISTRY must list every module in the package"
    )
