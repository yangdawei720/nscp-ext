' Check MS SQL specified DB access users count
' ==============================
'
' based on example scripts fond in nsclient++/scripts directory
'
' Author: yangdawei720  2024-8-24
'
' 针对MS SQL指定的数据库，查看当前用户访问的数量
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
' databases(必选): 网络协议，包括 TCP 或 UDP。若空缺，默认两个协议的端口都包含

' 全局变量
Const PROGNAME = "check_mssql_user_connecting_db_count"
Const VERSION = "0.1.1"

' Default settings for script.
Dim databases, serverName, username, password
Dim objConn, execStr, objRs, retVal

' 解析参数
' Create the NagiosPlugin object
Set np = New NagiosPlugin

' Define what args that should be used
np.add_arg "serverName", "SQL Server hostname or IP", 1
np.add_arg "username", "SQL Server login name", 1
np.add_arg "password", "SQL Server login password", 1
np.add_arg "databases", "db1,db2[,...]", 0

retCode = OK
' If we have no args or arglist contains /help or not all of the required arguments are fulfilled show the usage output,.
If Args.Count < 3 Or Args.Exists("help") Or np.parse_args = 0 Then
	WScript.Echo Args.Count
	np.Usage
End If

' If we define /warning /critical on commandline it should override the script default.
If Args.Exists("databases") Then databases = Args("databases")
If Args.Exists("serverName") Then serverName = Args("serverName")
If Args.Exists("username") Then username = Args("username")
If Args.Exists("password") Then password = Args("password")

' 创建ADODB连接对象
Set objConn = CreateObject("ADODB.Connection")
' 构建连接字符串
execStr = "Provider=SQLOLEDB;Data Source=" & serverName & ";Initial Catalog=master;User ID=" & username & ";Password=" & password & ";"
' 启用错误处理
On Error Resume Next
' 打开连接
objConn.Open execStr
' 检查连接是否成功
If Err.Number <> 0 Then
	retVal = Err.Description
	
	objConn.Close
	Set objConn = Nothing
	
	On Error GoTo 0
	np.nagios_exit retVal, CRITICAL
End If

' 如果不给出指定的数据库名称，则默认对所有数据库的用户访问情况进行统计
If IsEmpty(databases) Then
    ' 定义SQL查询语句，获取所有数据库名称
    execStr = "SELECT name FROM sys.databases ORDER BY name"
    ' 执行SQL查询
    Set objRs = objConn.Execute(execStr)
    ' 检查SQL执行是否成功
    If Err.Number <> 0 Then
		retVal = Err.Description
			
		objConn.Close
		Set objConn = Nothing
		objRs.Close
		Set objRs = Nothing
			
		On Error GoTo 0
		np.nagios_exit retVal, CRITICAL
    Else
        ' 遍历结果集并输出每个数据库名称
        databases = objRs.Fields("name").Value
        objRs.MoveNext
        Do Until objRs.EOF
            databases = databases & "," & objRs.Fields("name").Value
            objRs.MoveNext
        Loop
		
		objRs.Close
		Set objRs = Nothing
    End If
End If

databases = Split(databases, ",") ' 使用逗号作为分隔符
Dim database, perfdata, ucdbc
ucdbc = 0
For i = 0 To UBound(databases)
	database = databases(i)
	execStr = "SELECT COUNT(*) AS UserCount FROM sys.sysprocesses WHERE dbid = DB_ID('" & database & "') AND spid > 50"
    Set objRs = objConn.Execute(execStr)
    
	If objRs.Fields("UserCount").Value > 0 Then
		ucdbc = ucdbc + 1
	End If
	
    If IsEmpty(perfdata) Then
        perfdata = " '" & database & "'=" & objRs.Fields("UserCount").Value
    Else
        perfdata = perfdata & " '" & database & "'=" & objRs.Fields("UserCount").Value
    End If
		
    objRs.Close
	Set objRs = Nothing
Next

' 清理资源
objRs.Close
Set objRs = Nothing
objConn.Close
Set objConn = Nothing

On Error GoTo 0
np.nagios_exit "User Connecting DB Count(" & ucdbc & ") | " & "'ucdbc'=" & ucdbc & perfdata, OK
