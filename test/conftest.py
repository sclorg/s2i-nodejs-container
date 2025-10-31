import os
import sys

from collections import namedtuple
from pathlib import Path
from pytest import skip

from container_ci_suite.utils import check_variables

if not check_variables():
    sys.exit(1)

OS = os.getenv("TARGET").lower()
VERSION = os.getenv("VERSION")
IMAGE_TAG = "15-c9s"
PGSQL_IMAGE_TAG = f"postgresql:{IMAGE_TAG}"
DEPLOYED_PGSQL_IMAGE = f"quay.io/sclorg/{PGSQL_IMAGE_TAG}"
TAGS = {
    "rhel8": "-ubi8",
    "rhel9": "-ubi9",
    "rhel10": "-ubi10",
}
MYSQL_TAGS = {
    "rhel8": "-el8",
    "rhel9": "-el9",
    "rhel10": "-el10",
}

Vars = namedtuple("Vars", [
    "OS", "VERSION", "TAG", "MYSQL_TAG", "PGSQL_IMAGE_TAG",
    "DEPLOYED_PGSQL_IMAGE", "IMAGE_NAME", "IS_MINIMAL",
    "VERSION_NO_MINIMAL", "SHORT_VERSION", "TEST_DIR"
])


VARS = Vars(
    OS=OS,
    VERSION=VERSION,
    TAG=TAGS.get(OS),
    MYSQL_TAG=MYSQL_TAGS.get(OS),
    PGSQL_IMAGE_TAG=PGSQL_IMAGE_TAG,
    DEPLOYED_PGSQL_IMAGE=DEPLOYED_PGSQL_IMAGE,
    IMAGE_NAME=os.getenv("IMAGE_NAME"),
    IS_MINIMAL="minimal" in VERSION,
    VERSION_NO_MINIMAL=VERSION.replace("-minimal", ""),
    SHORT_VERSION=VERSION.replace("-minimal", "").replace(".", ""),
    TEST_DIR=Path(__file__).parent.absolute()
)


def skip_for_minimal():
    if "minimal" in VARS.VERSION:
        skip("This test is not available for NodeJS minimal container")
