<#

.SYNOPSIS 
	Nagios check plugin used for host monitoring of Remote Desktop Services (RDS) 
	including uptime and CPU usage for Nagios performance charts for total CPU
.DESCRIPTION 
	No options exist and the plugin is used for monitoring Windows Servers running RDS. 
	Performance data is output by default.
	
    File Name  : checek_host.ps1 
    Author     : Chris Johnston - HireChrisJohnston@gmail.com
    Requires   : PowerShell V2
    
	Nagios Performance data example seen below and has been formatted for readbility of the performance metrics.
	No alerts occur based on performance data but instead are based on the Windows RDS service in a "Running" state.
	Usage is calulated across all cores for total CPU usage.
	
.EXAMPLE 
    C:\foo> .\check_host.ps1
	
	CRITICAL: Remote Desktop Service is not running - Up for 7 Days 21 Hours 27 Minutes
	|'%ProcessorTime'=1.69% 
	'%UserTime'=0.78% 
	'%PrivilegedTime'=0.20% 
	'%InterruptTime'=0.00% 
	'%DPCTime'=0.00%

#>
$wmi = Get-WmiObject -Class Win32_OperatingSystem
$perf_data =''
$perf_status_data = ''
$output = '' 


$uptimeObj = $wmi.ConvertToDateTime($wmi.LocalDateTime) – $wmi.ConvertToDateTime($wmi.LastBootUpTime)
$days = $uptimeObj.days
$hours = $uptimeObj.hours
$minutes = $uptimeObj.minutes

If ((get-service "Remote Desktop Services").Status -eq "Running") {
    $perf_status_data="OK: Remote Desktop Services Running - Up for $days Days $hours Hours $minutes Minutes" 
    $exit_code = '0'
    }
    Else {
    $perf_status_data = "CRITICAL: Remote Desktop Service is not running - Up for $days Days $hours Hours $minutes Minutes"
    $exit_code = '2'
    }

 $listOfCPUMetrics = @("\Processor Information(_Total)\% Processor Time",
 "\Processor Information(_Total)\% User Time",
 "\Processor Information(_Total)\% Privileged Time", 
 "\Processor Information(_Total)\% Interrupt Time",
 "\Processor Information(_Total)\% DPC Time"),
 ('some','other','array');
 
$perf_data ='|'

foreach ($cpum in $listOfCPUMetrics[0]) {
    # $obj = $cpum.CounterSamples | Select-Object -Property Path, CookedValue;
    # $counter = $cpum.Replace(" ","") 
      
    $strip_space = $cpum.Replace('\Processor Information(_Total)\','')
    $counter = $strip_space.Replace(' ','')
    $perf_data += "'$counter'="
    $perf_data_val= "{0:N2}" -f ((Get-Counter -Counter $cpum).CounterSamples | Select-Object -Property CookedValue).CookedValue
    $perf_data += $perf_data_val
    $perf_data += '% '

}

$output += $perf_status_data
$output += $perf_data

 Write-host $output
Exit $exit_code