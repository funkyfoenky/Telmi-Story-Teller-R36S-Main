#Requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'
$exp = 'c:\Users\Utilisateur\Downloads\Tools\HelloWorld_R36S\Telmi-R36-Other\dts\v20-exp'

Write-Host '==> disk 2 online'
Set-Disk -Number 2 -IsOffline $false
Start-Sleep -Seconds 3

$bootVol = Get-Volume | Where-Object { $_.FileSystemLabel -eq 'BOOT' } | Select-Object -First 1
if (-not $bootVol -or -not $bootVol.DriveLetter) {
  $p1 = Get-Partition -DiskNumber 2 -PartitionNumber 1
  if (-not $p1.DriveLetter) {
    Set-Partition -DiskNumber 2 -PartitionNumber 1 -NewDriveLetter D
  }
  $bootVol = Get-Volume | Where-Object { $_.FileSystemLabel -eq 'BOOT' } | Select-Object -First 1
}
$boot = "$($bootVol.DriveLetter):\"
Write-Host "BOOT=$boot"
if (-not (Test-Path (Join-Path $boot 'Image'))) { throw "Pas de Image sur $boot" }

Copy-Item (Join-Path $exp 'out\uInitrd-telmi') (Join-Path $boot 'uInitrd-telmi') -Force
$ini = [IO.File]::ReadAllText((Join-Path $exp 'boot.ini')) -replace "`r`n","`n" -replace "`r","`n"
if (-not $ini.EndsWith("`n")) { $ini += "`n" }
[IO.File]::WriteAllBytes((Join-Path $boot 'boot.ini'), [Text.Encoding]::ASCII.GetBytes($ini))
Set-Content -Path (Join-Path $boot 'telmi-runtime.log') -Value $null -NoNewline -Encoding Ascii

$telmiVol = Get-Volume | Where-Object { $_.FileSystemLabel -eq 'TELMI' } | Select-Object -First 1
if ($telmiVol -and $telmiVol.DriveLetter) {
  Set-Content -Path "$($telmiVol.DriveLetter):\telmi-early.log" -Value $null -NoNewline -Encoding Ascii
}

Write-Host "OK uInitrd=$((Get-Item (Join-Path $boot 'uInitrd-telmi')).Length) dtb=$((Get-Item (Join-Path $boot 'rk3326-r36s-v20-linux.dtb')).Length)"
Write-Host 'Ejecte la SD, teste, rebranche. Logs: D:\telmi-runtime.log  E:\telmi-early.log  ext4 /telmi-early.log'
