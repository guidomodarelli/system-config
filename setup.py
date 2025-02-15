import platform
import subprocess

def main():
	try:
		system = platform.system()
		if system == "Windows":
			subprocess.call(["setup.bat"])
		elif system == "Linux":
			subprocess.call(["bash", "setup.sh"])
		else:
			print(f"Unsupported operating system: {system}")
	except KeyboardInterrupt:
		print("\nProcess interrupted by user. Exiting gracefully.")

if __name__ == "__main__":
	main()
