#!/usr/bin/env python3

import platform
import subprocess
from pathlib import Path
import sys

def setup_windows(setup_dir: Path, args: list[str]):
	setup_script_path = setup_dir / "setup.ps1"
	subprocess.run(
		["powershell", "-ExecutionPolicy", "Bypass", "-File", str(setup_script_path.absolute())] + args,
		check=True,
	)

def setup_linux(setup_dir: Path, args: list[str]):
	setup_script_path = setup_dir / "setup.sh"
	subprocess.run([str(setup_script_path.absolute())] + args, check=True)

	dotfiler_path = Path("dotfiler.sh")
	subprocess.run([str(dotfiler_path.absolute())], check=True)

def main(args: list[str]) -> int:
	try:
		script_dir = Path("scripts")
		setup_dir = script_dir / "setup"
		system = platform.system()
		if system == "Windows":
			setup_windows(setup_dir, args)
		elif system == "Linux":
			setup_linux(setup_dir, args)
		else:
			print(f"Unsupported operating system: {system}")
			return 1

		print("Setup complete.")
		return 0
	except KeyboardInterrupt:
		print("\nProcess interrupted by user. Exiting gracefully.")
		return 130
	except subprocess.CalledProcessError as error:
		print(f"Setup failed with exit code {error.returncode}.")
		return error.returncode
	except Exception as error:
		print(f"An error occurred: {error}")
		return 1

if __name__ == "__main__":
	sys.exit(main(sys.argv[1:]))
