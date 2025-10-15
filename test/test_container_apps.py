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
    container_lib = ContainerTestLib(VARS.IMAGE_NAME)
    app_name = app_path.name
    s2i_app = container_lib.build_as_df(
        app_path=app_path,
        s2i_args=f"--pull-policy=never {container_lib.build_s2i_npm_variables()} {container_args}",
        src_image=VARS.IMAGE_NAME,
        dst_image=f"{VARS.IMAGE_NAME}-{app_name}"
    )
    return s2i_app


class TestNodeJSAppsContainer:

    def setup_method(self):
        self.s2i_app = build_s2i_app(test_app)

    def teardown_method(self):
        self.s2i_app.cleanup()

    def test_run_app_application(self):
        assert self.s2i_app.create_container(
            cid_file_name=self.s2i_app.app_name,
            container_args="--user 100001"
        )
        cip = self.s2i_app.get_cip(cid_file_name=self.s2i_app.app_name)
        assert cip
        assert self.s2i_app.test_response(
            url=f"http://{cip}"
        )

    def test_nodemon_removed(self):
        return_value = PodmanCLIWrapper.podman_run_command_and_remove(
            cid_file_name=f"{VARS.IMAGE_NAME}-{self.s2i_app.app_name}",
            cmd="! test -d ./node_modules/nodemon",
            return_output=False
        )
        assert return_value == 0

    def test_npm_cache_cleared(self):
        cache_loc = PodmanCLIWrapper.podman_run_command_and_remove(
            cid_file_name=f"{VARS.IMAGE_NAME}-{self.s2i_app.app_name}",
            cmd="npm config get cache"
        ).strip()
        assert PodmanCLIWrapper.podman_run_command_and_remove(
            cid_file_name=f"{VARS.IMAGE_NAME}-{self.s2i_app.app_name}",
            cmd=f"! test -d {cache_loc}",
            return_output=False
        ) == 0

    def test_npm_tmp_cleared(self):
        tmp_config = PodmanCLIWrapper.podman_run_command_and_remove(
            cid_file_name=f"{VARS.IMAGE_NAME}-{self.s2i_app.app_name}",
            cmd="npm config get tmp"
        )
        assert tmp_config.strip() == "undefined"

    # test_node_cmd_development_init_wrapper_true
    # test_node_cmd_production_init_wrapper_true
    # test_node_cmd_development_init_wrapper_false
    @pytest.mark.parametrize(
        "node_env,init_wrapper,node_cmd",
        [
            ("development", "true", "node server.js"),
            ("production", "true", "node server.js"),
            ("development", "false", "node server.js"),
        ]
    )
    def test_node_cmd_development(self, node_env, init_wrapper, node_cmd):
        skip_for_minimal()
        assert self.s2i_app.create_container(
          cid_file_name=self.s2i_app.app_name,
          container_args=f"--user 100001 \'-e NODE_ENV={node_env} "
                         f"-e INIT_WRAPPER={init_wrapper} -e NODE_CMD={node_cmd}\'"
        )
        cip = self.s2i_app.get_cip(cid_file_name=self.s2i_app.app_name)
        assert cip
        assert self.s2i_app.test_response(
            url=f"http://{cip}"
        )
        logs = self.s2i_app.get_logs(self.s2i_app.app_name)
        assert re.search(f"NODE_ENV={node_env}", logs)
        assert re.search("DEBUG_PORT=5858", logs)
        assert re.search(f"INIT_WRAPPER={init_wrapper}", logs)
        assert re.search(f"NODE_CMD={node_cmd}", logs)

    # test_dev_mode_true_development
    # test_dev_mode_false_production
    @pytest.mark.parametrize(
        "dev_mode,node_env",
        [
            ("true", "development"),
            ("false", "production"),
        ]
    )
    def test_dev_node(self, dev_mode, node_env):
        assert self.s2i_app.create_container(
            cid_file_name=self.s2i_app.app_name,
            container_args=f"--user 100001 \'-e DEV_MODE={dev_mode}\'"
        )
        logs = self.s2i_app.get_logs(self.s2i_app.app_name)
        print(f"AppsContainer '{logs}'.")
        cip = self.s2i_app.get_cip(cid_file_name=self.s2i_app.app_name)
        assert cip
        assert self.s2i_app.test_response(
            url=f"http://{cip}"
        )
        assert re.search(f"DEV_MODE={dev_mode}", logs)
        assert re.search("DEBUG_PORT=5858", logs)
        assert re.search(f"NODE_ENV={node_env}", logs)

    # test_init_wrapper_true_development
    # test_init_wrapper_false_development
    @pytest.mark.parametrize(
        "node_env,init_wrapper",
        [
            ("production", "false"),
            ("development", "false"),
            ("development", "true"),

        ]
    )
    def test_node_init_wrapper(self, node_env, init_wrapper):
        skip_for_minimal()
        assert self.s2i_app.create_container(
            cid_file_name=self.s2i_app.app_name,
            container_args=f"--user 100001 \'-e NODE_ENV={node_env} "
                           f"-e INIT_WRAPPER={init_wrapper}\'"
        )
        logs = self.s2i_app.get_logs(self.s2i_app.app_name)
        cip = self.s2i_app.get_cip(cid_file_name=self.s2i_app.app_name)
        assert cip
        assert self.s2i_app.test_response(
            url=f"http://{cip}",
            debug=True
        )
        assert re.search(f"NODE_ENV={node_env}", logs)
        assert re.search("DEBUG_PORT=5858", logs)
        assert re.search(f"INIT_WRAPPER={init_wrapper}", logs)


class TestNodeJSAppsWithDevModeTrueContainer:

    def setup_method(self):
        self.s2i_app = build_s2i_app(test_app, container_args="-e DEV_MODE=true")

    def teardown_method(self):
        self.s2i_app.cleanup()

    def test_run_app_application(self):
        assert self.s2i_app.create_container(
            cid_file_name=self.s2i_app.app_name, container_args="--user 100001"
        )
        cip = self.s2i_app.get_cip(cid_file_name=self.s2i_app.app_name)
        assert cip
        assert self.s2i_app.test_response(
            url=f"http://{cip}"
        )

    def test_nodemon_present(self):
        return_value = PodmanCLIWrapper.podman_run_command_and_remove(
            cid_file_name=f"{VARS.IMAGE_NAME}-{self.s2i_app.app_name}",
            cmd="test -d ./node_modules/nodemon",
            return_output=False
        )
        assert return_value == 0

    def test_npm_cache_exist(self):
        cache_loc = PodmanCLIWrapper.podman_run_command_and_remove(
            cid_file_name=f"{VARS.IMAGE_NAME}-{self.s2i_app.app_name}",
            cmd="npm config get cache"
        ).strip()
        assert PodmanCLIWrapper.podman_run_command_and_remove(
            cid_file_name=f"{VARS.IMAGE_NAME}-{self.s2i_app.app_name}",
            cmd=f"test -d {cache_loc}",
            return_output=False
        ) == 0

    # test_dev_mode_true_development
    # test_dev_mode_false_production
    @pytest.mark.parametrize(
        "dev_mode,node_env",
        [
            ("true", "development"),
            ("false", "production"),
        ]
    )
    def test_dev_node(self, dev_mode, node_env):
        assert self.s2i_app.create_container(
            cid_file_name=self.s2i_app.app_name,
            container_args=f"--user 100001 \'-e DEV_MODE={dev_mode}\'"
        )
        cip = self.s2i_app.get_cip(cid_file_name=self.s2i_app.app_name)
        assert cip
        assert self.s2i_app.test_response(
            url=f"http://{cip}"
        )
        logs = self.s2i_app.get_logs(self.s2i_app.app_name)
        assert re.search(f"DEV_MODE={dev_mode}", logs)
        assert re.search("DEBUG_PORT=5858", logs)
        assert re.search(f"NODE_ENV={node_env}", logs)

    # test_node_cmd_development_init_wrapper_true
    # test_node_cmd_production_init_wrapper_true
    # test_node_cmd_development_init_wrapper_false
    @pytest.mark.parametrize(
        "node_env,init_wrapper,node_cmd",
        [
            ("development", "true", "node server.js"),
            ("production", "true", "node server.js"),
            ("development", "false", "node server.js"),
        ]
    )
    def test_node_cmd_development(self, node_env, init_wrapper, node_cmd):
        skip_for_minimal()
        assert self.s2i_app.create_container(
          cid_file_name=self.s2i_app.app_name,
          container_args=f"--user 100001 \'-e NODE_ENV={node_env} "
                         f"-e INIT_WRAPPER={init_wrapper} -e NODE_CMD={node_cmd}\'"
        )
        cip = self.s2i_app.get_cip(cid_file_name=self.s2i_app.app_name)
        assert cip
        assert self.s2i_app.test_response(
            url=f"http://{cip}"
        )
        logs = self.s2i_app.get_logs(self.s2i_app.app_name)
        assert re.search(f"NODE_ENV={node_env}", logs)
        assert re.search("DEBUG_PORT=5858", logs)
        assert re.search(f"INIT_WRAPPER={init_wrapper}", logs)
        assert re.search(f"NODE_CMD={node_cmd}", logs)

class TestNodeJSAppsWithNodeEnvDevelopmentContainer:

    def setup_method(self):
        self.s2i_app = build_s2i_app(test_app, container_args="-e NODE_ENV=development")

    def teardown_method(self):
        self.s2i_app.cleanup()

    def test_run_app_application(self):
        assert self.s2i_app.create_container(
            cid_file_name=self.s2i_app.app_name, container_args="--user 100001"
        )
        cip = self.s2i_app.get_cip(cid_file_name=self.s2i_app.app_name)
        assert cip
        assert self.s2i_app.test_response(
            url=f"http://{cip}"
        )

    def test_nodemon_present(self):
        return_value = PodmanCLIWrapper.podman_run_command_and_remove(
            cid_file_name=f"{VARS.IMAGE_NAME}-{self.s2i_app.app_name}",
            cmd="test -d ./node_modules/nodemon",
            return_output=False
        )
        assert return_value == 0

    def test_npm_cache_exist(self):
        cache_loc = PodmanCLIWrapper.podman_run_command_and_remove(
            cid_file_name=f"{VARS.IMAGE_NAME}-{self.s2i_app.app_name}",
            cmd="npm config get cache"
        ).strip()
        assert PodmanCLIWrapper.podman_run_command_and_remove(
            cid_file_name=f"{VARS.IMAGE_NAME}-{self.s2i_app.app_name}",
            cmd=f"test -d {cache_loc}",
            return_output=False
        ) == 0

    # test_dev_mode_true_development
    # test_dev_mode_false_production
    @pytest.mark.parametrize(
        "dev_mode,node_env",
        [
            ("true", "development"),
            ("false", "development"),
        ]
    )
    def test_dev_node(self, dev_mode, node_env):
        assert self.s2i_app.create_container(
            cid_file_name=self.s2i_app.app_name,
            container_args=f"--user 100001 \'-e DEV_MODE={dev_mode}\'"
        )
        cip = self.s2i_app.get_cip(cid_file_name=self.s2i_app.app_name)
        assert cip
        assert self.s2i_app.test_response(
            url=f"http://{cip}"
        )
        logs = self.s2i_app.get_logs(self.s2i_app.app_name)
        assert re.search(f"DEV_MODE={dev_mode}", logs)
        assert re.search("DEBUG_PORT=5858", logs)
        assert re.search(f"NODE_ENV={node_env}", logs)

    # test_node_cmd_development_init_wrapper_true
    # test_node_cmd_production_init_wrapper_true
    # test_node_cmd_development_init_wrapper_false
    @pytest.mark.parametrize(
        "node_env,init_wrapper,node_cmd",
        [
            ("development", "true", "node server.js"),
            ("production", "true", "node server.js"),
            ("production", "false", "node server.js"),
        ]
    )
    def test_node_cmd_development(self, node_env, init_wrapper, node_cmd):
        assert self.s2i_app.create_container(
          cid_file_name=self.s2i_app.app_name,
          container_args=f"--user 100001 \'-e NODE_ENV={node_env} "
                         f"-e INIT_WRAPPER={init_wrapper} -e NODE_CMD={node_cmd}\'"
        )
        cip = self.s2i_app.get_cip(cid_file_name=self.s2i_app.app_name)
        assert cip
        assert self.s2i_app.test_response(
            url=f"http://{cip}"
        )
        logs = self.s2i_app.get_logs(self.s2i_app.app_name)
        assert re.search(f"NODE_ENV={node_env}", logs)
        assert re.search("DEBUG_PORT=5858", logs)
        assert re.search(f"INIT_WRAPPER={init_wrapper}", logs)
        assert re.search(f"NODE_CMD={node_cmd}", logs)


class TestNodeJSAppsHWContainer:

    def setup_method(self):
        http_proxy = "http://user.password@0.0.0.0:8080"
        https_proxy = "https://user.password@0.0.0.0:8080"
        self.s2i_app = build_s2i_app(
            test_hw, container_args=f"-e HTTP_PROXY={http_proxy} -e http_proxy={http_proxy} "
                                    f"-e HTTPS_PROXY={https_proxy} -e https_proxy={https_proxy}"
        )

    def teardown_method(self):
        self.s2i_app.cleanup()

    def test_run_app_application(self):
        assert self.s2i_app.create_container(
            cid_file_name=self.s2i_app.app_name, container_args="--user 100001"
        )
        cip = self.s2i_app.get_cip(cid_file_name=self.s2i_app.app_name)
        assert cip
        assert self.s2i_app.test_response(
            url=f"http://{cip}"
        )

    # test_init_wrapper_false_development
    @pytest.mark.parametrize(
        "node_env,init_wrapper",
        [
            ("development", "false"),

        ]
    )
    def test_node_init_wrapper(self, node_env, init_wrapper):
        skip_for_minimal()
        assert self.s2i_app.create_container(
            cid_file_name=self.s2i_app.app_name,
            container_args=f"--user 100001 \'-e NODE_ENV={node_env} "
                           f"-e INIT_WRAPPER={init_wrapper}\'"
        )
        logs = self.s2i_app.get_logs(self.s2i_app.app_name)
        cip = self.s2i_app.get_cip(cid_file_name=self.s2i_app.app_name)
        assert cip
        assert self.s2i_app.test_response(
            url=f"http://{cip}",
            debug=True
        )
        assert re.search(f"NODE_ENV={node_env}", logs)
        assert re.search("DEBUG_PORT=5858", logs)
        assert re.search(f"INIT_WRAPPER={init_wrapper}", logs)

    # test_node_cmd_development_init_wrapper_true
    @pytest.mark.parametrize(
        "node_env,init_wrapper,node_cmd",
        [
            ("development", "true", "node server.js"),
        ]
    )
    def test_node_cmd_development(self, node_env, init_wrapper, node_cmd):
        skip_for_minimal()
        assert self.s2i_app.create_container(
          cid_file_name=self.s2i_app.app_name,
          container_args=f"--user 100001 \'-e NODE_ENV={node_env} "
                         f"-e INIT_WRAPPER={init_wrapper} -e NODE_CMD={node_cmd}\'"
        )
        cip = self.s2i_app.get_cip(cid_file_name=self.s2i_app.app_name)
        assert cip
        assert self.s2i_app.test_response(
            url=f"http://{cip}"
        )
        logs = self.s2i_app.get_logs(self.s2i_app.app_name)
        assert re.search(f"NODE_ENV={node_env}", logs)
        assert re.search("DEBUG_PORT=5858", logs)
        assert re.search(f"INIT_WRAPPER={init_wrapper}", logs)
        assert re.search(f"NODE_CMD={node_cmd}", logs)

    def test_safe_logging(self):
        podman_log_file = self.s2i_app.get_podman_build_log_file()
        assert podman_log_file.count("redacted") == 4
        assert "redacted" in podman_log_file


class TestNodeJSIncrementalAppContainer:

    def setup_method(self):
        self.build1 = build_s2i_app(test_incremental)
        self.build2 = build_s2i_app(test_incremental, container_args="--incremental")

    def teardown_method(self):
        self.build1.cleanup()
        self.build2.cleanup()

    def test_incremental_build(self):
        skip_for_minimal()
        build_log1 = self.build1.get_podman_build_log_file()
        build_log2 = self.build2.get_podman_build_log_file()
        assert build_log1 != build_log2
