import http.server
import json
import pathlib
import subprocess
import tempfile
import threading

loaded = threading.Event()


def production_succeeded(exit_code, page_executed, diagnostics):
    """Reject native failure diagnostics even when the helper exits successfully."""
    return page_executed and exit_code == 0 and "Lich WebUI: " not in diagnostics


class Page(http.server.BaseHTTPRequestHandler):
    """Serve a loopback page that exercises the packaged native bridge."""

    def do_GET(self):
        if self.path == "/ready":
            loaded.set()
            body = b"ok"
        else:
            body = b"""<!doctype html><title>Native production smoke</title>
<script>
window.addEventListener('load', () => {
  window.lichNativeWindow.present({hidden: false, title: 'Native smoke'});
  setTimeout(async () => {
    await fetch('/ready');
    window.close();
  }, 1000);
});
</script>"""
        self.send_response(200)
        self.send_header("Content-Type", "text/html")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *_args):
        pass


out = pathlib.Path("tmp/macos-native")
out.mkdir(parents=True, exist_ok=True)
server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Page)
thread = threading.Thread(target=server.serve_forever, daemon=True)
thread.start()
try:
    with tempfile.TemporaryDirectory(prefix="lich-native-smoke-") as directory:
        launch = pathlib.Path(directory) / "launch"
        launch.write_text(f"http://127.0.0.1:{server.server_port}/")
        launch.chmod(0o600)
        executable = "lib/webui/native/macos/build/LichWebUI.app/Contents/MacOS/LichWebUI"
        with (out / "production.log").open("w") as log:
            result = subprocess.run([executable, str(launch), '{"width":320,"height":200}'],
                                    stdout=log, stderr=subprocess.STDOUT, timeout=45)
        diagnostics = (out / "production.log").read_text()
        evidence = {"exit": result.returncode, "page_executed": loaded.is_set(),
                    "helper_failure_diagnostic_absent": "Lich WebUI: " not in diagnostics,
                    "close": "real packaged window.close bridge", "timeout_seconds": 45}
        (out / "production.json").write_text(json.dumps(evidence, indent=2) + "\n")
        assert production_succeeded(result.returncode, loaded.is_set(), diagnostics), evidence
        print("Production helper loaded the page and closed through its native bridge.")
finally:
    server.shutdown()
    server.server_close()
