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

VERSION = os.getenv("VERSION")
IMAGE_NAME = os.getenv("IMAGE_NAME")
OS = os.getenv("TARGET")

TAGS = {
    "rhel8": "-ubi8",
    "rhel9": "-ubi9"
}
TAG = TAGS.get(OS, None)


class TestHelmNodeJSApplication:

    def setup_method(self):
        package_name = "redhat-nodejs-application"
        path = test_dir
        self.hc_api = HelmChartsAPI(path=path, package_name=package_name, tarball_dir=test_dir)
        self.hc_api.clone_helm_chart_repo(
            repo_url="https://github.com/sclorg/helm-charts", repo_name="helm-charts",
            subdir="charts/redhat"
        )

    def teardown_method(self):
        self.hc_api.delete_project()

    def test_curl_connection(self):
        if self.hc_api.oc_api.shared_cluster:
            pytest.skip("Do NOT test on shared cluster")
        self.hc_api.package_name = "nodejs-imagestreams"
        self.hc_api.helm_package()
        assert self.hc_api.helm_installation()
        self.hc_api.package_name = "nodejs-application"
        assert self.hc_api.helm_package()
        assert self.hc_api.helm_installation(
            values={
                "nodejs_version": f"{VERSION}{TAG}",
                "namespace": self.hc_api.namespace
            }
        )
        assert self.hc_api.is_s2i_pod_running(pod_name_prefix="nodejs-example")
        assert self.hc_api.test_helm_curl_output(
            route_name="nodejs-example",
            expected_str="Node.js Crud Application"
        )

    def test_by_helm_test(self):
        self.hc_api.package_name = "nodejs-imagestreams"
        self.hc_api.helm_package()
        assert self.hc_api.helm_installation()
        self.hc_api.package_name = "nodejs-application"
        assert self.hc_api.helm_package()
        assert self.hc_api.helm_installation(
            values={
                "nodejs": f"{VERSION}{TAG}",
                "namespace": self.hc_api.namespace
            }
        )
        assert self.hc_api.is_s2i_pod_running(pod_name_prefix="nodejs-example")
        assert self.hc_api.test_helm_chart(expected_str=["Node.js Crud Application"])
