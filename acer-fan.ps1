<#
Acer gaming fan mode via WMI (AcerGamingFunction).  Run as Administrator.

  .\acer-fan.ps1 -Mode Normal      # kembali ke kendali otomatis BIOS
  .\acer-fan.ps1 -Mode Max         # kipas CPU + GPU 100%
  .\acer-fan.ps1 -Mode Max -WhatIf # hanya tampilkan payload, tidak menulis

Payload dari jeremyaliparo/nitrous (AcerWmiManager.cs):
  SetGamingFanBehavior : Auto=0x41000F  Max=0x82000F
  SetGamingFanSpeed    : (fanId | percent<<8), fanId = 1 (CPU), 2 (GPU), 4 (GPU)
Terverifikasi di model Nitro lain, BELUM terverifikasi di AN515-44.
Kalau ragu atau kipas terasa aneh: jalankan -Mode Normal, lalu restart laptop.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][ValidateSet('Normal', 'Max')][string]$Mode
)
$ErrorActionPreference = 'Stop'

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { Write-Host "Jalankan PowerShell sebagai Administrator." -ForegroundColor Red; return }

$inst = Get-CimInstance -Namespace root\WMI -ClassName AcerGamingFunction | Select-Object -First 1
if (-not $inst) { Write-Host "AcerGamingFunction tidak ditemukan." -ForegroundColor Red; return }
$cls = Get-CimClass -Namespace root\WMI -ClassName AcerGamingFunction

function ConvertTo-InputType {
    param([string]$Method, [uint64]$Value)
    $t = ($cls.CimClassMethods[$Method].Parameters | Where-Object Name -eq 'gmInput').CimType.ToString()
    if ($t -eq 'UInt64') { return [uint64]$Value }
    return [uint32]$Value
}

function Invoke-Acer {
    param([string]$Method, [uint64]$Value)
    $desc = "{0}(0x{1:X})" -f $Method, $Value
    if ($PSCmdlet.ShouldProcess($desc, 'Kirim ke BIOS via WMI')) {
        $arg = ConvertTo-InputType -Method $Method -Value $Value
        $r = Invoke-CimMethod -InputObject $inst -MethodName $Method -Arguments @{ gmInput = $arg }
        Write-Host ("  {0} -> gmOutput={1}" -f $desc, $r.gmOutput)
    }
}

function Read-AcerSensor {
    param([uint32]$Address, [uint64]$Mask)
    # Jangan beri nama fungsi 'Rd': itu alias bawaan untuk Remove-Item.
    $res = Invoke-CimMethod -InputObject $inst -MethodName GetGamingSysInfo -Arguments @{ gmInput = $Address }
    return [int](([uint64]$res.gmOutput -shr 8) -band $Mask)
}

function Get-Telemetry {
    [pscustomobject]@{
        CpuTemp = Read-AcerSensor -Address 0x0101 -Mask 0xFF
        CpuRpm  = Read-AcerSensor -Address 0x0201 -Mask 0xFFFF
        GpuTemp = Read-AcerSensor -Address 0x0A01 -Mask 0xFF
        GpuRpm  = Read-AcerSensor -Address 0x0601 -Mask 0xFFFF
    }
}

Write-Host "Sebelum:" ; Get-Telemetry | Format-List | Out-String | Write-Host

if ($Mode -eq 'Normal') {
    $behavior = 0x41000F; $pct = 0
} else {
    $behavior = 0x82000F; $pct = 100
}

Write-Host "Mode: $Mode"
Invoke-Acer -Method SetGamingFanBehavior -Value $behavior
foreach ($id in 1, 2, 4) { Invoke-Acer -Method SetGamingFanSpeed -Value ([uint64]$id -bor ([uint64]$pct -shl 8)) }

if ($WhatIfPreference) { Write-Host "`n(-WhatIf: tidak ada yang ditulis.)"; return }

Write-Host "`nMenunggu 8 detik agar kipas menyesuaikan..."
Start-Sleep -Seconds 8
Write-Host "Sesudah:" ; Get-Telemetry | Format-List | Out-String | Write-Host
Write-Host "Kalau RPM tidak berubah sama sekali, BIOS kemungkinan tidak memakai format ini di model Anda."
Write-Host "Kembalikan kapan saja dengan:  .\acer-fan.ps1 -Mode Normal"
