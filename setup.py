#!/usr/bin/env python3

import platform
import subprocess
from pathlib import Path
import sys

def setup_windows(script_dir: Path, args: list[str]):
	setup_script_path = script_dir / "setup.ps1"
	subprocess.call(["powershell", "-ExecutionPolicy", "Bypass", "-File", str(setup_script_path.absolute())] + args)

def setup_linux(script_dir: Path, args: list[str]):
	setup_script_path = script_dir / "setup.sh"
	subprocess.call([str(setup_script_path.absolute())] + args)

	dotfiler_path = Path("dotfiler.sh")
	subprocess.call([str(dotfiler_path.absolute())])

def main(args: list[str]):
	try:
		script_dir = Path("scripts/setup")
		system = platform.system()
		if system == "Windows":
			setup_windows(script_dir, args)
		elif system == "Linux":
			setup_linux(script_dir, args)
		else:
			print(f"Unsupported operating system: {system}")
	except KeyboardInterrupt:
		print("\nProcess interrupted by user. Exiting gracefully.")
	except Exception as e:
		print(f"An error occurred: {e}")

if __name__ == "__main__":
	main(sys.argv[1:])
