# Windows 桌面停留超时自动关机

双击 `配置桌面超时关机.cmd`，在弹出的 UAC 提示中选择“是”，即可完成配置。配置完成后，当前用户每次登录 Windows 时都会启动一个后台监控任务：**Windows 桌面连续位于前台 60 分钟**后，电脑会进入 60 秒关机倒计时。

## 行为说明

- 只有真正的 Windows 桌面处于前台时才计时；打开任意应用、文件资源管理器窗口或切换到其他窗口，都会重置计时。
- 达到 60 分钟后使用 `shutdown.exe /s /t 60` 关机，因此会保留 60 秒取消时间。
- 若要取消已经开始的倒计时，请按 `Win + R`，输入 `shutdown /a` 后按回车。
- 监控任务允许在电池供电时运行，适用于笔记本电脑。

## 自定义或卸载

请以管理员身份打开 PowerShell，切换到本目录后执行：

```powershell
# 安装并将时长改为 90 分钟
.\configure-desktop-idle-shutdown.ps1 -TimeoutMinutes 90

# 卸载任务和已安装的监控脚本
.\configure-desktop-idle-shutdown.ps1 -Mode Uninstall
```

安装文件会复制到 `%ProgramData%\DesktopIdleShutdown`，计划任务名称为 `DesktopIdleShutdown`。也可以在“任务计划程序”中禁用或删除该任务。
