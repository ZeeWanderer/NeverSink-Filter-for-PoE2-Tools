# NeverSink Filter for PoE2 Tools

This repository contains PowerShell scripts i use to manage NeverSink Filters for Path of Exile 2. Some scripts require administrative privileges to run.

## Scripts

### Create-Links.ps1
- **Purpose:** Creates symbolic or hard links for your filter files from the NeverSink Filter repository to your PoE2 filters folder.
- **Features:**
  - Supports linking different filter sets: `default`, `darkmode`, `customsounds`, or recursively with `all` (which searches for all `.filter` and `.mp3` files).
- **Usage Example:**
  ```powershell
  .\Create-Links.ps1 "C:\Path\To\NeverSink-Filter-for-PoE2" -FilterSet default,darkmode
  ```

###  Schedule-Updates.ps1
- **Purpose:** Schedules a persistent Windows Scheduled Task to automatically run a `git pull` in your NeverSink Filter repository.
- **Features:**
  - Supports triggers at logon and/or at specified intervals.
- **Usage Example:**
  ```powershell
  .\Schedule-Updates.ps1 "C:\Path\To\NeverSink-Filter-for-PoE2" -AtLogon
  ```
### Requirements
- Cloned [Neversink Filters Repository](https://github.com/NeverSinkDev/NeverSink-Filter-for-PoE2)
- PowerShell 5.1 or higher
- Administrator privileges
- Git installed and available in your system's PATH
