import re

from pathlib import Path

import pytest
from container_ci_suite.container_lib import ContainerTestLib
from container_ci_suite.engines.podman_wrapper import PodmanCLIWrapper

from conftest import VARS, skip_for_minimal


test_app = VARS.TEST_DIR / "test-app"
test_binary = VARS.TEST_DIR / "test-binary"
test_express_webapp = VARS.TEST_DIR / "test-express-webapp"
test_fips = VARS.TEST_DIR / "test-fips"
test_hw = VARS.TEST_DIR / "test-hw"
test_incremental = VARS.TEST_DIR / "test-incremental"


def build_s2i_app(app_path: Path, container_args: str = "") -> ContainerTestLib:
    """
    Build a S2I application.
    """
    container_lib = ContainerTestLib(VARS.IMAGE_NAME)
    app_name = app_path.name
    s2i_app = container_lib.build_as_df(
        app_path=app_path,
        s2i_args=f"--pull-policy=never {container_lib.build_s2i_npm_variables()} {container_args}",
        src_image=VARS.IMAGE_NAME,
        dst_image=f"{VARS.IMAGE_NAME}-{app_name}",
    )
    return s2i_app


class TestNodeJSAppsContainer:
    """
    Test NodeJS apps of a NodeJS application.
    """

    def setup_method(self):
        """
        Setup the test environment.
        """
        self.s2i_app = build_s2i_app(test_app)

    def teardown_method(self):
        """
        Cleanup the test environment.
        """
        self.s2i_app.cleanup()

    def test_run_app_application(self):
        """
        Test run app application of a NodeJS application.
        """
        assert self.s2i_app.create_container(
            cid_file_name=self.s2i_app.app_name, container_args="--user 100001"
        )
        cip = self.s2i_app.get_cip(cid_file_name=self.s2i_app.app_name)
        assert cip
        assert self.s2i_app.test_response(url=f"http://{cip}")

    def test_nodemon_removed(self):
        """
        Test nodemon removed of a NodeJS application.
        """
        return_value = PodmanCLIWrapper.podman_run_command_and_remove(
            cid_file_name=f"{VARS.IMAGE_NAME}-{self.s2i_app.app_name}",
            cmd="! test -d ./node_modules/nodemon",
            return_output=False,
        )
        assert return_value == 0

    def test_npm_cache_cleared(self):
        """
        Test npm cache cleared of a NodeJS application.
        """
        cache_loc = PodmanCLIWrapper.podman_run_command_and_remove(
            cid_file_name=f"{VARS.IMAGE_NAME}-{self.s2i_app.app_name}",
            cmd="npm config get cache",
        ).strip()
        assert (
            PodmanCLIWrapper.podman_run_command_and_remove(
                cid_file_name=f"{VARS.IMAGE_NAME}-{self.s2i_app.app_name}",
                cmd=f"! test -d {cache_loc}",
                return_output=False,
            )
            == 0
        )

    def test_npm_tmp_cleared(self):
        """
        Test npm tmp cleared of a NodeJS application.
        """
        tmp_config = PodmanCLIWrapper.podman_run_command_and_remove(
            cid_file_name=f"{VARS.IMAGE_NAME}-{self.s2i_app.app_name}",
            cmd="npm config get tmp",
        )
        assert tmp_config.strip() == "undefined"

    @pytest.mark.parametrize(
        "node_env,init_wrapper",
        [
            ("development", "true"),
            ("production", "true"),
            ("development", "false"),
        ],
    )
    def test_node_cmd_development(self, node_env, init_wrapper):
        """
        Test node command development of a NodeJS application.
        """
        skip_for_minimal()
        assert self.s2i_app.create_container(
            cid_file_name=self.s2i_app.app_name,
            container_args=f"--user 100001 '-e NODE_ENV={node_env} "
            f"-e INIT_WRAPPER={init_wrapper} -e NODE_CMD=node server.js'",
        )
        cip = self.s2i_app.get_cip(cid_file_name=self.s2i_app.app_name)
        assert cip
        assert self.s2i_app.test_response(url=f"http://{cip}")
        logs = self.s2i_app.get_logs(self.s2i_app.app_name)
        assert re.search(f"NODE_ENV={node_env}", logs)
        assert re.search("DEBUG_PORT=5858", logs)
        assert re.search(f"INIT_WRAPPER={init_wrapper}", logs)
        assert re.search("NODE_CMD=node server.js", logs)

    @pytest.mark.parametrize(
        "dev_mode,node_env",
        [
            ("true", "development"),
            ("false", "production"),
        ],
    )
    def test_dev_node(self, dev_mode, node_env):
        """
        Test dev node of a NodeJS application.
        """
        assert self.s2i_app.create_container(
            cid_file_name=self.s2i_app.app_name,
            container_args=f"--user 100001 '-e DEV_MODE={dev_mode}'",
        )
        logs = self.s2i_app.get_logs(self.s2i_app.app_name)
        print(f"AppsContainer '{logs}'.")
        cip = self.s2i_app.get_cip(cid_file_name=self.s2i_app.app_name)
        assert cip
        assert self.s2i_app.test_response(url=f"http://{cip}")
        assert re.search(f"DEV_MODE={dev_mode}", logs)
        assert re.search("DEBUG_PORT=5858", logs)
        assert re.search(f"NODE_ENV={node_env}", logs)

    @pytest.mark.parametrize(
        "node_env,init_wrapper",
        [
            ("production", "false"),
            ("development", "false"),
            ("development", "true"),
        ],
    )
    def test_node_init_wrapper(self, node_env, init_wrapper):
        """
        Test node init wrapper of a NodeJS application.
        """
        skip_for_minimal()
        assert self.s2i_app.create_container(
            cid_file_name=self.s2i_app.app_name,
            container_args=f"--user 100001 '-e NODE_ENV={node_env} "
            f"-e INIT_WRAPPER={init_wrapper}'",
        )
        logs = self.s2i_app.get_logs(self.s2i_app.app_name)
        cip = self.s2i_app.get_cip(cid_file_name=self.s2i_app.app_name)
        assert cip
        assert self.s2i_app.test_response(url=f"http://{cip}", debug=True)
        assert re.search(f"NODE_ENV={node_env}", logs)
        assert re.search("DEBUG_PORT=5858", logs)
        assert re.search(f"INIT_WRAPPER={init_wrapper}", logs)


class TestNodeJSAppsWithDevModeTrueContainer:
    """
    Test NodeJS apps with DevMode true of a NodeJS application.
    """

    def setup_method(self):
        """
        Setup the test environment.
        """
        self.s2i_app = build_s2i_app(test_app, container_args="-e DEV_MODE=true")

    def teardown_method(self):
        """
        Cleanup the test environment.
        """
        self.s2i_app.cleanup()

    def test_run_app_application(self):
        """
        Test run app application of a NodeJS application.
        """
        assert self.s2i_app.create_container(
            cid_file_name=self.s2i_app.app_name, container_args="--user 100001"
        )
        cip = self.s2i_app.get_cip(cid_file_name=self.s2i_app.app_name)
        assert cip
        assert self.s2i_app.test_response(url=f"http://{cip}")

    def test_nodemon_present(self):
        """
        Test nodemon present of a NodeJS application.
        """
        return_value = PodmanCLIWrapper.podman_run_command_and_remove(
            cid_file_name=f"{VARS.IMAGE_NAME}-{self.s2i_app.app_name}",
            cmd="test -d ./node_modules/nodemon",
            return_output=False,
        )
        assert return_value == 0

    def test_npm_cache_exist(self):
        """
        Test npm cache exist of a NodeJS application.
        """
        cache_loc = PodmanCLIWrapper.podman_run_command_and_remove(
            cid_file_name=f"{VARS.IMAGE_NAME}-{self.s2i_app.app_name}",
            cmd="npm config get cache",
        ).strip()
        assert (
            PodmanCLIWrapper.podman_run_command_and_remove(
                cid_file_name=f"{VARS.IMAGE_NAME}-{self.s2i_app.app_name}",
                cmd=f"test -d {cache_loc}",
                return_output=False,
            )
            == 0
        )

    @pytest.mark.parametrize(
        "dev_mode,node_env",
        [
            ("true", "development"),
            ("false", "production"),
        ],
    )
    def test_dev_node(self, dev_mode, node_env):
        """
        Test dev node of a NodeJS application.
        """
        assert self.s2i_app.create_container(
            cid_file_name=self.s2i_app.app_name,
            container_args=f"--user 100001 '-e DEV_MODE={dev_mode}'",
        )
        cip = self.s2i_app.get_cip(cid_file_name=self.s2i_app.app_name)
        assert cip
        assert self.s2i_app.test_response(url=f"http://{cip}")
        logs = self.s2i_app.get_logs(self.s2i_app.app_name)
        assert re.search(f"DEV_MODE={dev_mode}", logs)
        assert re.search("DEBUG_PORT=5858", logs)
        assert re.search(f"NODE_ENV={node_env}", logs)

    @pytest.mark.parametrize(
        "node_env,init_wrapper",
        [
            ("development", "true"),
            ("production", "true"),
            ("development", "false"),
        ],
    )
    def test_node_cmd_development(self, node_env, init_wrapper):
        """
        Test node command development of a NodeJS application.
        """
        skip_for_minimal()
        assert self.s2i_app.create_container(
            cid_file_name=self.s2i_app.app_name,
            container_args=f"--user 100001 '-e NODE_ENV={node_env} "
            f"-e INIT_WRAPPER={init_wrapper} -e NODE_CMD=node server.js'",
        )
        cip = self.s2i_app.get_cip(cid_file_name=self.s2i_app.app_name)
        assert cip
        assert self.s2i_app.test_response(url=f"http://{cip}")
        logs = self.s2i_app.get_logs(self.s2i_app.app_name)
        assert re.search(f"NODE_ENV={node_env}", logs)
        assert re.search("DEBUG_PORT=5858", logs)
        assert re.search(f"INIT_WRAPPER={init_wrapper}", logs)
        assert re.search("NODE_CMD=node server.js", logs)


class TestNodeJSAppsWithNodeEnvDevelopmentContainer:
    """
    Test NodeJS apps with NodeEnv development of a NodeJS application.
    """

    def setup_method(self):
        """
        Setup the test environment.
        """
        self.s2i_app = build_s2i_app(test_app, container_args="-e NODE_ENV=development")

    def teardown_method(self):
        """
        Cleanup the test environment.
        """
        self.s2i_app.cleanup()

    def test_run_app_application(self):
        """
        Test run app application of a NodeJS application.
        """
        assert self.s2i_app.create_container(
            cid_file_name=self.s2i_app.app_name, container_args="--user 100001"
        )
        cip = self.s2i_app.get_cip(cid_file_name=self.s2i_app.app_name)
        assert cip
        assert self.s2i_app.test_response(url=f"http://{cip}")

    def test_nodemon_present(self):
        """
        Test nodemon present of a NodeJS application.
        """
        return_value = PodmanCLIWrapper.podman_run_command_and_remove(
            cid_file_name=f"{VARS.IMAGE_NAME}-{self.s2i_app.app_name}",
            cmd="test -d ./node_modules/nodemon",
            return_output=False,
        )
        assert return_value == 0

    def test_npm_cache_exist(self):
        """
        Test npm cache exist of a NodeJS application.
        """
        cache_loc = PodmanCLIWrapper.podman_run_command_and_remove(
            cid_file_name=f"{VARS.IMAGE_NAME}-{self.s2i_app.app_name}",
            cmd="npm config get cache",
        ).strip()
        assert (
            PodmanCLIWrapper.podman_run_command_and_remove(
                cid_file_name=f"{VARS.IMAGE_NAME}-{self.s2i_app.app_name}",
                cmd=f"test -d {cache_loc}",
                return_output=False,
            )
            == 0
        )

    @pytest.mark.parametrize(
        "dev_mode,node_env",
        [
            ("true", "development"),
            ("false", "development"),
        ],
    )
    def test_dev_node(self, dev_mode, node_env):
        """
        Test dev node of a NodeJS application.
        """
        assert self.s2i_app.create_container(
            cid_file_name=self.s2i_app.app_name,
            container_args=f"--user 100001 '-e DEV_MODE={dev_mode}'",
        )
        cip = self.s2i_app.get_cip(cid_file_name=self.s2i_app.app_name)
        assert cip
        assert self.s2i_app.test_response(url=f"http://{cip}")
        logs = self.s2i_app.get_logs(self.s2i_app.app_name)
        assert re.search(f"DEV_MODE={dev_mode}", logs)
        assert re.search("DEBUG_PORT=5858", logs)
        assert re.search(f"NODE_ENV={node_env}", logs)

    @pytest.mark.parametrize(
        "node_env,init_wrapper",
        [
            ("development", "true"),
            ("production", "true"),
            ("production", "false"),
        ],
    )
    def test_node_cmd_development(self, node_env, init_wrapper):
        assert self.s2i_app.create_container(
            cid_file_name=self.s2i_app.app_name,
            container_args=f"--user 100001 '-e NODE_ENV={node_env} "
            f"-e INIT_WRAPPER={init_wrapper} -e NODE_CMD=node server.js'",
        )
        cip = self.s2i_app.get_cip(cid_file_name=self.s2i_app.app_name)
        assert cip
        assert self.s2i_app.test_response(url=f"http://{cip}")
        logs = self.s2i_app.get_logs(self.s2i_app.app_name)
        assert re.search(f"NODE_ENV={node_env}", logs)
        assert re.search("DEBUG_PORT=5858", logs)
        assert re.search(f"INIT_WRAPPER={init_wrapper}", logs)
        assert re.search("NODE_CMD=node server.js", logs)


class TestNodeJSAppsHWContainer:
    """
    Test HW of a NodeJS application.
    """

    def setup_method(self):
        """
        Setup the test environment.
        """
        http_proxy = "http://user.password@0.0.0.0:8080"
        https_proxy = "https://user.password@0.0.0.0:8080"
        self.s2i_app = build_s2i_app(
            test_hw,
            container_args=f"-e HTTP_PROXY={http_proxy} -e http_proxy={http_proxy} "
            f"-e HTTPS_PROXY={https_proxy} -e https_proxy={https_proxy}",
        )

    def teardown_method(self):
        """
        Cleanup the test environment.
        """
        self.s2i_app.cleanup()

    def test_run_app_application(self):
        """
        Test run app application of a NodeJS application.
        """
        assert self.s2i_app.create_container(
            cid_file_name=self.s2i_app.app_name, container_args="--user 100001"
        )
        cip = self.s2i_app.get_cip(cid_file_name=self.s2i_app.app_name)
        assert cip
        assert self.s2i_app.test_response(url=f"http://{cip}")

    def test_node_init_wrapper(self):
        """
        Test node init wrapper of a NodeJS application.
        """
        skip_for_minimal()
        assert self.s2i_app.create_container(
            cid_file_name=self.s2i_app.app_name,
            container_args="--user 100001 '-e NODE_ENV=development "
            "-e INIT_WRAPPER=false'",
        )
        logs = self.s2i_app.get_logs(self.s2i_app.app_name)
        cip = self.s2i_app.get_cip(cid_file_name=self.s2i_app.app_name)
        assert cip
        assert self.s2i_app.test_response(url=f"http://{cip}", debug=True)
        assert re.search("NODE_ENV=development", logs)
        assert re.search("DEBUG_PORT=5858", logs)
        assert re.search("INIT_WRAPPER=false", logs)

    def test_node_cmd_development(self):
        """
        Test node command development of a NodeJS application.
        """
        skip_for_minimal()
        assert self.s2i_app.create_container(
            cid_file_name=self.s2i_app.app_name,
            container_args="--user 100001 '-e NODE_ENV=development "
            "-e INIT_WRAPPER=true -e NODE_CMD=node server.js'",
        )
        cip = self.s2i_app.get_cip(cid_file_name=self.s2i_app.app_name)
        assert cip
        assert self.s2i_app.test_response(url=f"http://{cip}")
        logs = self.s2i_app.get_logs(self.s2i_app.app_name)
        assert re.search("NODE_ENV=development", logs)
        assert re.search("DEBUG_PORT=5858", logs)
        assert re.search("INIT_WRAPPER=true", logs)
        assert re.search("NODE_CMD=node server.js", logs)

    def test_safe_logging(self):
        podman_log_file = self.s2i_app.get_podman_build_log_file()
        assert podman_log_file.count("redacted") == 4
        assert "redacted" in podman_log_file


class TestNodeJSIncrementalAppContainer:
    """
    Test incremental build of a NodeJS application.
    """

    def setup_method(self):
        """
        Setup the test environment.
        """
        self.build1 = build_s2i_app(test_incremental)
        self.build2 = build_s2i_app(test_incremental, container_args="--incremental")

    def teardown_method(self):
        """
        Cleanup the test environment.
        """
        self.build1.cleanup()
        self.build2.cleanup()

    def test_incremental_build(self):
        """
        Test incremental build of a NodeJS application.
        """
        skip_for_minimal()
        build_log1 = self.build1.get_podman_build_log_file()
        build_log2 = self.build2.get_podman_build_log_file()
        assert build_log1 != build_log2
