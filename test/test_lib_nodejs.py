#!/usr/bin/env python3
"""
Functions for tests for the Node.js image.

IMAGE_NAME specifies a name of the candidate image used for testing.
The image has to be available before this script is executed.
"""

import os
import sys
import subprocess
import tempfile
import shutil
from pathlib import Path
import re

# Get the directory of this script
THISDIR = Path(__file__).parent.resolve()

# Import common test library
sys.path.insert(0, str(THISDIR.parent / "common"))
# Note: test_lib.py would need to be created from test-lib.sh

test_dir = THISDIR

def info(message):
    """Print an info message with formatting."""
    print(f"\n\033[1m[INFO] {message}...\033[0m\n", flush=True)

def check_prep_result(result, app):
    """Check preparation result and update test result if failed."""
    if result != 0:
        # This would call ct_update_test_result from test_lib
        print(f"[FAILED] {app} preparation")
        global TESTSUITE_RESULT
        TESTSUITE_RESULT = 1
        return result
    return 0

def image_exists(image_name):
    """Check if a Docker image exists."""
    try:
        subprocess.run(
            ["docker", "inspect", image_name],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=True
        )
        return True
    except subprocess.CalledProcessError:
        return False

def container_exists(cid_file):
    """Check if a container exists based on cid file."""
    try:
        with open(cid_file, 'r') as f:
            cid = f.read().strip()
        return image_exists(cid)
    except (FileNotFoundError, IOError):
        return False

def container_ip(cid_file):
    """Get container IP address from cid file."""
    try:
        with open(cid_file, 'r') as f:
            cid = f.read().strip()
        result = subprocess.run(
            ["docker", "inspect", "--format={{ .NetworkSettings.IPAddress }}", cid],
            capture_output=True,
            text=True,
            check=True
        )
        return result.stdout.strip()
    except (subprocess.CalledProcessError, FileNotFoundError, IOError):
        return ""

def container_logs(cid_file):
    """Get container logs from cid file."""
    try:
        with open(cid_file, 'r') as f:
            cid = f.read().strip()
        result = subprocess.run(
            ["docker", "logs", cid],
            capture_output=True,
            text=True,
            check=True
        )
        return result.stdout
    except (subprocess.CalledProcessError, FileNotFoundError, IOError):
        return ""

def run_s2i_build(s2i_args="", npm_variables="", extra_args=""):
    """Run S2I build for test-app."""
    image_name = os.environ.get('IMAGE_NAME', '')
    cmd_args = f"file://{test_dir}/test-app {image_name} {image_name}-testapp {s2i_args} {npm_variables} {extra_args}"
    # This would call ct_s2i_build_as_df from test_lib
    # For now, returning a placeholder
    return subprocess.run(
        f"ct_s2i_build_as_df {cmd_args}",
        shell=True,
        capture_output=True,
        text=True
    )

def run_s2i_build_fips(s2i_args="", npm_variables="", extra_args=""):
    """Run S2I build for test-fips."""
    image_name = os.environ.get('IMAGE_NAME', '')
    cmd_args = f"file://{test_dir}/test-fips {image_name} {image_name}-testfips {s2i_args} {npm_variables} {extra_args}"
    return subprocess.run(
        f"ct_s2i_build_as_df {cmd_args}",
        shell=True,
        capture_output=True,
        text=True
    )

def run_s2i_build_proxy(http_proxy, https_proxy, s2i_args="", npm_variables=""):
    """Run S2I build with proxy settings."""
    image_name = os.environ.get('IMAGE_NAME', '')
    cmd = (
        f"ct_s2i_build_as_df file://{test_dir}/test-hw {image_name} "
        f"{image_name}-testhw {s2i_args} {npm_variables} "
        f"-e HTTP_PROXY={http_proxy} -e http_proxy={http_proxy} "
        f"-e HTTPS_PROXY={https_proxy} -e https_proxy={https_proxy}"
    )
    return subprocess.run(cmd, shell=True, capture_output=True, text=True)

def run_s2i_build_client(client_name, s2i_args="", npm_variables=""):
    """Run S2I build for client applications."""
    image_name = os.environ.get('IMAGE_NAME', '')
    cmd = (
        f"ct_s2i_build_as_df_build_args "
        f"\"file://{test_dir}/{client_name}\" \"{image_name}\" \"{image_name}-{client_name}\" "
        f"\"--ulimit nofile=4096:4096\" {s2i_args} {npm_variables} "
        f"-e NODE_ENV=development -e CI=true"
    )
    return subprocess.run(cmd, shell=True, capture_output=True, text=True)

def run_s2i_build_binary(s2i_args="", npm_variables="", extra_args=""):
    """Run S2I build for test-binary."""
    image_name = os.environ.get('IMAGE_NAME', '')
    cmd = (
        f"ct_s2i_build_as_df file://{test_dir}/test-binary {image_name} "
        f"{image_name}-testbinary {s2i_args} {npm_variables} {extra_args} -e CI=true"
    )
    return subprocess.run(cmd, shell=True, capture_output=True, text=True)

def run_s2i_multistage_build(npm_variables=""):
    """Run S2I multistage build."""
    image_name = os.environ.get('IMAGE_NAME', '')
    full_image = os.environ.get('FULL_IMAGE', '')
    cmd = (
        f"ct_s2i_multistage_build file://{test_dir}/test-app "
        f"{full_image} {image_name} {image_name}-testapp {npm_variables}"
    )
    return subprocess.run(cmd, shell=True, capture_output=True, text=True)

def prepare_dummy_git_repo(gitconfig):
    """Prepare a dummy git repository."""
    subprocess.run(["git", "init"], check=True)
    for key, value in gitconfig.items():
        subprocess.run(["git", "config", "--local", key, value], check=True)
    subprocess.run(["git", "add", "--all"], check=True)
    subprocess.run(["git", "commit", "-m", "Sample commit"], check=True)

def prepare_client_repo(dest, repo_url, revision, gitconfig):
    """Clone and prepare a client repository."""
    subprocess.run([
        "git", "clone",
        "--config", "advice.detachedHead=false",
        "--branch", revision,
        "--depth", "1",
        repo_url, dest
    ], check=True)

    cwd = os.getcwd()
    try:
        os.chdir(dest)
        for key, value in gitconfig.items():
            subprocess.run(["git", "config", "--local", key, value], check=True)
    finally:
        os.chdir(cwd)

def prepare_minimal_build(suffix):
    """Prepare minimal build."""
    image_name = os.environ.get('IMAGE_NAME', '')
    full_image = os.environ.get('FULL_IMAGE', '')

    if suffix == "testapp":
        run_s2i_multistage_build()
    elif suffix == "testhw":
        # Set IMAGE_NAME to FULL_IMAGE temporarily
        old_image_name = os.environ.get('IMAGE_NAME', '')
        os.environ['IMAGE_NAME'] = full_image

        with open('/tmp/build-log', 'w') as f:
            result = run_s2i_build_proxy(
                "http://user.password@0.0.0.0:8000",
                "https://user.password@0.0.0.0:8000"
            )
            f.write(result.stdout)
            f.write(result.stderr)

        os.environ['IMAGE_NAME'] = old_image_name

        # Get application from assembled image
        tempdir = tempfile.mkdtemp()
        os.chown(tempdir, 1001, 0)
        subprocess.run([
            "docker", "run", "-u", "0", "--rm", "-ti",
            "-v", f"{tempdir}:{tempdir}:Z",
            f"{full_image}-{suffix}",
            "bash", "-c", f"cp -ar /opt/app-root/src {tempdir}"
        ], check=True)

        cwd = os.getcwd()
        try:
            os.chdir(tempdir)

            # Create Dockerfile
            dockerfile_content = f"""FROM {image_name}
ADD src/* /opt/app-root/src
CMD /usr/libexec/s2i/run
"""
            # Check for CA authority
            ca_file = full_ca_file_path()
            if ca_file and os.path.isfile(ca_file):
                dockerfile_content += """USER 0
RUN cd /etc/pki/ca-trust/source/anchors && update-ca-trust extract
USER 1001
"""

            with open('Dockerfile', 'w') as f:
                f.write(dockerfile_content)

            # Build image
            subprocess.run([
                "docker", "build", "-t", f"{image_name}-{suffix}", "."
            ], check=True)
        finally:
            os.chdir(cwd)
    else:
        print("Please specify a valid test application")
        return 1

    return 0

def full_ca_file_path():
    """Get full CA file path - placeholder."""
    # This would be implemented based on test-lib.sh
    return None

def prepare(app, test_list_clients="", gitconfig=None):
    """Prepare test application."""
    image_name = os.environ.get('IMAGE_NAME', '')

    if not image_exists(image_name):
        print(f"ERROR: The image {image_name} must exist before this script is executed.")
        return 1

    if gitconfig is None:
        gitconfig = {}

    if app in ["app", "hw", "fips", "express-webapp", "binary"]:
        cwd = os.getcwd()
        try:
            os.chdir(f"{test_dir}/test-{app}")
            prepare_dummy_git_repo(gitconfig)
        finally:
            os.chdir(cwd)
    elif app in test_list_clients.split():
        prefix = app.replace("-", "")
        repo_var = f"{prefix.upper()}_REPO"
        revision_var = f"{prefix.upper()}_REVISION"

        repo = os.environ.get(repo_var, "")
        revision = os.environ.get(revision_var, "")

        prepare_client_repo(f"{test_dir}/{app}", repo, revision, gitconfig)
    else:
        print("Please specify a valid test application")
        return 1

    return 0

def run_test_application(app, extra_args="", cid_file_dir=""):
    """Run test application in a container."""
    image_name = os.environ.get('IMAGE_NAME', '')

    if app not in ["app", "fips", "hw", "express-webapp", "binary"]:
        print("No such test application")
        return None

    cid_file = os.path.join(
        cid_file_dir,
        next(tempfile._get_candidate_names()) + ".cid"
    )

    cmd = [
        "docker", "run", "-d", "--user=100001",
        "--rm", f"--cidfile={cid_file}"
    ]

    if extra_args:
        cmd.extend(extra_args.split())

    cmd.append(f"{image_name}-test{app}")

    subprocess.run(cmd, check=True)
    return cid_file

def run_test_application_with_quoted_args(app, extra_args="", cid_file_dir=""):
    """Run test application with quoted arguments."""
    return run_test_application(app, extra_args, cid_file_dir)

def run_client_test_suite(client_name, cid_file_dir=""):
    """Run client test suite."""
    image_name = os.environ.get('IMAGE_NAME', '')

    cid_file = os.path.join(
        cid_file_dir,
        next(tempfile._get_candidate_names()) + ".cid"
    )

    cmd = "npm test"
    # Skip style check tests for prom-client
    if client_name == "prom-client":
        cmd = f"sed -i.bak 's/&& npm run check-prettier //g' package.json && {cmd}"

    subprocess.run([
        "docker", "run", "--user=100001",
        "-e", "CI=true", "--rm", f"--cidfile={cid_file}",
        f"{image_name}-{client_name}",
        "bash", "-c", cmd
    ], check=True)

def kill_test_application(cid_file):
    """Kill a running test application."""
    if cid_file and os.path.isfile(cid_file):
        with open(cid_file, 'r') as f:
            cid = f.read().strip()
        subprocess.run(["docker", "kill", cid], check=True)

def wait_for_cid(cid_file, max_attempts=20, sleep_time=1):
    """Wait for container ID file to be created."""
    import time

    for attempt in range(1, max_attempts + 1):
        if os.path.isfile(cid_file) and os.path.getsize(cid_file) > 0:
            return True
        print("Waiting for container start...")
        time.sleep(sleep_time)

    return False

def test_s2i_usage(image_name, s2i_args=""):
    """Test s2i usage."""
    print("Testing 's2i usage'...")
    result = subprocess.run(
        f"ct_s2i_usage {image_name} {s2i_args}",
        shell=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    )
    # ct_check_testcase_result would be called here
    return result.returncode

def test_docker_run_usage(image_name):
    """Test docker run usage."""
    print("Testing 'docker run' usage...")
    result = subprocess.run(
        ["docker", "run", "--rm", image_name],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    )
    return result.returncode

def test_connection(cid_file, test_port=8080, max_attempts=10, sleep_time=1):
    """Test HTTP connection to container."""
    import time

    print("Testing HTTP connection...")

    for attempt in range(1, max_attempts + 1):
        ip = container_ip(cid_file)
        url = f"http://{ip}:{test_port}/"
        print(f"Sending GET request to {url}")

        try:
            result = subprocess.run(
                ["curl", "-s", "-w", "%{http_code}", "-o", "/dev/null", url],
                capture_output=True,
                text=True,
                timeout=5
            )

            if result.returncode == 0 and result.stdout.strip() == "200":
                return 0
        except subprocess.TimeoutExpired:
            pass

        time.sleep(sleep_time)

    return 1

def scl_usage(cid_file, image_name, run_cmd, expected):
    """Test SCL usage."""
    print("Testing the image SCL enable ...")

    # Test with docker run
    result = subprocess.run(
        ["docker", "run", "--rm", image_name, "/bin/bash", "-c", run_cmd],
        capture_output=True,
        text=True
    )

    if expected not in result.stdout:
        print(f"ERROR[/bin/bash -c \"{run_cmd}\"] Expected '{expected}', got '{result.stdout}'")
        return 1

    # Test with docker exec bash
    with open(cid_file, 'r') as f:
        cid = f.read().strip()

    result = subprocess.run(
        ["docker", "exec", cid, "/bin/bash", "-c", run_cmd],
        capture_output=True,
        text=True
    )

    if expected not in result.stdout and expected not in result.stderr:
        combined = result.stdout + result.stderr
        print(f"ERROR[exec /bin/bash -c \"{run_cmd}\"] Expected '{expected}', got '{combined}'")
        return 1

    # Test with docker exec sh -ic
    result = subprocess.run(
        ["docker", "exec", cid, "/bin/sh", "-ic", run_cmd],
        capture_output=True,
        text=True
    )

    combined = result.stdout + result.stderr
    if expected not in combined:
        print(f"ERROR[exec /bin/sh -ic \"{run_cmd}\"] Expected '{expected}', got '{combined}'")
        return 1

    return 0

def test_scl_usage(cid_file, image_name):
    """Test SCL usage for Node.js."""
    version = os.environ.get('VERSION', '').replace('-minimal', '')

    if version == "22":
        run_cmd = f"node-{version} --version"
    else:
        run_cmd = "node --version"

    expected = f"v{version}."
    return scl_usage(cid_file, image_name, run_cmd, expected)

def validate_default_value(image_name, label):
    """Validate default value for a label."""
    result = subprocess.run(
        ["docker", "inspect", "-f", f"{{{{index .Config.Labels \"{label}\"}}}}", image_name],
        capture_output=True,
        text=True,
        check=True
    )

    label_vals = result.stdout.strip().split(':')
    label_var = label_vals[0]
    default_label_val = label_vals[1] if len(label_vals) > 1 else ""

    result = subprocess.run(
        ["docker", "run", "--rm", image_name, "/bin/bash", "-c", f"echo ${label_var}"],
        capture_output=True,
        text=True,
        check=True
    )

    actual_label_val = result.stdout.strip()

    if actual_label_val != default_label_val:
        print(f"ERROR default value for {label} with environment variable {label_var}; "
              f"Expected {default_label_val}, got {actual_label_val}")
        return 1

    return 0

def get_node_env_from_container(image_name, dev_mode, node_env):
    """Get NODE_ENV environment variable from container."""
    result = subprocess.run(
        ["docker", "inspect", "-f", "{{index .Config.Labels \"com.redhat.dev-mode\"}}", image_name],
        capture_output=True,
        text=True,
        check=True
    )

    label_val = result.stdout.strip().split(':')
    dev_mode_label_var = label_val[0]

    result = subprocess.run(
        ["docker", "run", "--rm",
         "--env", f"{dev_mode_label_var}={dev_mode}",
         "--env", f"NODE_ENV={node_env}",
         image_name, "/bin/bash", "-c", 'echo "$NODE_ENV"'],
        capture_output=True,
        text=True,
        check=True
    )

    return result.stdout.strip()

def validate_node_env(image_name, current_val, dev_mode_val, expected):
    """Validate NODE_ENV value."""
    actual = get_node_env_from_container(image_name, dev_mode_val, current_val)

    if actual != expected:
        print(f"ERROR default value for NODE_ENV when development mode is {dev_mode_val}; "
              f"should be {expected} but is {actual}")
        return 1

    return 0

def test_incremental_build(image_name, s2i_args="", npm_variables=""):
    """Test incremental build."""
    # First build
    result1 = subprocess.run(
        f"ct_s2i_build_as_df file://{test_dir}/test-incremental {image_name} "
        f"{image_name}-testapp {s2i_args} {npm_variables}",
        shell=True,
        capture_output=True,
        text=True
    )

    if result1.returncode != 0:
        return 1

    # Second build with --incremental
    result2 = subprocess.run(
        f"ct_s2i_build_as_df file://{test_dir}/test-incremental {image_name} "
        f"{image_name}-testapp {s2i_args} {npm_variables} --incremental",
        shell=True,
        capture_output=True,
        text=True
    )

    if result2.returncode != 0:
        return 1

    # Compare package counts
    match1 = re.search(r'added (\d+) packages', result1.stdout)
    match2 = re.search(r'added (\d+) packages', result2.stdout)

    if match1 and match2:
        first = match1.group(1)
        second = match2.group(1)

        if first == second:
            print(f"ERROR Incremental build failed: both builds installed {first} packages")
            return 1

    return 0

def cleanup(image_name):
    """Cleanup test application image."""
    info(f"Cleaning up the test application image {image_name}-testapp")

    if image_exists(f"{image_name}-testapp"):
        info(f"Image {image_name}-testapp exists...removing it")
        result = subprocess.run(
            ["docker", "rmi", "-f", f"{image_name}-testapp"],
            capture_output=True
        )
        print(result.returncode)
        info(f"Removed by docker rmi {image_name}-testapp")

# Global variable for test suite result
TESTSUITE_RESULT = 0
