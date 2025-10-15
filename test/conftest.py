import os
import sys

from collections import namedtuple
from pathlib import Path
from pytest import skip

from container_ci_suite.utils import check_variables

if not check_variables():
    sys.exit(1)

Vars = namedtuple("Vars", [
    "OS", "VERSION", "IMAGE_NAME", "IS_MINIMAL", "VERSION_NO_MINIMAL", "SHORT_VERSION", "TEST_DIR"
])
VERSION = os.getenv("VERSION")
VARS = Vars(
    OS=os.getenv("TARGET").lower(),
    VERSION=VERSION,
    IMAGE_NAME=os.getenv("IMAGE_NAME"),
    IS_MINIMAL="minimal" in VERSION,
    VERSION_NO_MINIMAL=VERSION.replace("-minimal", ""),
    SHORT_VERSION=VERSION.replace("-minimal", "").replace(".", ""),
    TEST_DIR=Path(__file__).parent.absolute()
)

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

DEPLOYED_PGSQL_IMAGE = "quay.io/sclorg/postgresql-15-c9s"

PGSQL_IMAGE_TAG = "postgresql:15-c9s"
IMAGE_TAG = "15-c9s"

def skip_for_minimal():
    if "minimal" in VERSION:
        skip("This test is not available for NodeJS minimal container")

