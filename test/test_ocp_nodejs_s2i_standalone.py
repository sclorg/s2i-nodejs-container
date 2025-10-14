from container_ci_suite.openshift import OpenShiftAPI

from conftest import VARS


class TestNodeJSExTemplate:

    def setup_method(self):
        self.oc_api = OpenShiftAPI(
            pod_name_prefix=f"nodejs-{VARS.VERSION_NO_MINIMAL}-testing",
            version=VARS.VERSION_NO_MINIMAL
        )

    def teardown_method(self):
        self.oc_api.delete_project()

    def test_nodejs_ex_template_inside_cluster(self):
        service_name = f"nodejs-{VARS.VERSION_NO_MINIMAL}-testing"
        assert self.oc_api.deploy_s2i_app(
            image_name=VARS.IMAGE_NAME, app="https://github.com/sclorg/s2i-nodejs-container.git",
            context="test/test-app",
            service_name=service_name
        )
        assert self.oc_api.is_template_deployed(name_in_template=service_name)
        assert self.oc_api.check_response_inside_cluster(
            name_in_template=service_name, expected_output="This is a node.js echo service"
        )
