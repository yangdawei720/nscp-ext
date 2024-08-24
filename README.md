nscp-ext(v1.0)
=========
本项目依据NSCP（v0.5.2.41），扩展各类型脚本。
同时为方便脚本编制、调试，故将脚本执行环境从NSCP中剥离。
在本环境中调试验证后的脚本，可直接拷贝至NSCP安装目录下即可使用。
目前支持脚本格式包括:
    VBS;
    ps1;

基础库环境
---------
    scripts/lib下NagiosPlugins.vbs和wrapper.vbs为NSCP提供的基础库文件。

VBS调试开发
--------
1. 扩展脚本部署位置
自定义扩展脚本请放置在scripts目录下
2. 脚本执行
在本项目根目录下，启动命令行终端;
执行命令：cscript.exe //T:30 //NoLogo scripts\\lib\\wrapper.vbs [vbs文件名]  [参数]
举例如：cscript.exe //T:30 //NoLogo scripts\\lib\\wrapper.vbs check_open_ports.vbs  /ports:500,49664:49669,64504
