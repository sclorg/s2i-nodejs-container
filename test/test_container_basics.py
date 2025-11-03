import pytest

from pathlib import Path

from container_ci_suite.container_lib import ContainerTestLib, PodmanCLIWrapper
from container_ci_suite.utils import get_file_content

from conftest import VARS, skip_for_minimal


test_fips = VARS.TEST_DIR / "test-fips"


def build_s2i_app(app_path: Path) -> ContainerTestLib:
    """
    Build a S2I application.
    """
    container_lib = ContainerTestLib(VARS.IMAGE_NAME)
    app_name = app_path.name
    s2i_app = container_lib.build_as_df(
        app_path=app_path,
        s2i_args=f"--pull-policy=never {container_lib.build_s2i_npm_variables()}",
        src_image=VARS.IMAGE_NAME,
        dst_image=f"{VARS.IMAGE_NAME}-{app_name}",
    )
    return s2i_app


class TestNodeJSAppContainer:
    """
    Test NodeJS app of a NodeJS application.
    """

    def setup_method(self):
        """
        Setup the test environment.
        """
        self.app = ContainerTestLib(image_name=VARS.IMAGE_NAME, s2i_image=True)

    def teardown_method(self):
        """
        Cleanup the test environment.
        """
        self.app.cleanup()

    def test_run_s2i_usage(self):
        """
        Test if /usr/libexec/s2i/usage works properly
        """
        output = self.app.s2i_usage()
        assert output

    def test_docker_run_usage(self):
        """
        Test if podman run works properly
        """
        assert (
            PodmanCLIWrapper.call_podman_command(
                cmd=f"run --rm {VARS.IMAGE_NAME} &>/dev/null", return_output=False
            )
            == 0
        )

    def test_scl_usage(self):
        """
        Test if node --version works properly
        """
        assert VARS.VERSION_NO_MINIMAL in PodmanCLIWrapper.podman_run_command(
            f"--rm {VARS.IMAGE_NAME} /bin/bash -c 'node --version'"
        )

    @pytest.mark.parametrize("dockerfile", ["Dockerfile", "Dockerfile.s2i"])
    def test_dockerfiles(self, dockerfile):
        """
        Test if we are able to build a container from
        `examples/from-dockerfile/<version>/{Dockerfile,Dockerfile.s2i}
        """
        assert self.app.build_test_container(
            dockerfile=VARS.TEST_DIR / "examples/from-dockerfile" / dockerfile,
            app_url="https://github.com/sclorg/nodejs-ex.git",
            app_dir="app-src",
            build_args="--ulimit nofile=4096:4096",
        )
        assert self.app.test_app_dockerfile()
        cip = self.app.get_cip()
        assert cip
        assert self.app.test_response(
            url=cip, expected_output="Node.js Crud Application"
        )


class TestNodeJSFipsContainer:
    """
    Test NodeJS FIPS mode of a NodeJS application.
    """

    def setup_method(self):
        """
        Setup the test environment.
        """
        self.s2i_fips = build_s2i_app(test_fips)

    def teardown_method(self):
        """
        Cleanup the test environment.
        """
        self.s2i_fips.cleanup()

    def test_nodejs_fips_mode(self):
        """
        Test NodeJS FIPS mode of a NodeJS application.
        """
        skip_for_minimal()
        if VARS.OS == "rhel8":
            pytest.skip("Do not execute on RHEL8")
        is_fips_enabled = 0
        fips_enabled_file = Path("/proc/sys/crypto/fips_enabled")
        if fips_enabled_file.exists():
            is_fips_enabled = int(get_file_content(fips_enabled_file))
        if is_fips_enabled == 1:
            fips_result = PodmanCLIWrapper.podman_run_command_and_remove(
                cid_file_name=f"{VARS.IMAGE_NAME}-{self.s2i_fips.app_name}",
                cmd="node test.js",
                return_output=False,
            )
            assert fips_result == 1
        else:
            fips_mode = PodmanCLIWrapper.podman_run_command_and_remove(
                cid_file_name=f"{VARS.IMAGE_NAME}-{self.s2i_fips.app_name}",
                cmd="node test.js",
                return_output=False,
            )
            assert fips_mode == 0

    def test_run_fips_app_application(self):
        """
        Test NodeJS FIPS mode of a NodeJS application.
        """
        skip_for_minimal()
        is_fips_enabled = 0
        fips_enabled_file = Path("/proc/sys/crypto/fips_enabled")
        if fips_enabled_file.exists():
            is_fips_enabled = int(get_file_content(fips_enabled_file))
        if is_fips_enabled == 1:
            assert self.s2i_fips.create_container(
                cid_file_name=self.s2i_fips.app_name, container_args="--user 100001"
            )
            assert self.s2i_fips.get_cid(cid_file_name=self.s2i_fips.app_name)
