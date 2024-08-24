' Required Variables
Const PROGNAME = "check_disk_iostat"
Const VERSION = "1.0.2"

' Default settings for your script.
threshold_warning = 50
threshold_critical = 80
strComputer = "."

' Create the NagiosPlugin object
Set np = New NagiosPlugin

' Define what args that should be used
np.add_arg "computer", "Computer name", 0
np.add_arg "warning", "warning threshold", 0
np.add_arg "critical", "critical threshold", 0

' If we have no args or arglist contains /help or not all of the required arguments are fulfilled show the usage output,.
If Args.Exists("help") Then
	np.Usage
End If

' If we define /warning /critical on commandline it should override the script default.
If Args.Exists("warning") Then threshold_warning = Args("warning")
If Args.Exists("critical") Then threshold_critical = Args("critical")
If Args.Exists("computer") Then strComputer = Args("computer")
np.set_thresholds threshold_warning, threshold_critical
return_code = OK
'=====================================================
Set objWMI = GetObject("winmgmts://" & strComputer & "/root\cimv2")
Set objInstances = objWMI.InstancesOf("Win32_PerfFormattedData_PerfDisk_PhysicalDisk",48)

out="Disk windows iostat | "
For Each objInstance in objInstances 
	if InStr(objInstance.Name,"Total") =0 then
		name=replace(objInstance.Name," ","_")
		name=" "&replace(name,":","")
		out=out & Name & "_AvgDiskQueueLength=" & objInstance.AvgDiskQueueLength&";"&threshold_warning&";"& threshold_critical &Name &"_DiskReadBytesPersec=" & objInstance.DiskReadBytesPersec & Name &"_DiskWriteBytesPersec=" & objInstance.DiskWriteBytesPersec & Name &"_PercentDiskTime=" & objInstance.PercentDiskTime
		return_code = np.escalate_check_threshold(return_code, objInstance.AvgDiskQueueLength)
	end if
Next
'=====================================================
' Nice Exit with msg and exitcode

np.nagios_exit out, return_code