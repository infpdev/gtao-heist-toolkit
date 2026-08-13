# Updating Standalone Scripts

## Option 1: Automatic Updater (Recommended)

> [!NOTE]
>  This method is only available for the standalone pack. Please use the manual update method for NoSave standalone.

1. Open the `VaultOps-Standalone-Pack` folder
2. Open the `lib` folder
3. Run `standaloneUpdater.exe`
4. If the update succeeds, the standalone script will launch automatically

If the updater fails for any reason, follow the steps below to update manually.

## Option 2: Manual Update

1. Download the latest standalone package:

   * [vaultOps-Standalone-Pack.exe](https://github.com/infpdev/gtao-heist-toolkit/releases/latest/download/vaultOps-Standalone-Pack.exe) (includes all standalone solvers)
   * [NoSave-Standalone.exe](https://github.com/infpdev/gtao-heist-toolkit/releases/latest/download/NoSave-Standalone.exe) (not an SFX package; simply download and run)

2. Run the downloaded executable

3. The standalone package will automatically extract into a `vaultOps-Standalone-Pack` folder in the current directory

Done!

> [!NOTE]
> Standalone scripts now automatically preserve your settings and hotkeys through a cached settings file at `%appdata%\vaultOps`
>
> This means you no longer need to extract updates into the same folder to keep your configuration.

## Changelog

<details>
<summary><b>vaultOps v4.169.67 changes</b></summary>

Please read the [v4.169.67 release notes](https://github.com/infpdev/gtao-heist-toolkit/releases/tag/v4.169.67) for detailed information about:

* Added support for **16:10** screens
* Fixed **DPI scaling** issues
* Fixed a bug in the **El Rubio** solver

</details>

<details>
<summary><b>vaultOps v4.169.1 changes</b></summary>

Please read the [v4.169.1 release notes](https://github.com/infpdev/gtao-heist-toolkit/releases/tag/v4.169.1) for detailed information about:

* Fixed a NoSave error on unsupported resolutions
* Added a warning when anti-cheat or antivirus software interferes with NoSave
* Added a new **Misc Settings** tab for additional customization options
* Added an optional always-on-top **NoSave tooltip**
* Improved startup speed when **Discord RPC** is disabled

</details>

<details>
<summary><b>vaultOps v4.69.99 changes</b></summary>

Please read the [v4.69.99 release notes](https://github.com/infpdev/gtao-heist-toolkit/releases/tag/v4.69.99) for detailed information about:

* Removed **Alt + F4** interception while **NoSave** is active
* Fixed an issue where the **El Rubio** solver failed to time out after completing a hack
* Ledge-grab sprint fix
* Fixed a GUI issue that could occur on high or unsupported resolutions
* Discord Rich Presence now uses the official GTA activity instead of VaultOps

</details>

<details>
<summary><b>vaultOps v4.69.69 changes</b></summary>

Please read the [v4.69.69 release notes](https://github.com/infpdev/gtao-heist-toolkit/releases/tag/v4.69.69) for detailed information about:

* New **Discord Rich Presence** support with dynamic activity updates
* Removed **Buffered Ledge Grab** from the standalone scripts
* Removed **PgUp forwarding** from both **vaultOps** and the standalone **El Rubio** script, as Rockstar fixed the issue
* Improved startup and shutdown performance

</details>

<details>
<summary><b>vaultOps v4.69.67 changes</b></summary>

Please read the [v4.69.67 release notes](https://github.com/infpdev/gtao-heist-toolkit/releases/tag/v4.69.67) for detailed information about:

* Compatibility with the **Kortz Center** heist
* Updated standalone **Fingerprint** and **Keypad** solvers for Kortz compatibility
* Improved **Keypad** solver reliability
* Updated **NoSave** workflow and in-app tutorial link for Rockstar's latest patch
* New **GUI controls**, including drag, quick exit, and force-close GTA buttons
* Protection against accidentally pressing **Alt + F4** while NoSave is active

</details>

<details>
<summary><b>vaultOps v4.20.69 changes</b></summary>

Please read the [v4.20.69 release notes](https://github.com/infpdev/gtao-heist-toolkit/releases/tag/v4.20.69) for detailed information about:

* Buffered Ledge Grab automation for the Diamond Casino heist
* Configurable tooltip position and vertical offset
* Startup file validation and automatic Windows Security exclusion prompt

</details>

<details>
<summary><b>vaultOps v4.2.0 changes</b></summary>

Please read the [v4.2.0 release notes](https://github.com/infpdev/gtao-heist-toolkit/releases/tag/v4.2.0) for detailed information about:

* Improved puzzle detection reliability and reduced false detections
* Standalone packaging and shared OpenCV engine changes
* Automatic updates for standalone solvers
* New Cayo Perico and Diamond Casino tutorial videos

</details>

<details>
<summary><b>vaultOps v4.1.1 changes</b></summary>

Please read the [v4.1.1 release notes](https://github.com/infpdev/gtao-heist-toolkit/releases/tag/v4.1.1) for additional information about:

* improved NoSave reliability checks
* persistent settings support
* installation behavior changes
* standalone packaging changes

</details>