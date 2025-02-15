import platform
import subprocess
import pathlib

def main():
	try:
		script_dir = pathlib.Path("scripts/setup")
		system = platform.system()
		if system == "Windows":
			script_path = script_dir / "setup.ps1"
			subprocess.call(["powershell", "-ExecutionPolicy", "Bypass", "-Command", str(script_path.absolute())])
		elif system == "Linux":
			script_path = script_dir / "setup.sh"
			subprocess.call([str(script_path.absolute())])
		else:
			print(f"Unsupported operating system: {system}")
	except KeyboardInterrupt:
		print("\nProcess interrupted by user. Exiting gracefully.")
	except Exception as e:
		print(f"An error occurred: {e}")

if __name__ == "__main__":
	main()
