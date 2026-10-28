# ===========================================================
#  Windows Defender Event Viewer  -  Narco City Screenshare
#  Liest nur das Defender-Eventlog aus, aendert nichts.
# ===========================================================

$Host.UI.RawUI.WindowTitle = "Windows Defender Event Viewer - Narco City"
Clear-Host

# --- Admin-Check ---------------------------------------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

$banner = @"

  ____         __                _             _
 |  _ \  ___  / _| ___ _ __   __| | ___ _ __  | |    ___   __ _
 | | | |/ _ \| |_ / _ \ '_ \ / _`` |/ _ \ '__| | |   / _ \ / _`` |
 | |_| |  __/|  _|  __/ | | | (_| |  __/ |    | |__| (_) | (_| |
 |____/ \___||_|  \___|_| |_|\__,_|\___|_|    |_____\___/ \__, |
                                                          |___/
"@
Write-Host $banner -ForegroundColor Magenta
Write-Host "  Narco City Screenshare Tools  |  discord.gg/narcocity" -ForegroundColor White
Write-Host ""

if (-not $isAdmin) {
    Write-Host "  [!] Nicht als Administrator gestartet - Ergebnisse koennen unvollstaendig sein." -ForegroundColor Yellow
    Write-Host ""
}

# --- Helfer --------------------------------------------------------------
function Format-EventRow {
    param([string]$Time, [string]$Type, [string]$Message, [ConsoleColor]$Color)
    $line = "{0,-20} {1,-20} {2}" -f $Time, $Type, $Message
    Write-Host $line -ForegroundColor $Color
}

function Get-ExclusionValue {
    # "HKLM\SOFTWARE\Microsoft\Windows Defender\Exclusions\Paths\C:\Users\X = 0x0" -> "C:\Users\X"
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    if ($Value -match '\\Exclusions\\(?<kind>[^\\]+)\\(?<item>.+?)(\s*=\s*0x[0-9a-fA-F]+)?\s*$') {
        $kind = $Matches['kind']
        $item = $Matches['item'].Trim()
        if ($kind -eq 'Paths') { return $item }
        return "[$kind] $item"
    }
    return $null
}

function Get-DefenderEvents {
    param([int[]]$EventIds = @(5000, 5001, 5007, 1116))

    $logName = 'Microsoft-Windows-Windows Defender/Operational'
    $idFilter = ($EventIds | ForEach-Object { "EventID=$_" }) -join ' or '
    $xml = @"
<QueryList>
  <Query Id="0" Path="$logName">
    <Select Path="$logName">*[System[($idFilter)]]</Select>
  </Query>
</QueryList>
"@
    Get-WinEvent -FilterXml $xml -ErrorAction Stop
}

# --- Ausgabe -------------------------------------------------------------
Write-Host "Loading Windows Defender Events..." -ForegroundColor Cyan
Write-Host ""

try {
    $events = Get-DefenderEvents
    Write-Host ("{0,-20} {1,-20} {2}" -f "Timestamp", "Type", "Details") -ForegroundColor Gray
    Write-Host ("-" * 70) -ForegroundColor DarkGray

    $shown = 0
    foreach ($evt in $events) {
        $time = $evt.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss")

        switch ($evt.Id) {
            5000 { Format-EventRow $time "Activated"   "Defender aktiviert"   Green; $shown++ }
            5001 { Format-EventRow $time "Deactivated" "Defender deaktiviert" Red;   $shown++ }

            5007 {
                # EventData: 0=Product Name, 1=Product Version, 2=Old Value, 3=New Value
                $old = Get-ExclusionValue ([string]$evt.Properties[2].Value)
                $new = Get-ExclusionValue ([string]$evt.Properties[3].Value)

                if ($new -and -not $old)      { Format-EventRow $time "Exclusion Added"   $new Red; $shown++ }
                elseif ($old -and -not $new)  { Format-EventRow $time "Exclusion Removed" $old Red; $shown++ }
                elseif ($old -and $new)       { Format-EventRow $time "Exclusion Changed" "$old -> $new" Red; $shown++ }
                # andere Einstellungsaenderungen werden ignoriert
            }

            1116 {
                $path = "Unbekannt"
                if ($evt.Message -match 'file:_(?<p>[^\r\n;]+)') { $path = $Matches['p'].Trim() }
                Format-EventRow $time "Threat Detected" $path DarkRed
                $shown++
            }
        }
    }

    if ($shown -eq 0) {
        Write-Host "No Defender Events Found." -ForegroundColor DarkGray
    }
}
catch {
    if ($_.Exception.Message -match 'No events were found|Es wurden keine Ereignisse gefunden') {
        Write-Host "No Defender Events Found." -ForegroundColor DarkGray
    } else {
        Write-Host "Error loading Result: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Press any Key to Exit..." -ForegroundColor Yellow
[void]$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
