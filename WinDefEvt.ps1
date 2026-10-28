$host.ui.RawUI.WindowTitle = "Windows Defender Event Viewer - Narco City"
Clear-Host
Write-Host ""
Write-Host -ForegroundColor Magenta @"
   ███╗   ██╗ █████╗ ██████╗  ██████╗ ██████╗      ██████╗██╗████████╗██╗   ██╗
   ████╗  ██║██╔══██╗██╔══██╗██╔════╝██╔═══██╗    ██╔════╝██║╚══██╔══╝╚██╗ ██╔╝
   ██╔██╗ ██║███████║██████╔╝██║     ██║   ██║    ██║     ██║   ██║    ╚████╔╝
   ██║╚██╗██║██╔══██║██╔══██╗██║     ██║   ██║    ██║     ██║   ██║     ╚██╔╝
   ██║ ╚████║██║  ██║██║  ██║╚██████╗╚██████╔╝    ╚██████╗██║   ██║      ██║
   ╚═╝  ╚═══╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚═════╝      ╚═════╝╚═╝   ╚═╝      ╚═╝
"@

Write-Host -ForegroundColor White "                    Made by rafaelv1004 - " -NoNewLine
Write-Host -ForegroundColor White "discord.gg/narcocity"
Write-Host ""

function Format-EventRow {
    param (
        [string]$Time,
        [string]$Type,
        [string]$Message,
        [ConsoleColor]$Color = 'White'
    )
    Write-Host ("{0,-20} {1,-20} {2}" -f $Time, $Type, $Message) -ForegroundColor $Color
}

function Get-ExclusionItem {
    param ([string]$Value)
    if ($Value -match 'Windows Defender\\Exclusions\\(Paths|Extensions|Processes|IpAddresses)\\([^=]*)') {
        $kind = $matches[1]
        $item = $matches[2].Trim()
        if ($kind -eq 'Paths') { return $item }
        return "[$kind] $item"
    }
    return $null
}

function Get-DefenderEvents {
    param (
        [int[]]$EventIds = @(5000, 5001, 5007, 1116),
        [string]$LogName = 'Microsoft-Windows-Windows Defender/Operational'
    )

    Write-Host "Loading Windows Defender Events...`n" -ForegroundColor Cyan
    Write-Host ("{0,-20} {1,-20} {2}" -f "Timestamp", "Type", "Details") -ForegroundColor Gray
    Write-Host ("-" * 70) -ForegroundColor DarkGray

    $query = @"
<QueryList>
  <Query Id="0" Path="$LogName">
    <Select Path="$LogName">*[System[EventID=$($EventIds -join ' or EventID=')]]</Select>
  </Query>
</QueryList>
"@

    try {
        $events = Get-WinEvent -FilterXml $query -ErrorAction Stop

        if (-not $events) {
            Write-Host "No Defender Events Found." -ForegroundColor DarkGray
            return
        }

        foreach ($event in $events) {
            $eventXml  = [xml]$event.ToXml()
            $timestamp = $event.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss')

            switch ($event.Id) {
                5000 {
                    Format-EventRow -Time $timestamp -Type "Activated" -Message "Defender aktiviert" -Color Green
                }
                5001 {
                    Format-EventRow -Time $timestamp -Type "Deactivated" -Message "Defender deaktiviert" -Color Red
                }
                5007 {
                    $newValue = ($eventXml.Event.EventData.Data | Where-Object { $_.Name -eq 'New Value' }).'#text'
                    $oldValue = ($eventXml.Event.EventData.Data | Where-Object { $_.Name -eq 'Old Value' }).'#text'

                    $newPath = Get-ExclusionItem $newValue
                    $oldPath = Get-ExclusionItem $oldValue

                    if ($newPath -and -not $oldPath) {
                        Format-EventRow -Time $timestamp -Type "Exclusion Added" -Message $newPath -Color Red
                    }
                    elseif ($oldPath -and -not $newPath) {
                        Format-EventRow -Time $timestamp -Type "Exclusion Removed" -Message $oldPath -Color Red
                    }
                    elseif ($oldPath -and $newPath) {
                        Format-EventRow -Time $timestamp -Type "Exclusion Changed" -Message "$oldPath -> $newPath" -Color Red
                    }
                }
                1116 {
                    $filePath = ($eventXml.Event.EventData.Data | Where-Object { $_.Name -eq 'Path' }).'#text'
                    if ($filePath -match 'file:_([^;]+)') {
                        Format-EventRow -Time $timestamp -Type "Threat Detected" -Message $matches[1].Trim() -Color DarkRed
                    }
                }
            }
        }
    }
    catch {
        if ($_.Exception.Message -match 'No events were found|Es wurden keine Ereignisse') {
            Write-Host "No Defender Events Found." -ForegroundColor DarkGray
        } else {
            Write-Host "Error loading Result: $_" -ForegroundColor Red
        }
    }
}

Get-DefenderEvents

Write-Host "`nPress any Key to Exit..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
