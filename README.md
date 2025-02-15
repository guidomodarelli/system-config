# System config

Repository designed to configure your system effortlessly, thanks to our comprehensive collection of resources that simplify the entire setup process.

## Requirements

To ensure that all submodules are initialized and updated, run the following command:

```sh
git submodule update --init --recursive
```

## Installation

In Linux:

1. Read `SETUP.md`: Before proceeding with the installation, make sure to read
   the `SETUP.md` file. It contains detailed instructions on how to use the
   setup `script`, including how to run the entire script or specific functions.

2. Run the setup `script`: Execute the setup script to install and configure
   various tools and dependencies. This script is designed for Arch Linux-based
   systems.

	```bash
	./setup.sh
	```

3. Run `dotfiler.sh`: After running the setup script, execute the `dotfiler.sh`
   script to set up your dotfiles and other configurations.

	```sh
	./dotfiler.sh
	```

In Windows:

1. Read `SETUP.md`: Before proceeding with the installation, make sure to read
   the `SETUP.md` file. It contains detailed instructions on how to use the
   setup script, including how to run the entire script or specific functions.

2. Run the setup `script`: Open PowerShell as Administrator and execute the
   setup.bat `script` to install and configure various tools and dependencies
   using Chocolatey.

	```ps1
	.\setup.bat
	```
