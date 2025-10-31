import pytest

from container_ci_suite.helm import HelmChartsAPI

from conftest import VARS


class TestHelmRHELNodeJSImageStreams:

    def setup_method(self):
        package_name = "redhat-nodejs-imagestreams"
        self.hc_api = HelmChartsAPI(
            path=VARS.TEST_DIR,
            package_name=package_name,
            tarball_dir=VARS.TEST_DIR
            )
        self.hc_api.clone_helm_chart_repo(
            repo_url="https://github.com/sclorg/helm-charts", repo_name="helm-charts",
            subdir="charts/redhat"
        )

    def teardown_method(self):
        self.hc_api.delete_project()

    @pytest.mark.parametrize(
        "version,registry,expected",
        [
            ("22-ubi10", "registry.redhat.io/ubi10/nodejs-22:latest", True),
            ("22-ubi10-minimal", "registry.redhat.io/ubi10/nodejs-22-minimal:latest", True),
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
