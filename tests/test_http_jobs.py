"""Exercise real editor job callbacks against a local HTTP server.

Run with: python3 -m unittest discover -s tests -v
Set AW_TEST_EDITORS to a path-separated list to override vim/nvim discovery.
"""

import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import tempfile
import threading
import time
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


PLUGIN = Path(__file__).resolve().parents[1] / "plugin/activitywatch.vim"
EDITORS = list(
    dict.fromkeys(
        os.environ["AW_TEST_EDITORS"].split(os.pathsep)
        if "AW_TEST_EDITORS" in os.environ
        else (
            str(Path(editor).resolve())
            for editor in (shutil.which("vim"), shutil.which("nvim"))
            if editor
        )
    )
)


class HTTPJobsTest(unittest.TestCase):
    def setUp(self):
        if not EDITORS:
            self.skipTest("Vim or Neovim is required")

    def serve(self, respond):
        """Serve POSTs on an OS-chosen port; respond(path) returns the status."""
        requests = []

        class Handler(BaseHTTPRequestHandler):
            def do_POST(self):
                requests.append(self.path)
                self.rfile.read(int(self.headers["Content-Length"]))
                self.send_response(respond(self.path))
                self.end_headers()

            def log_message(self, *args):
                pass

        server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()

        def stop():
            server.shutdown()
            thread.join()
            server.server_close()

        self.addCleanup(stop)
        return server.server_port, requests

    def run_editor(
        self, editor, port, curl_script=None, api_timeout="1", commands=None
    ):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            result = root / "result.json"
            script = root / "probe.vim"
            script.write_text(
                "\n".join(
                    [
                        "set nomore",
                        "let g:aw_apiurl_host = '127.0.0.1'",
                        f"let g:aw_apiurl_port = {port}",
                        f"let g:aw_api_timeout = {api_timeout}",
                        "let g:aw_hostname = 'http-job-test'",
                        f"source {PLUGIN}",
                        *(
                            commands
                            or ["AWStart", "sleep 500m", "AWHeartbeat", "sleep 500m"]
                        ),
                        f"call writefile([json_encode({{'messages': execute('messages'), 'status': execute('AWStatus'), 'error': v:errmsg, 'vars': get(g:, 'aw_test', {{}})}})], '{result}')",
                        "qa!",
                    ]
                )
                + "\n"
            )
            env = os.environ.copy()
            env["NO_PROXY"] = "127.0.0.1"
            if curl_script is not None:
                curl = root / "curl"
                curl.write_text(curl_script)
                curl.chmod(0o755)
                env["PATH"] = str(root)
            version = subprocess.check_output([editor, "--version"], env=env, text=True)
            mode = ["--headless"] if version.startswith("NVIM") else ["-es"]
            process = subprocess.run(
                [editor, *mode, "-u", "NONE", "-n", "-S", str(script)],
                env=env,
                capture_output=True,
                text=True,
                timeout=10,
            )
            self.assertTrue(result.exists(), process.stderr)
            return json.loads(result.read_text())

    def test_refused_connection_reports_endpoint_and_curl_error(self):
        with socket.socket() as sock:
            sock.bind(("127.0.0.1", 0))
            port = sock.getsockname()[1]
            for editor in EDITORS:
                with self.subTest(editor=editor):
                    result = self.run_editor(editor, port)
                    self.assertIn(
                        f"http://127.0.0.1:{port}/api/0/buckets/", result["messages"]
                    )
                    self.assertIn("curl: (7)", result["messages"])
                    self.assertIn("running: 0", result["status"])

    def test_empty_stdout_reports_error_without_missing_dictionary_key(self):
        for editor in EDITORS:
            with self.subTest(editor=editor):
                result = self.run_editor(
                    editor,
                    5600,
                    "#!/bin/sh\necho 'curl diagnostic with no stdout' >&2\nexit 7\n",
                )
                self.assertNotIn("E716", result["messages"])
                self.assertIn("curl diagnostic with no stdout", result["messages"])
                self.assertIn("running: 0", result["status"])

    def test_status_code_split_across_stdout_callbacks(self):
        for editor in EDITORS:
            with self.subTest(editor=editor):
                result = self.run_editor(
                    editor,
                    5600,
                    "#!/bin/sh\nprintf 2\n/bin/sleep 0.1\nprintf 01\n",
                )
                self.assertIn("running: 1", result["status"])
                self.assertEqual("", result["error"])

    def test_float_api_timeout_starts_plugin(self):
        # The README documents `2.0`; a Float in the job argv used to raise E806.
        # Succeed only when curl receives the timeout as the plain value `0.5`.
        curl = '#!/bin/sh\ncase "$*" in *"-m 0.5 "*) printf 200;; esac\n'
        for editor in EDITORS:
            for value in ("0.5", "'0.5'"):
                with self.subTest(editor=editor, value=value):
                    result = self.run_editor(editor, 5600, curl, api_timeout=value)
                    self.assertNotIn("E806", result["messages"])
                    self.assertIn("running: 1", result["status"])

    def test_http_success_and_rejection(self):
        for status in (201, 503):
            requests = []

            class Handler(BaseHTTPRequestHandler):
                def do_POST(self):
                    requests.append(self.path)
                    self.rfile.read(int(self.headers["Content-Length"]))
                    self.send_response(status)
                    self.end_headers()

                def log_message(self, *args):
                    pass

            with ThreadingHTTPServer(("127.0.0.1", 0), Handler) as server:
                thread = threading.Thread(target=server.serve_forever, daemon=True)
                thread.start()
                try:
                    for editor in EDITORS:
                        with self.subTest(editor=editor, status=status):
                            requests.clear()
                            result = self.run_editor(editor, server.server_port)
                            if status == 201:
                                self.assertIn("running: 1", result["status"])
                                self.assertEqual("", result["error"])
                                self.assertTrue(
                                    any("/heartbeat?" in path for path in requests)
                                )
                            else:
                                self.assertIn("status code 503", result["messages"])
                                self.assertIn("running: 0", result["status"])
                finally:
                    server.shutdown()
                    thread.join()

    # Send a heartbeat right away by changing the reported language, instead of
    # waiting out the plugin's one-heartbeat-per-second throttle.
    HEARTBEATS = [
        f"set filetype=lang{n}\nAWHeartbeat\nsleep 400m" for n in range(1, 4)
    ]

    def test_deleted_bucket_is_recreated_once_without_errors(self):
        # The bucket disappears after the first heartbeat, as when it is deleted
        # in the web UI or aw-server restarts onto a fresh database.
        state = {"bucket": False, "heartbeats": 0}

        def respond(path):
            if "/heartbeat?" not in path:
                state["bucket"] = True
                return 200
            state["heartbeats"] += 1
            if state["heartbeats"] == 1:
                state["bucket"] = False
                return 200
            return 200 if state["bucket"] else 404

        port, requests = self.serve(respond)
        commands = ["AWStart", "sleep 500m", *self.HEARTBEATS]
        for editor in EDITORS:
            with self.subTest(editor=editor):
                requests.clear()
                state.update(bucket=False, heartbeats=0)
                result = self.run_editor(editor, port, commands=commands)
                creates = [path for path in requests if "/heartbeat?" not in path]
                self.assertEqual(2, len(creates), requests)
                self.assertNotIn("status code", result["messages"])
                self.assertEqual("", result["error"])
                self.assertIn("running: 1", result["status"])
                # Heartbeats resume against the re-created bucket.
                self.assertTrue(requests[-1].endswith("/heartbeat?pulsetime=30"))

    def test_heartbeat_rejection_disconnects_with_one_error(self):
        # A bucket that cannot be re-created (404 persists) and any other error
        # status both stop heartbeats instead of erroring on every cursor move.
        for status in (404, 500):
            port, requests = self.serve(
                lambda path, status=status: status if "/heartbeat?" in path else 200
            )
            commands = ["AWStart", "sleep 500m", *self.HEARTBEATS]
            for editor in EDITORS:
                with self.subTest(editor=editor, status=status):
                    requests.clear()
                    result = self.run_editor(editor, port, commands=commands)
                    self.assertEqual(
                        1, result["messages"].count(f"status code {status}")
                    )
                    self.assertIn(":AWStart", result["messages"])
                    self.assertNotIn(":AWStop", result["messages"])
                    self.assertIn("running: 0", result["status"])
                    heartbeats = [p for p in requests if "/heartbeat?" in p]
                    self.assertEqual(1 if status == 500 else 2, len(heartbeats))

    def test_stop_wins_over_late_success_reply(self):
        # A heartbeat sent just before :AWStop (e.g. by CmdlineEnter when
        # :AWStop is mapped) must not reconnect the plugin when it succeeds.
        def respond(path):
            if "/heartbeat?" in path:
                time.sleep(0.5)
            return 200

        port, requests = self.serve(respond)
        commands = [
            "AWStart",
            "sleep 500m",
            "AWHeartbeat",
            "AWStop",
            "sleep 1000m",
            "let g:aw_test = {'stopped': execute('AWStatus')}",
            "AWStart",
            "sleep 500m",
        ]
        for editor in EDITORS:
            with self.subTest(editor=editor):
                requests.clear()
                result = self.run_editor(editor, port, commands=commands)
                self.assertIn("running: 0", result["vars"]["stopped"])
                self.assertIn("running: 1", result["status"])
                self.assertEqual("", result["error"])


if __name__ == "__main__":
    unittest.main()
