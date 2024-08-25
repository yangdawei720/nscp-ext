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
Const PROGNAME = "check_mssql_db_access_users"
Const VERSION = "0.1.0"

' Default settings for script.
Dim databases, serverName, username, password
Dim retCode, retVal
Dim objConn, execStr, objRs

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
If Args.Count < 4 Or Args.Exists("help") Or np.parse_args = 0 Then
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
' 打开连接
objConn.Open execStr
' 检查连接是否成功
If Err.Number <> 0 Then
    retVal = "Connection failed: " & Err.Description
    retCode = UNKNOWN
    GoTo RETRIEVE_AND_EXIT
End If

' 如果不给出指定的数据库名称，则默认对所有数据库的用户访问情况进行统计
If IsEmpty(databases) Then
    ' 定义SQL查询语句，获取所有数据库名称
    execStr = "SELECT name FROM sys.databases ORDER BY name"
    ' 执行SQL查询
    Set objRs = conn.Execute(execStr)
    ' 检查SQL执行是否成功
    If Err.Number <> 0 Then
        retCode = UNKNOWN
        retVal = "Execution failed(code: " & Err.Number & "): " & Err.Description
    Else
        ' 遍历结果集并输出每个数据库名称
        databases = objRs.Fields("name").Value
        objRs.MoveNext
        Do Until objRs.EOF
            databases = databases & "," & objRs.Fields("name").Value
            objRs.MoveNext
        Loop
    End If

    objRs.Close
    Set objRs = Nothing

    If retCode = UNKNOWN Then
        GoTo RETRIEVE_AND_EXIT
    End If
End If

databases = Split(databases, ",") ' 使用逗号作为分隔符
Dim database, perfdata, errMsg
For database = LBound(databases) To UBound(databases)
	execStr = "SELECT COUNT(*) AS UserCount FROM sys.sysprocesses WHERE dbid = DB_ID('" & database & "') AND spid > 50"
    Set objRs = conn.Execute(execStr)
    
    If Err.Number <> 0 Then
        retCode = CRITICAL
        If IsEmpty(errMsg) Then
            errMsg = database 
        Else
            errMsg = errMsg & "," & database
        End If
    Else
        If IsEmpty(perfdata) Then
            perfdata = "'" & database & "'=" & objRs.Fields("UserCount").Value
        Else
            perfdata = perfdata & "'" & database & "'=" & objRs.Fields("UserCount").Value
        End If
    End If

    objRs.Close
    Set objRs = Nothing
Next

If retCode = OK Then
    retVal = "All is fine!"
Else
    retVal = "Failed DB: " & errMsg
End If

' 清理资源
RETRIEVE_AND_EXIT:
objConn.Close
Set objConn = Nothing

np.nagios_exit retVal, retCode
