<#
Acer 4-zone keyboard dynamic effects via WMI (AcerGamingFunction).  Run as Administrator.

  .\acer-keyboard-effect.ps1 -Effect Wave
  .\acer-keyboard-effect.ps1 -Effect Wave -Speed 5 -Direction RightToLeft
  .\acer-keyboard-effect.ps1 -Effect Breath -Color FF00FF -Speed 4
  .\acer-keyboard-effect.ps1 -Effect Neon -Speed 3
  .\acer-keyboard-effect.ps1 -Effect Wave -WhatIf      # hanya tampilkan payload, tidak menulis

Efek yang memakai warna: Breath, Shifting, Zoom.  Efek tanpa warna: Neon, Wave.
Untuk kembali ke warna statis, jalankan acer-keyboard.ps1.

Format dari JafarAkhondali/acer-predator-turbo-and-rgb-keyboard-linux-module (facer_rgb.py):
  buffer 16 byte -> metode WMI id 20 (SetGamingKBBacklight)
  [0]=mode (1 Breath, 2 Neon, 3 Wave, 4 Shifting, 5 Zoom)  [1]=speed (1-9)  [2]=brightness (0-100)
  [3]=8 hanya untuk Wave, selain itu 0   [4]=direction (1 RtL, 2 LtR)   [5..7]=R,G,B   [9]=1
Terverifikasi di AN515-45 dan seri lain; AN515-44 BELUM terverifikasi.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][ValidateSet('Breath', 'Neon', 'Wave', 'Shifting', 'Zoom')][string]$Effect,
    [ValidatePattern('^#?[0-9A-Fa-f]{6}$')][string]$Color = '00FF00',
    [ValidateRange(1, 9)][int]$Speed = 4,
    [ValidateRange(0, 100)][int]$Brightness = 100,
    [ValidateSet('RightToLeft', 'LeftToRight')][string]$Direction = 'RightToLeft'
)
$ErrorActionPreference = 'Stop'

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { Write-Host "Jalankan PowerShell sebagai Administrator." -ForegroundColor Red; return }

$inst = Get-CimInstance -Namespace root\WMI -ClassName AcerGamingFunction | Select-Object -First 1
if (-not $inst) { Write-Host "AcerGamingFunction tidak ditemukan." -ForegroundColor Red; return }

$modeMap = @{ Breath = 1; Neon = 2; Wave = 3; Shifting = 4; Zoom = 5 }
$mode = $modeMap[$Effect]
$dirValue = if ($Direction -eq 'RightToLeft') { 1 } else { 2 }

$hex = $Color.TrimStart('#')
$red = [Convert]::ToByte($hex.Substring(0, 2), 16)
$green = [Convert]::ToByte($hex.Substring(2, 2), 16)
$blue = [Convert]::ToByte($hex.Substring(4, 2), 16)

[byte[]]$payload = New-Object byte[] 16
$payload[0] = [byte]$mode
$payload[1] = [byte]$Speed
$payload[2] = [byte]$Brightness
$payload[3] = if ($mode -eq 3) { 8 } else { 0 }
$payload[4] = [byte]$dirValue
$payload[5] = $red
$payload[6] = $green
$payload[7] = $blue
$payload[9] = 1

$usesColor = $mode -in 1, 4, 5
Write-Host ("Efek: {0}  Kecepatan: {1}  Kecerahan: {2}%  Arah: {3}  Warna: {4}" -f $Effect, $Speed, $Brightness, $Direction, $(if ($usesColor) { "#$hex" } else { '(tidak dipakai)' }))

$desc = "SetGamingKBBacklight -> " + (($payload | ForEach-Object { '{0:X2}' -f $_ }) -join ' ')
if ($PSCmdlet.ShouldProcess($desc, 'Kirim ke BIOS via WMI')) {
    $result = Invoke-CimMethod -InputObject $inst -MethodName SetGamingKBBacklight -Arguments @{ gmInput = $payload }
    Write-Host ("  gmOutput={0}" -f $result.gmOutput)
    Write-Host "`nSelesai. Lihat keyboard Anda. Kembali ke warna statis: jalankan acer-keyboard.ps1."
} else {
    Write-Host "`n(-WhatIf: tidak ada yang ditulis.)"
}
