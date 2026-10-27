# fanmon.ps1 — улучшенная версия
$ErrorActionPreference = "Continue"
$logPath = "C:\ProgramData\SystemData\FanLog\fan.log"
$dllPath = "C:\ProgramData\SystemData\LHM\LibreHardwareMonitorLib.dll"
$timestamp = Get-Date -Format "yyyy-MM-dd-HH-mm"

try {
    if (-not (Test-Path $dllPath)) {
        "$timestamp Fan_ERROR: DLL not found at $dllPath" | Out-File $logPath -Append -Encoding utf8
        exit 1
    }

    Unblock-File -LiteralPath $dllPath -ErrorAction SilentlyContinue
    Add-Type -LiteralPath $dllPath

    $computer = New-Object LibreHardwareMonitor.Hardware.Computer
    $computer.IsMotherboardEnabled = $true
    $computer.IsControllerEnabled  = $true
    $computer.IsCpuEnabled         = $true
    $computer.IsGpuEnabled         = $true
    $computer.Open()

    # Правильный обход всех датчиков
    $visitor = [LibreHardwareMonitor.Hardware.IVisitor]@{
        VisitComputer = { param($c) $c.Traverse($visitor) }
        VisitHardware = {
            param($h)
            $h.Update()
            foreach ($sh in $h.SubHardware) { $sh.Accept($visitor) }
        }
        VisitSensor   = { param($s) }
        VisitParameter = { param($p) }
    }
    $computer.Accept($visitor)

    $fanIndex = 1
    $found = $false

    function Process-Sensors($hardware) {
        foreach ($sensor in $hardware.Sensors) {
            if ($sensor.SensorType -eq 'Fan') {
                $rpm = if ($null -ne $sensor.Value) { [int]$sensor.Value } else { 0 }
                $state = if ($rpm -gt 0) { "$rpm RPM" } else { "OFF" }
                $name = $sensor.Name
                "$timestamp Fan_$script:fanIndex`_state: $state ($name)" | Out-File $logPath -Append -Encoding utf8
                $script:fanIndex++
                $script:found = $true
            }
        }
        foreach ($sub in $hardware.SubHardware) {
            Process-Sensors $sub
        }
    }

    foreach ($hw in $computer.Hardware) {
        Process-Sensors $hw
    }

    if (-not $found) {
        "$timestamp Fan_1_state: NO_FAN_SENSORS" | Out-File $logPath -Append -Encoding utf8
    }

    $computer.Close()
}
catch {
    "$timestamp Fan_ERROR: $($_.Exception.Message)" | Out-File $logPath -Append -Encoding utf8
}