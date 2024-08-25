' Check open ports
' ==============================
'
' based on example scripts fond in nsclient++/scripts directory
'
' Author: yangdawei720  2024-8-17
'
' 针对TCP或UDP指定的端口或多个端口，检测是否对外开放。若其中有任何一个端口未开放
' 则报错critical。
' =========================
'
'
' in [modules]:
' CheckExternalScripts.dll
'
' in [NRPE]:
' allow_arguments=1
' allow_nasty_meta_chars=1
' allowed_hosts=x.x.x.x
'
' in [External Script]:
' allow_arguments=1
' allow_nasty_meta_chars=1
'
' in [Script Wrappings]:
' vbs=cscript.exe //T:30 //NoLogo scripts\lib\wrapperCDbl.vbs %SCRIPT% %ARGS%
'
' in [Wrapped Scripts]:
' check_files=check_files.vbs $ARG1$ $ARG2$ $ARG3$ $ARG4$ $ARG5$ $ARG6$ $ARG7$ $ARG8$ $ARG9$ $ARG10$ $ARG11$ $ARG12$ $ARG13$ $ARG14$
'
'
' args:
' =====
'
' proto(可选): 网络协议，包括 TCP 或 UDP。若空缺，默认两个协议的端口都包含
' ports(必选): 指定探查的网络端口范围。比如33,56,20002:20007,98等
' 全局变量
Const PROGNAME = "check_open_ports"
Const VERSION = "0.1.0"

' Default settings for script.
Dim ports, proto, command, retCode, retVal
Dim objShell, objScriptExec

Set objShell = CreateObject("WScript.Shell")

' 解析参数
' Create the NagiosPlugin object
Set np = New NagiosPlugin

' Define what args that should be used
np.add_arg "ports", "22,24:32,99", 1
np.add_arg "proto", "TCP | UDP", 0
retCode = OK

' If we have no args or arglist contains /help or not all of the required arguments are fulfilled show the usage output,.
If Args.Count < 1 Or Args.Exists("help") Or np.parse_args = 0 Then
	WScript.Echo Args.Count
	np.Usage
End If

' If we define /warning /critical on commandline it should override the script default.
If Args.Exists("proto") Then proto = Args("proto")
If Args.Exists("ports") Then ports = Args("ports")

' 解析Ports
ports = ParsePorts(ports)

' 执行netstat
If IsEmpty(proto) Then
	command = "cmd /C ""netStat -an """
Else
	command = "cmd /C ""netStat -anp " & proto & """"
End If
set objScriptExec = objShell.Exec(command)
strContent = objScriptExec.StdOut.ReadAll

' 将netstat结果记录至文件中
'Windows临时目录
tmpFolderPath = objShell.ExpandEnvironmentStrings("%TEMP%")
'创建随机文件名
Randomize
Dim filePath
filePath = tmpFolderPath & "\" & "file" & Int(Rnd * 900 + 100) & ".tmp"
Set objFSO = CreateObject("Scripting.FileSystemObject")
Set objTextFile = objFSO.CreateTextFile(filePath, True)
objTextFile.WriteLine strContent
objTextFile.Close
Set objTextFile = Nothing

'解析ports状态
For Each port In ports
	' command = "cmd /C findstr /C:""0.0.0.0:" & port & " "" " & filePath & " | findstr ""LISTENING"" | find /C /V """""
	command = "cmd /C findstr /C:""0.0.0.0:" & port & " "" " & filePath & " | find /C /V """""
	set objScriptExec = objShell.Exec(command)
	strContent = objScriptExec.StdOut.ReadAll
	If CInt(strContent) = 0 Then
		If retCode = OK Then
			retVal = port
			retCode = CRITICAL
		Else
			retVal = retVal & "," & port
		End If
	End If
Next

If objFSO.FileExists(filePath) Then
    ' 删除文件
    objFSO.DeleteFile filePath, True ' True参数表示强制删除，即使文件是只读的也会被删除
End If

Set objFSO = Nothing
Set objShell = Nothing
Set objScriptExec = Nothing

If retCode = OK Then
	retVal = "All Ports OK!"
Else
	retVal = "Ports(" & retVal & ") Down!"
End If 


np.nagios_exit retVal, retCode


' Functions
Function ParsePorts(PortsStr)
	Dim PortsArray, ports, i, j
	Set PortsArray = CreateObject("Scripting.Dictionary")

	ports = Split(PortsStr, ",") ' 使用逗号作为分隔符
	For i = LBound(ports) To UBound(ports)
		Set re = New RegExp
		re.IgnoreCase = True
		re.Pattern = "^[0-9]+$"
		If re.Test(ports(i)) Then
			AddPort PortsArray, ports(i)
		End If
		
		re.Pattern = "^([0-9]+):([0-9]+)$"
		If re.Test(ports(i)) Then
			Set threshold = re.Execute(ports(i))
			For Each thres In threshold
				For j = CLng(thres.SubMatches(0)) To CLng(thres.SubMatches(1))
					AddPort PortsArray, CStr(j)
				Next
			Next
		End If
	Next
	
	ParsePorts = PortsArray.Keys
End Function

Sub AddPort(ports, port)
	If Not (ports.Exists(port)) Then
		ports.Add port, port
	End If
End Sub
