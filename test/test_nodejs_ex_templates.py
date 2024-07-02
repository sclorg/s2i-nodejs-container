import os
import sys

import pytest
from container_ci_suite.openshift import OpenShiftAPI
from container_ci_suite.utils import check_variables

if not check_variables():
    print("At least one variable from IMAGE_NAME, OS, SINGLE_VERSION is missing.")
    sys.exit(1)


VERSION = os.getenv("SINGLE_VERSION")
IMAGE_NAME = os.getenv("IMAGE_NAME")
OS = os.getenv("TARGET")

DEPLOYED_PGSQL_IMAGE = "quay.io/sclorg/postgresql-15-c9s"

NODEJS_TAGS = {
    "rhel8": "-ubi8",
    "rhel9": "-ubi9"
}
NODEJS_TAG = NODEJS_TAGS.get(OS, None)
PGSQL_IMAGE_NAME = f"postgresql:15-c9s"
IMAGE_TAG = f"15-c9s"


class TestDeployNodeJSExTemplate:

    def setup_method(self):
        self.oc_api = OpenShiftAPI(pod_name_prefix="nodejs-testing", version=VERSION)
        assert self.oc_api.upload_image(DEPLOYED_PGSQL_IMAGE, PGSQL_IMAGE_NAME)

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
        service_name = "nodejs-testing"
        template_url = self.oc_api.get_raw_url_for_json(
            container="nodejs-ex", dir="openshift/templates", filename=template, branch="master"
        )
        new_version = VERSION
        if "minimal" in VERSION:
            new_version = VERSION.replace("-minimal", "")
        openshift_args = [
            "SOURCE_REPOSITORY_URL=https://github.com/sclorg/nodejs-ex.git",
            "SOURCE_REPOSITORY_REF=master",
            f"NODEJS_VERSION={new_version}",
            f"NAME={service_name}"
        ]
        if template != "nodejs.json":
            openshift_args = [
                "SOURCE_REPOSITORY_URL=https://github.com/sclorg/nodejs-ex.git",
                "SOURCE_REPOSITORY_REF=master",
                f"POSTGRESQL_VERSION={IMAGE_TAG}",
                f"NODEJS_VERSION={new_version}",
                f"NAME={service_name}",
                "DATABASE_USER=testu",
                "DATABASE_PASSWORD=testpwd",
                "DATABASE_ADMIN_PASSWORD=testadminpwd"
            ]
        assert self.oc_api.deploy_template_with_image(
            image_name=IMAGE_NAME,
            template=template_url,
            name_in_template="nodejs",
            openshift_args=openshift_args

        )
        assert self.oc_api.template_deployed(name_in_template=service_name)
        assert self.oc_api.check_response_inside_cluster(
            name_in_template=service_name, expected_output="Node.js Crud Application"
        )
