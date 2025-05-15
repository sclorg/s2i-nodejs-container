import os
import sys

import pytest

from container_ci_suite.openshift import OpenShiftAPI
from container_ci_suite.utils import check_variables

from constants import TAGS

if not check_variables():
    print("At least one variable from IMAGE_NAME, OS, VERSION is missing.")
    sys.exit(1)


VERSION = os.getenv("VERSION")
IMAGE_NAME = os.getenv("IMAGE_NAME")
OS = os.getenv("OS")

DEPLOYED_PGSQL_IMAGE = "quay.io/sclorg/postgresql-15-c9s"


TAG = TAGS.get(OS)
PGSQL_IMAGE_TAG = f"postgresql:15-c9s"
IMAGE_TAG = f"15-c9s"


# Replacement with 'test_python_s2i_templates'
class TestImagestreamsQuickstart:

    def setup_method(self):
        self.oc_api = OpenShiftAPI(pod_name_prefix="nodejs-example", version=VERSION, shared_cluster=True)

    def teardown_method(self):
        self.oc_api.delete_project()

    @pytest.mark.parametrize(
        "template",
        [
            "nodejs.json",
            "nodejs-postgresql-persistent.json",
        ]
    )
    def test_nodejs_template_inside_cluster(self, template):
        assert self.oc_api.upload_image(DEPLOYED_PGSQL_IMAGE, PGSQL_IMAGE_TAG)
        new_version = VERSION
        if "minimal" in VERSION:
            new_version = VERSION.replace("-minimal", "")
        service_name = f"nodejs-{new_version}-example"
        template_url = self.oc_api.get_raw_url_for_json(
            container="nodejs-ex", dir="openshift/templates", filename=template, branch="master"
        )
        openshift_args = [
            f"SOURCE_REPOSITORY_URL=https://github.com/sclorg/nodejs-ex.git",
            f"SOURCE_REPOSITORY_REF=master",
            f"NODEJS_VERSION={new_version}",
            f"NAME={service_name}"
        ]
        if template != "nodejs.json":
            openshift_args = [
                f"SOURCE_REPOSITORY_URL=https://github.com/sclorg/nodejs-ex.git",
                f"SOURCE_REPOSITORY_REF=master",
                f"POSTGRESQL_VERSION={IMAGE_TAG}",
                f"NODEJS_VERSION={new_version}",
                f"NAME={service_name}",
                f"DATABASE_USER=testu",
                f"DATABASE_PASSWORD=testpwd",
                f"DATABASE_ADMIN_PASSWORD=testadminpwd"
            ]
        assert self.oc_api.imagestream_quickstart(
            imagestream_file="imagestreams/nodejs-rhel.json",
            template_file=template_url,
            image_name=IMAGE_NAME,
            name_in_template="nodejs",
            openshift_args=openshift_args
        )
        assert self.oc_api.is_template_deployed(name_in_template=service_name)
        assert self.oc_api.check_response_inside_cluster(
            name_in_template=service_name, expected_output="Node.js Crud Application"
        )

