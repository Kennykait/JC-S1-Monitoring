param (
    [string]$CsvPath,
    [string]$GroupName,
    [string]$SlackWebhookUrl,
    [string]$APIKey
)

# Authenticate to JumpCloud
Connect-JCOnline -JumpCloudAPIKey $APIKey -Force

# Get all systems with needed properties
$allSystems = Get-JCSystem -returnProperties hostname, serialNumber, os, _id
$windowsSystems = Get-JCSystemApp -Name "Sentinel Agent" -SystemOS "windows" | Select-Object -ExpandProperty SystemID
$macSystems = Get-JCSystemApp -Name "SentinelAgent" -SystemOS "macOS" | Select-Object -ExpandProperty SystemID
$sentinelOneSystems = $windowsSystems + $macSystems

$results = @()
$noSentinelOneSystems = @()
$noS1FormattedList = @()

foreach ($system in $allSystems) {
    $hasS1 = $sentinelOneSystems -contains $system._id
    if (-not $hasS1) {
        $noSentinelOneSystems += $system._id
        $noS1FormattedList += "$($system.hostname) $($system.os)"
    }

    $results += [PSCustomObject]@{
        Hostname = $system.hostname
        "Serial Number" = $system.serialNumber
        _id = $system._id
        OS = $system.os
        "SentinelOne Status" = if ($hasS1) { "SentinelOne Installed" } else { "SentinelOne not Installed" }
    }
}

$results | Export-Csv -Path $CsvPath -NoTypeInformation

foreach ($systemID in $noSentinelOneSystems) {
    Add-JCSystemGroupMember -GroupName $GroupName -SystemID "$systemID"
}

# Build Slack message
$deviceCount = $noSentinelOneSystems.Count
$deviceListText = $noS1FormattedList -join "`n"
$message = @"
SentinelOne Audit Completed. Devices count without SentinelOne - $deviceCount.
List of devices:
$deviceListText
"@

# Send message to Slack
$payload = @{ text = $message } | ConvertTo-Json -Depth 3
Invoke-RestMethod -Uri $SlackWebhookUrl -Method Post -ContentType 'application/json' -Body $payload