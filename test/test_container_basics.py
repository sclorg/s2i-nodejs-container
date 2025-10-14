import pytest

from container_ci_suite.container_lib import ContainerTestLib, PodmanCLIWrapper

from conftest import VARS


class TestNodeJSAppContainer:

    def setup_method(self):
        self.app = ContainerTestLib(image_name=VARS.IMAGE_NAME, s2i_image=True)

    def teardown_method(self):
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
        assert PodmanCLIWrapper.call_podman_command(
            cmd=f"run --rm {VARS.IMAGE_NAME} &>/dev/null",
            return_output=False
        ) == 0

    def test_scl_usage(self):
        assert VARS.VERSION_NO_MINIMAL in PodmanCLIWrapper.podman_run_command(
            f"--rm {VARS.IMAGE_NAME} /bin/bash -c 'node --version'"
        )

    @pytest.mark.parametrize(
        "dockerfile",
        [
            "Dockerfile",
            "Dockerfile.s2i"
        ]
    )
    def test_dockerfiles(self, dockerfile):
        assert self.app.build_test_container(
            dockerfile=VARS.TEST_DIR / "examples/from-dockerfile" / dockerfile,
            app_url="https://github.com/sclorg/nodejs-ex.git",
            app_dir="app-src",
            build_args="--ulimit nofile=4096:4096"
        )
        assert self.app.test_app_dockerfile()
        cip = self.app.get_cip()
        assert cip
        assert self.app.test_response(
            url=cip,
            expected_output="Node.js Crud Application"
        )
