<#
Acer 4-zone keyboard static color via WMI (AcerGamingFunction).  Run as Administrator.

  .\acer-keyboard.ps1 -Color FF0000                 # semua zona merah
  .\acer-keyboard.ps1 -Color 00FF00 -Zone 2         # hanya zona 2 hijau (zona 1-4, kiri ke kanan)
  .\acer-keyboard.ps1 -Color FFFFFF -Brightness 60  # putih, kecerahan 60%
  .\acer-keyboard.ps1 -Color 0000FF -WhatIf         # hanya tampilkan payload, tidak menulis

Format dari JafarAkhondali/acer-predator-turbo-and-rgb-keyboard-linux-module (facer_rgb.py, facer.c):
  Warna statis  : 4 byte [bit zona, R, G, B] -> metode WMI id 6  (SetGamingRgbKb)
  Mode statis   : buffer 16 byte, [2]=kecerahan, [9]=1           -> metode WMI id 20 (SetGamingKBBacklight)
Modul itu terverifikasi untuk AN515-45 dan seri lain; AN515-44 BELUM terverifikasi.
Efek terburuk yang diharapkan: warna/kecerahan tidak sesuai. Pulihkan dengan menjalankan ulang
skrip ini dengan warna yang diinginkan, atau lewat NitroSense kalau sudah bisa dibuka.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][ValidatePattern('^#?[0-9A-Fa-f]{6}$')][string]$Color,
    [ValidateRange(0, 4)][int]$Zone = 0,
    [ValidateRange(0, 100)][int]$Brightness = 100
)
$ErrorActionPreference = 'Stop'

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { Write-Host "Jalankan PowerShell sebagai Administrator." -ForegroundColor Red; return }

$inst = Get-CimInstance -Namespace root\WMI -ClassName AcerGamingFunction | Select-Object -First 1
if (-not $inst) { Write-Host "AcerGamingFunction tidak ditemukan." -ForegroundColor Red; return }

$hex = $Color.TrimStart('#')
$red = [Convert]::ToByte($hex.Substring(0, 2), 16)
$green = [Convert]::ToByte($hex.Substring(2, 2), 16)
$blue = [Convert]::ToByte($hex.Substring(4, 2), 16)
$zones = if ($Zone -eq 0) { 1, 2, 3, 4 } else { @($Zone) }

Write-Host ("Warna: R={0} G={1} B={2}  Zona: {3}  Kecerahan: {4}%" -f $red, $green, $blue, ($zones -join ','), $Brightness)

# 1) Warna statis per zona: 4 byte little-endian [zoneBit, R, G, B] sebagai UInt32
# Catatan: nama variabel di PowerShell tidak peka huruf besar/kecil, jadi hasil WMI memakai $result.
foreach ($z in $zones) {
    $zoneBit = [uint32](1 -shl ($z - 1))
    $value = [uint32]($zoneBit -bor ([uint32]$red -shl 8) -bor ([uint32]$green -shl 16) -bor ([uint32]$blue -shl 24))
    $desc = "SetGamingRgbKb zona $z -> bytes [{0:X2} {1:X2} {2:X2} {3:X2}]" -f $zoneBit, $red, $green, $blue
    if ($PSCmdlet.ShouldProcess($desc, 'Kirim ke BIOS via WMI')) {
        $result = Invoke-CimMethod -InputObject $inst -MethodName SetGamingRgbKb -Arguments @{ gmInput = $value }
        Write-Host ("  zona {0}: gmOutput={1}" -f $z, $result.gmOutput)
    }
}

# 2) Aktifkan mode statis + kecerahan: buffer 16 byte, [2]=brightness, [9]=1
[byte[]]$payload = New-Object byte[] 16
$payload[2] = [byte]$Brightness
$payload[9] = 1
$desc = "SetGamingKBBacklight -> " + (($payload | ForEach-Object { '{0:X2}' -f $_ }) -join ' ')
if ($PSCmdlet.ShouldProcess($desc, 'Kirim ke BIOS via WMI')) {
    $result = Invoke-CimMethod -InputObject $inst -MethodName SetGamingKBBacklight -Arguments @{ gmInput = $payload }
    Write-Host ("  backlight: gmOutput={0}" -f $result.gmOutput)
}

if ($WhatIfPreference) { Write-Host "`n(-WhatIf: tidak ada yang ditulis.)" } else { Write-Host "`nSelesai. Lihat keyboard Anda sekarang." }
