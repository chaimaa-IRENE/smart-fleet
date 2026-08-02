$adb = "$env:USERPROFILE\AppData\Local\Android\Sdk\platform-tools\adb.exe"
Write-Host "Watching adb reverse tunnels... (Ctrl+C to stop)"
while ($true) {
    $list = & $adb reverse --list 2>$null
    if ($list -notmatch 'tcp:8082') {
        Write-Host "$(Get-Date -Format HH:mm:ss) Restoring tunnel 8082"
        & $adb reverse tcp:8082 tcp:8082 2>$null
    }
    if ($list -notmatch 'tcp:5000') {
        Write-Host "$(Get-Date -Format HH:mm:ss) Restoring tunnel 5000"
        & $adb reverse tcp:5000 tcp:5000 2>$null
    }
    Start-Sleep -Seconds 3
}
