# Telmi-os 0.2.5 — selection DTB ArkOS4Clone sans casser le boot.
# Double-clic Select-DTB.bat depuis la partition BOOT.
# Copie les .dtb, alias U-Boot Odroid, boot.ini SANS uInitrd (LF).
$ErrorActionPreference = 'Stop'

$TelmiBootargs = 'root=/dev/mmcblk0p2 rootwait rw fsck.mode=skip net.ifnames=0 fbcon=map:9 vt.global_cursor_default=0 console=/dev/ttyFIQ0 quiet loglevel=3 nosplash plymouth.enable=0 consoleblank=0 systemd.show_status=false max_cpufreq=1296 boot_cpufreq=1248 max_gpufreq=520 max_ddrfreq=666'

function Find-BootRoot {
	$here = $PSScriptRoot
	if (Test-Path (Join-Path $here 'consoles')) { return $here }
	foreach ($d in Get-PSDrive -PSProvider FileSystem) {
		$c = Join-Path $d.Root 'consoles'
		$b = Join-Path $d.Root 'boot.ini'
		if ((Test-Path $c) -and (Test-Path $b)) { return $d.Root.TrimEnd('\') }
	}
	throw "Partition BOOT introuvable (pas de consoles\ + boot.ini)."
}

$boot = Find-BootRoot
$consoles = Join-Path $boot 'consoles'
$bootIni = Join-Path $boot 'boot.ini'
$packs = @(Get-ChildItem -LiteralPath $consoles -Directory | Where-Object {
	$_.Name -notmatch '^(logo|System Volume Information)$'
} | Sort-Object Name)
if ($packs.Count -eq 0) { throw "Aucun pack dans $consoles" }

$choice = $packs | Select-Object @{N='Modele';E={$_.Name}} | Out-GridView -Title 'Telmi-os 0.2.5 — choisir le DTB' -PassThru
if (-not $choice) { Write-Host 'Annule.'; exit 0 }
$pack = Join-Path $consoles $choice.Modele

$packIni = Join-Path $pack 'boot.ini'
$dtbName = $null
if (Test-Path $packIni) {
	$m = Select-String -LiteralPath $packIni -Pattern 'load mmc 1:1 \$\{dtb_loadaddr\} (\S+\.dtb)' | Select-Object -First 1
	if ($m) { $dtbName = $m.Matches[0].Groups[1].Value }
}
if (-not $dtbName) {
	$dtbFile = Get-ChildItem -LiteralPath $pack -Filter '*.dtb' | Where-Object { $_.Name -notmatch 'uboot' } | Select-Object -First 1
	if ($dtbFile) { $dtbName = $dtbFile.Name }
}
if (-not $dtbName) { throw "Pas de DTB dans $pack" }

$copied = @()
Get-ChildItem -LiteralPath $pack -Filter '*.dtb' | ForEach-Object {
	Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $boot $_.Name) -Force
	$copied += $_.Name
}

$srcDtb = Join-Path $pack $dtbName
if (-not (Test-Path $srcDtb)) {
	$srcDtb = Join-Path $boot $dtbName
}
if (Test-Path $srcDtb) {
	foreach ($alias in @(
		'rk3326-odroidgo3-linux.dtb',
		'rk3326-odroidgo2-linux.dtb',
		'rk3326-odroidgo2-linux-v11.dtb',
		'rk-kernel.dtb'
	)) {
		Copy-Item -LiteralPath $srcDtb -Destination (Join-Path $boot $alias) -Force
	}
}

$tplPath = Join-Path $PSScriptRoot 'boot.ini.template'
if (Test-Path $tplPath) {
	$template = [IO.File]::ReadAllText($tplPath)
} else {
	$template = @'
odroidgoa-uboot-config

########################################################################
# Telmi-os 0.2.5 -- LF only (no CR). Pas d'uInitrd.
########################################################################

# Boot Arguments
setenv bootargs "@@BOOTARGS@@"

# Booting
setenv loadaddr "0x02000000"
setenv dtb_loadaddr "0x01f00000"

load mmc 1:1 ${loadaddr} Image
load mmc 1:1 ${dtb_loadaddr} @@DTB@@

booti ${loadaddr} - ${dtb_loadaddr}
'@
}

$ascii = New-Object System.Text.ASCIIEncoding
$ini = $template.Replace('@@BOOTARGS@@', $TelmiBootargs).Replace('@@DTB@@', $dtbName)
$ini = $ini -replace "`r`n", "`n" -replace "`r", "`n"
$bytes = $ascii.GetBytes($ini.TrimEnd() + "`n")
[IO.File]::WriteAllBytes($bootIni, $bytes)

$consoleSrc = Join-Path $pack '.console'
if (Test-Path $consoleSrc) {
	Copy-Item -LiteralPath $consoleSrc -Destination (Join-Path $boot '.console') -Force
}

$log = @"
date=$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')
pack=$($choice.Modele)
dtb=$dtbName
copied=$($copied -join ',')
bootargs=telmi-os 0.2.5 (no uInitrd)
"@
[IO.File]::WriteAllBytes((Join-Path $boot 'TELMI-DTB-SELECT.txt'), $ascii.GetBytes($log))

Write-Host "OK  $($choice.Modele)"
Write-Host "    DTB $dtbName"
Write-Host "    boot.ini Telmi-os 0.2.5 (pas d'uInitrd)"
Write-Host "Ejecte la SD, mets-la dans la console."
