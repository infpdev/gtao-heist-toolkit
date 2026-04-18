# Building VaultOps from Source

If you prefer to verify the code or build the executable yourself, you can compile the project from source using the build scripts in this directory.

---

## Prerequisites

- **AutoHotkey v2.0**  
  *(Required only if you want to run the compiler script manually)*  
- **WinRAR** or any archive tool 
  *(Only if you want to compile the standalone scripts under `_src/standalone scripts/)`*  
- **Inno Setup 6** *(optional, included in this folder)*  

---

## Build Steps

1. Extract the repository to a local folder  
2. Navigate to this directory (`_src/lib/build_scripts/`)  
3. Run `compile_scripts.exe` or `dist.ahk`  
   - A build options dialog will appear  
   - Choose your preferred build settings (see below)  
   - The compiled files will be generated in the `_src/dist/` folder

---

## Build Options

The build script provides a GUI with the following options:

- **Compile and package vaultOps** (Always enabled)
  - Creates the main vaultOps executable and installer

- **Scan build with VirusTotal** (Yes / No, optional)
  - Optionally scans the generated setup file after building
  - Requires a VirusTotal API key (free account available at [virustotal.com](https://www.virustotal.com))
  - API key is saved locally in `build_options.ini` for future scans
  - Opens scan results in your browser automatically when complete

- **Compile standalone scripts** (Yes / No)
  - Optionally compiles individual puzzle solvers as standalone executables
  - Standalone scripts can run independently without the main app
- **Replace classes with originals** (Yes / No, conditional)
  - Only available if standalone scripts compilation is enabled
  - Creates temporary versions with original class definitions for compatibility


---

## Output

After building completes:
- **Main executable:** `_src/vaultOps.exe`
- **Installer:** `_src/dist/vaultOps-Setup.exe`
- **Standalone scripts:** `_src/dist/standalone/` (if enabled)

---

## Troubleshooting

**Build fails or executables not found:**
- Ensure AutoHotkey v2.0+ is installed and accessible
- Check that all required files in this directory exist (especially `Inno Setup 6/` and `AHK_BASE/`)
- Verify the repository structure hasn't been modified

**WinRAR not found:**
- If using standalone packaging, you'll be prompted to locate `WinRAR.exe`
- Ensure WinRAR is installed, or disable standalone SFX packaging in build options

**VirusTotal scan fails:**
- Verify your API key is correct (get one from [virustotal.com](https://www.virustotal.com))
- Ensure the setup file was created successfully before scanning
- Check if you exceeded your API usage quota
- Check that you have internet connectivity
