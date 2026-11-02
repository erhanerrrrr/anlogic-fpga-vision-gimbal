"""TD process launcher shared by the B7 synthesis runner."""
import subprocess


def run_td(executable, command, directory, log_path, timeout):
    with log_path.open("w", encoding="utf-8") as log_file:
        process = subprocess.run(
            [str(executable)],
            input=command + "\n",
            text=True,
            encoding="utf-8",
            errors="replace",
            cwd=directory,
            stdout=log_file,
            stderr=subprocess.STDOUT,
            timeout=timeout,
            creationflags=subprocess.CREATE_NO_WINDOW,
        )
    if process.returncode != 0:
        raise RuntimeError(f"TD exited with code {process.returncode}. See {log_path}")
    return log_path.read_text(encoding="utf-8", errors="replace")
