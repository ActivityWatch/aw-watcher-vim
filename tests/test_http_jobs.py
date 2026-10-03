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

    def run_editor(self, editor, port, curl_script=None):
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
                        "let g:aw_api_timeout = 1",
                        "let g:aw_hostname = 'http-job-test'",
                        f"source {PLUGIN}",
                        "AWStart",
                        "sleep 500m",
                        "AWHeartbeat",
                        "sleep 500m",
                        f"call writefile([json_encode({{'messages': execute('messages'), 'status': execute('AWStatus'), 'error': v:errmsg}})], '{result}')",
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


if __name__ == "__main__":
    unittest.main()
