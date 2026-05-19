# Building VaultOps from Source

If you prefer to verify the code or build the executable yourself, you can compile the project from source using the build scripts in this directory.

---

## Prerequisites

- **AutoHotkey v2.0**  
  *(Required only if you want to run the compiler script manually)*  

- **Python 3.13+**
  *(Required for the OpenCV backend build step)*

- Install Python dependencies:
  ```bash
  pip install -r ./lib/py_helpers/requirements.txt
  ```

- **WinRAR**
  *(Required only for building the standalone solver package)*

- **Inno Setup 6** *(optional, included in this folder)*  

---

## Build Steps

1. Extract the repository to a local folder  
2. Navigate to this directory (`_src/lib/build_scripts/`)  
3. Run `compile_scripts.exe` or `dist.ahk`  
   - A build options dialog will appear  
   - Choose your preferred build settings  
   - The compiled files will be generated in the `_src/dist/` folder  

During the build process:
- The OpenCV backend under `lib/py_helpers/` is automatically compiled using Nuitka
- The generated `OpenCV_Engine.exe` is placed in `lib/py_helpers/`

---

## Build Options

The build script provides a GUI with the following options:

- **Compile and package vaultOps** (Always enabled)
  - Creates the main vaultOps executable and installer

- **Scan build with VirusTotal** (Yes / No, optional)
  - Optionally scans the generated setup file after building
  - On selecting Yes, it will ask for your VirusTotal API key (free account available at [virustotal.com](https://www.virustotal.com))
  - API key is saved locally in `build_options.ini`
  - Opens scan results in your browser automatically and updates `README.md` when complete

- **Compile standalone scripts** (Yes / No - Requires devmode var to be set in build_options.ini)
  - Compiles the standalone puzzle solvers and packages them into a single standalone bundle
  - The standalone package includes shared resources and a shared OpenCV engine to reduce duplicated files
  - A separate `NoSave-Standalone.exe` is also generated independently

- **Replace classes with originals** (Yes / No, conditional)
  - Only available if standalone script compilation is enabled
  - Creates temporary versions with original class definitions for compatibility

---

## Output

After building completes:

- **Main executable:** `_src/vaultOps.exe`
- **OpenCV backend:** `_src/lib/py_helpers/OpenCV_Engine.exe`
- **Updater executable:** `_src/lib/vaultOpsUpdater.exe`
- **Installer:** `_src/dist/vaultOps-Setup.exe`
- **Standalone solvers bundle:** `_src/dist/vaultOps-Standalone-Pack.exe`
- **NoSave standalone:** `_src/dist/NoSave-Standalone.exe`

> [!NOTE]
> The standalone solver package extracts into the `vaultOps-Standalone-Pack` folder in the current directory, containing all standalone solvers and shared resources.

---

## Troubleshooting

**Build fails or executables not found:**
- Ensure AutoHotkey v2.0 is installed and accessible
- Ensure Python 3.13+ is installed and available in PATH
- Verify Python dependencies were installed from `requirements.txt`
- Check that required files/folders exist (`Inno Setup 6/`, `AHK_BASE/`, etc.)
- Verify the repository structure has not been modified

**WinRAR not found:**
- If using standalone packaging, you'll be prompted to locate `WinRAR.exe`
- Ensure WinRAR is installed, or disable standalone SFX packaging

**VirusTotal scan fails:**
- Verify your API key is correct
- Ensure the setup file was created successfully before scanning
- Check if you exceeded your API usage quota
- Ensure internet connectivity is available