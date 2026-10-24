# PJ Gaming

A single-file utility tailored to your Ryzen 7 9800X3D, NVIDIA RTX 5070, 32 GB RAM desktop running Windows 11 Home (reported as 26H2), with a **2560×1440, 360 Hz monitor and Ethernet**. Your main game is Fortnite, with Dead by Daylight, Call of Duty and Uncharted also in mind. The local hardware report can verify your actual Windows build and driver versions.

It runs offline with Windows PowerShell 5.1 and does not require administrator access or install software. FPS and input-delay improvements depend on the game and its settings; the tool does not measure or guarantee either.

1. Copy [dist/PJ-Gaming.cmd](dist/PJ-Gaming.cmd) to your Windows PC and double-click it. Keep the `.cmd` extension.
2. Save your work and close games and browsers yourself.
3. Review the options and click **Apply selected settings**.
4. Read the results, then restart Windows before testing a game.

The downloaded `.cmd` is self-contained. You do not need the source files, Python or a separate PowerShell download on your PC.

| Option | Default | Effect |
| --- | --- | --- |
| Gaming | Selected | Enables Game Mode and disables Windows game recording/captures. It does not remove Xbox components or change OBS/NVIDIA/AMD recording. |
| Appearance | Selected | Turns transparency off, requests Windows/app dark mode, disables Windows Dynamic Lighting, sets the desktop to solid black instead of Spotlight, and turns lock-screen Spotlight rotation/tips off. |
| Chrome / Edge background activity | Off | Adds per-user policies disabling Chrome background apps, Edge background apps and Edge Startup Boost. Browser hardware acceleration stays as it is. |
| High performance power plan | Off | Selects the existing standard High performance plan on an AC-powered desktop without a detected battery. It does not create plans or change individual processor settings. |

The browser option can make the browsers display **Managed by your organization**, because it uses policy settings. Existing values for these specific policies are preserved, and PCs detected as managed are skipped. The change may slow browser startup or stop background notifications, and it does not reduce the load of tabs you keep open. Restart browsers after applying it. Undo removes the policy values this tool added.

The new **Appearance** option is checked by default. Your final desktop background is **Solid color → Black**; the desktop Picture option is not selected because your final request was for a solid color. Lock-screen Spotlight rotation and tips are switched off without choosing a new lock-screen image. To select a particular lock-screen Picture, use Windows Personalization settings. Restart Windows after Apply or Undo so the shell reloads the preferences. Dark mode applies to Windows and apps that follow its theme; some apps have separate theme settings. The utility's own window is also dark. Windows Dynamic Lighting and foreground-app lighting control are switched off; RGB managed by device firmware or other peripheral software needs its own controls. These appearance choices are not a guaranteed FPS improvement.

After restarting, check **Settings → Personalization → Colors, Background, Dynamic Lighting and Lock screen**. Appearance settings use Windows registry implementation details and can vary by release or be overridden by work/school policy. No wallpaper files, theme caches or existing pictures are deleted. Undo restores the saved preferences and wallpaper path; your existing `backup-v1.json` also works when upgrading from the previous gaming-only version. Keep the latest `.cmd` to undo newly added settings.

Keep Windows Balanced as the initial baseline for your 9800X3D. High performance can increase power use and heat without improving frame rates. Treat it as an optional before/after test, and keep it only if repeatable measurements improve. The tool preserves your current plan unless you select the option. Systems without the standard High performance plan are skipped.

You chose networking options for review. The utility provides a local network guide and adapter link information for that review; it does not apply network changes. DNS, TCP settings, network adapters, Defender, firewall, Windows Update and system services are untouched. The tool also leaves GPU driver settings, hardware acceleration, memory settings, HPET and timer settings alone. It does not delete applications, clear browser profiles or forcibly close processes.

To undo, reopen the same `.cmd` under the same Windows account and click **Undo my changes**, then restart Windows. Original values, their types and the original power plan are recorded before changes in:

```text
%LOCALAPPDATA%\PJ-Tweaks\backup-v1.json
```

Keep this backup while using the tweaks. Repeated applications preserve the original baseline. Undo removes only values the tool added and restores values it changed. If another program or you changed a setting afterward, Undo skips it and retains the backup rather than overwriting the newer setting. Read any **SKIPPED UNDO** or **FAILED UNDO** messages. Unchecking an option does not undo a previous application; use the Undo button.

The result panel distinguishes **APPLIED**, **UNCHANGED**, **SKIPPED** and **FAILED**. A finished pass does not mean every selection succeeded. Windows game-setting registry values are implementation details and can vary with Windows updates; after restarting, verify **Settings → Gaming → Game Mode** and **Captures**. Browser policies can be checked in `chrome://policy` and `edge://policy`.

Use **Save hardware report** to create:

```text
%LOCALAPPDATA%\PJ-Tweaks\hardware-report.txt
```

The report contains Windows build, CPU, GPU/driver, RAM, driver-reported display information, the active power plan and network adapter link information. It stays on your PC and excludes identifying serial numbers and network addresses. Verify that your monitor is actually running at 2560×1440 and 360 Hz; driver-reported display information can be incomplete. The advertised 0.03 ms panel response is not total input latency. At 360 Hz, one refresh interval is approximately 2.78 ms.

Use **Personal gaming + network guide** to save your hardware-specific recommendations locally:

```text
%LOCALAPPDATA%\PJ-Tweaks\personal-guide.txt
```

For further tuning, make one change at a time:

- Install AMD chipset and NVIDIA graphics drivers from the official manufacturers. Avoid automatic third-party driver-updater utilities.
- In Windows Display settings, verify your monitor's native resolution and highest supported refresh rate. Check each monitor directly; reported rates can be incomplete.
- In Fortnite, start with the game's **NVIDIA Reflex: On** option. Avoid forcing NVIDIA Control Panel Low Latency Mode globally; use the supported in-game control. Test On + Boost separately if needed, since it can increase GPU power use and heat.
- For a competitive starting point, keep Frame Generation off and use VSync off if tearing is acceptable. Compare uncapped FPS against an in-game 360 FPS cap, and test a lower sustainable cap such as 300 if heavy gameplay drops below 360. For a separate tear-free setup, only if the monitor supports G-SYNC/compatible VRR, use the appropriate NVIDIA VSync/VRR configuration and stay below the refresh ceiling; 357 FPS is a starting test. Reflex may already apply a lower cap in that setup, so do not stack limiters without checking. The guide explains these alternatives; the utility does not alter display or NVIDIA settings.
- Compare Fortnite Performance rendering mode and DirectX 12 at the same resolution using a repeatable scene after shader compilation has settled. The best choice for your 9800X3D/RTX 5070 depends on the workload and image quality you want. Test each mode separately and keep the one with better measured frame times.
- For Call of Duty, use its supported in-game Reflex option when available. For Dead by Daylight and Uncharted, begin with their supported settings and evaluate frame pacing before applying game-specific changes. Avoid external injection tools in multiplayer games.
- Adjust resolution, render scale and expensive graphics effects to your preferred image-quality/performance balance. A stable frame-rate cap can help consistency; the best cap depends on your monitor, game and GPU load.
- Keep browser hardware acceleration enabled unless you are diagnosing a specific problem. Close unnecessary tabs and extensions before playing.
- Compare the same built-in benchmark or repeatable scene at the same settings and temperature conditions. Run it several times before and after, recording average FPS, 1% lows and visible stutter. FPS alone does not measure end-to-end input delay.

For networking, review these practical options without changing Windows adapter defaults:

- You already use Ethernet. Check the reported link speed and investigate packet loss or disconnects if present. Keep working speed/duplex autonegotiation and adapter defaults; a higher link rate alone does not guarantee lower server ping.
- Pause active downloads and cloud-sync transfers while playing, including browser downloads and game-launcher updates. Resume them afterward; there is no need to disable services.
- If latency rises when someone uploads or downloads, check whether your router offers SQM or another documented queue-management option. It can improve latency under congestion at the cost of some maximum throughput. Follow the router's instructions and compare before/after under load; the utility does not configure your router.
- Leave DNS, TCP autotuning, RSS, checksum/offload settings and interrupt moderation unchanged unless diagnosing a specific, measured problem with vendor guidance. A generic registry preset cannot guarantee lower ping.

For development, edit `src/PJ-Gaming.ps1` and rebuild the launcher with Python's standard library:

```sh
python3 tools/build.py
pwsh -NoLogo -NoProfile -File tests/test-core.ps1
```

The build also writes `dist/SHA256SUMS.txt`. The PowerShell tests exercise backup and restore logic using simulated Windows state; they do not change real Windows settings. Native Windows GUI, registry integration and gaming benchmarks have not been verified in this Linux development environment. Test the executable on Windows before distributing it more broadly.

On Windows, run the additional native checks from the repository root:

```powershell
powershell.exe -NoProfile -STA -File tests/test-windows.ps1
```

These checks round-trip values in a randomly named temporary test key, load Windows Forms and query the current power plan without changing it. They do not apply the gaming profile or automate the complete interface. They have not been executed in the Linux workspace.
