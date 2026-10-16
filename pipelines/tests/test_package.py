"""Test exemple du squelette : le paquet s'importe."""

import atlas_pipelines


def test_package_has_docstring() -> None:
    assert atlas_pipelines.__doc__ is not None
    assert atlas_pipelines.__doc__.strip() != ""
