import os
import platform
import subprocess

def main():
	system = platform.system()
	if system == "Windows":
		subprocess.call(["setup.bat"])
	elif system == "Linux":
		subprocess.call(["bash", "setup.sh"])
	else:
		print(f"Unsupported operating system: {system}")

if __name__ == "__main__":
	main()
