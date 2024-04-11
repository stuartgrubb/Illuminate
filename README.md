# ![image](https://i.imgur.com/chXMyEu.png) Illuminate
Illuminate is a PowerShell script that queries the LCU API to reveal your team's summoner names in champ select.

It contains a small GUI that displays summoner names and includes prepopulated links for OP.GG, U.GG, and Porofessor. No need to copy and paste!

## Preview
![GitHub Image](/Preview.png)

## Where can I download Illuminate?
An executable is available for download in the [Releases](https://github.com/stuartgrubb/Illuminate/releases) section.

You can also copy and paste the code within Illuminate.ps1 and simply run in it in PowerShell.

## How can I compile it myself?
This script can be converted into an executable through the following steps.

1. Download a copy of the source code from [Releases](https://github.com/stuartgrubb/Illuminate/releases).

2. Run the command below in PowerShell to install the [ps2exe](https://www.powershellgallery.com/packages/ps2exe/) module.
```PowerShell
Install-Module -Name ps2exe
```

3. Convert the script into an executable by running the 'Invoke-ps2exe' command below.
```PowerShell
Invoke-ps2exe .\Illuminate.ps1 .\Illuminate.exe -NoConsole -iconFile .\Icon.ico
```

## Disclaimer
Illuminate is not endorsed by or affiliated in any way with Riot Games. Use at your own risk.
