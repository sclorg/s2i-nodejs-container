import pytest


from container_ci_suite.openshift import OpenShiftAPI

from conftest import VARS


class TestDeployNodeJSExTemplate:

    def setup_method(self):
        self.oc_api = OpenShiftAPI(
            pod_name_prefix=f"nodejs-{VARS.VERSION_NO_MINIMAL}-testing",
            version=VARS.VERSION_NO_MINIMAL,
            shared_cluster=True
        )

    def teardown_method(self):
        self.oc_api.delete_project()

    @pytest.mark.parametrize(
        "template",
        [
            "nodejs.json",
            "nodejs-postgresql-persistent.json",
        ]
    )
    def test_nodejs_ex_template_inside_cluster(self, template):
        assert self.oc_api.upload_image(VARS.DEPLOYED_PGSQL_IMAGE, VARS.PGSQL_IMAGE_TAG)
        template_url = self.oc_api.get_raw_url_for_json(
            container="nodejs-ex", dir="openshift/templates", filename=template, branch="master"
        )
        service_name = f"nodejs-{VARS.VERSION_NO_MINIMAL}-testing"
        openshift_args = [
            "SOURCE_REPOSITORY_URL=https://github.com/sclorg/nodejs-ex.git",
            "SOURCE_REPOSITORY_REF=master",
            f"NODEJS_VERSION={VARS.VERSION_NO_MINIMAL}",
            f"NAME={service_name}"
        ]
        if template != "nodejs.json":
            openshift_args = [
                "SOURCE_REPOSITORY_URL=https://github.com/sclorg/nodejs-ex.git",
                "SOURCE_REPOSITORY_REF=master",
                f"POSTGRESQL_VERSION={VARS.IMAGE_TAG}",
                f"NODEJS_VERSION={VARS.VERSION_NO_MINIMAL}",
                f"NAME={service_name}",
                "DATABASE_USER=testu",
                "DATABASE_PASSWORD=testpwd",
                "DATABASE_ADMIN_PASSWORD=testadminpwd"
            ]
        assert self.oc_api.deploy_template_with_image(
            image_name=VARS.IMAGE_NAME,
            template=template_url,
            name_in_template="nodejs",
            openshift_args=openshift_args

        )
        assert self.oc_api.is_template_deployed(name_in_template=service_name)
        assert self.oc_api.check_response_inside_cluster(
            name_in_template=service_name, expected_output="Node.js Crud Application"
        )
