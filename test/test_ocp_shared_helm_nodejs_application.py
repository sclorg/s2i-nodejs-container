from container_ci_suite.helm import HelmChartsAPI

from conftest import VARS


class TestHelmNodeJSApplication:
    def setup_method(self):
        package_name = "redhat-nodejs-application"
        self.hc_api = HelmChartsAPI(
            path=VARS.TEST_DIR, package_name=package_name, tarball_dir=VARS.TEST_DIR
        )
        self.hc_api.clone_helm_chart_repo(
            repo_url="https://github.com/sclorg/helm-charts",
            repo_name="helm-charts",
            subdir="charts/redhat",
        )

    def teardown_method(self):
        self.hc_api.delete_project()

    def test_by_helm_test(self):
        self.hc_api.package_name = "redhat-nodejs-imagestreams"
        self.hc_api.helm_package()
        assert self.hc_api.helm_installation()
        self.hc_api.package_name = "redhat-nodejs-application"
        assert self.hc_api.helm_package()
        assert self.hc_api.helm_installation(
            values={
                "nodejs": f"{VARS.VERSION}{VARS.TAG}",
                "namespace": self.hc_api.namespace,
            }
        )
        assert self.hc_api.is_s2i_pod_running(pod_name_prefix="nodejs-example")
        assert self.hc_api.test_helm_chart(expected_str=["Node.js Crud Application"])
