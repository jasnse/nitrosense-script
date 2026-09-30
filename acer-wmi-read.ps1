# Read-only probe of the Acer gaming WMI interface (AcerGamingFunction).
# Sensor addresses/decoding taken from jeremyaliparo/nitrous (AcerWmiManager.cs).
# Verified there on newer Nitro models; results on AN515-44 are UNVERIFIED.
# Only calls Get* methods. Writes nothing. Must run as Administrator.

$ErrorActionPreference = 'Stop'

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { Write-Host "Jalankan PowerShell sebagai Administrator." -ForegroundColor Red; return }

$inst = Get-CimInstance -Namespace root\WMI -ClassName AcerGamingFunction | Select-Object -First 1
if (-not $inst) { Write-Host "AcerGamingFunction tidak ditemukan." -ForegroundColor Red; return }
Write-Host "Instance: $($inst.InstanceName)  Active: $($inst.Active)"

function Read-Acer {
    param([string]$Method, [uint32]$Address)
    try {
        $r = Invoke-CimMethod -InputObject $inst -MethodName $Method -Arguments @{ gmInput = $Address }
        return [uint64]$r.gmOutput
    } catch {
        return $null
    }
}

function Show-Sensor {
    param([string]$Name, [uint32]$Address, [uint64]$Mask, [string]$Unit)
    $raw = Read-Acer -Method 'GetGamingSysInfo' -Address $Address
    if ($null -eq $raw) {
        Write-Host ("{0,-16} addr=0x{1:X4}  ERROR (BIOS tidak menjawab)" -f $Name, $Address) -ForegroundColor Yellow
    } else {
        $val = ($raw -shr 8) -band $Mask
        Write-Host ("{0,-16} addr=0x{1:X4}  raw=0x{2:X}  ->  {3} {4}" -f $Name, $Address, $raw, $val, $Unit)
    }
}

Write-Host "`n== Sensor (GetGamingSysInfo) =="
Show-Sensor 'CPU temp'  0x0101 0xFF   'C'
Show-Sensor 'CPU fan'   0x0201 0xFFFF 'RPM'
Show-Sensor 'GPU temp'  0x0A01 0xFF   'C'
Show-Sensor 'GPU fan'   0x0601 0xFFFF 'RPM'

Write-Host "`n== Profil yang didukung (GetGamingMiscSetting 0x0A) =="
$raw = Read-Acer -Method 'GetGamingMiscSetting' -Address 0x0A
if ($null -eq $raw) {
    Write-Host "ERROR (BIOS tidak menjawab)" -ForegroundColor Yellow
} else {
    $bitmap = [int](($raw -shr 8) -band 0xFF)
    Write-Host ("raw=0x{0:X}  bitmap=0x{1:X2}  Turbo didukung: {2}" -f $raw, $bitmap, (($bitmap -band 0x20) -ne 0))
}

Write-Host "`nSelesai. Bandingkan suhu/RPM dengan HWiNFO. Tidak ada yang ditulis ke BIOS."
