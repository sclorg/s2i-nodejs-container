import os
import sys

import pytest
from pathlib import Path

from container_ci_suite.helm import HelmChartsAPI
from container_ci_suite.utils import check_variables

if not check_variables():
    print("At least one variable from IMAGE_NAME, OS, VERSION is missing.")
    sys.exit(1)

test_dir = Path(os.path.abspath(os.path.dirname(__file__)))


class TestHelmRHELNodeJSImageStreams:

    def setup_method(self):
        package_name = "redhat-nodejs-imagestreams"
        path = test_dir
        self.hc_api = HelmChartsAPI(path=path, package_name=package_name, tarball_dir=test_dir)
        self.hc_api.clone_helm_chart_repo(
            repo_url="https://github.com/sclorg/helm-charts", repo_name="helm-charts",
            subdir="charts/redhat"
        )

    def teardown_method(self):
        self.hc_api.delete_project()

    @pytest.mark.parametrize(
        "version,registry,expected",
        [
            ("22-ubi9", "registry.redhat.io/ubi9/nodejs-22:latest", True),
            ("22-ubi9-minimal", "registry.redhat.io/ubi9/nodejs-22-minimal:latest", True),
            ("20-ubi9", "registry.redhat.io/ubi9/nodejs-20:latest", True),
            ("20-ubi9-minimal", "registry.redhat.io/ubi9/nodejs-20-minimal:latest", True),
            ("20-ubi8", "registry.redhat.io/ubi8/nodejs-20:latest", True),
            ("20-ubi8-minimal", "registry.redhat.io/ubi8/nodejs-20-minimal:latest", True),
            ("18-ubi9", "registry.redhat.io/ubi9/nodejs-18:latest", False),
            ("18-ubi9-minimal", "registry.redhat.io/ubi9/nodejs-18-minimal:latest", False),
            ("18-ubi8", "registry.redhat.io/ubi8/nodejs-18:latest", False),
            ("18-ubi8-minimal", "registry.redhat.io/ubi8/nodejs-18-minimal:latest", False),
        ],
    )
    def test_package_imagestream(self, version, registry, expected):
        assert self.hc_api.helm_package()
        assert self.hc_api.helm_installation()
        assert self.hc_api.check_imagestreams(version=version, registry=registry) == expected
