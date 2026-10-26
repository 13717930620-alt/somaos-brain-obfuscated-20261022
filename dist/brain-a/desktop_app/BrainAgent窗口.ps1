# BrainAgent 桌面窗口 — PowerShell + Edge WebView2 (无需安装，Win10/11 自带)
Add-Type -AssemblyName System.Windows.Forms

# 窗口设置
$form = New-Object System.Windows.Forms.Form
$form.Text = "BrainAgent · 19脑区类脑认知智能体"
$form.Size = New-Object System.Drawing.Size(1200, 820)
$form.MinimumSize = New-Object System.Drawing.Size(800, 600)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::FromArgb(6, 10, 22)
$form.Icon = $null

# 尝试用 Edge WebView2 加载
$webViewLoaded = $false
try {
    Add-Type -Path "$env:ProgramFiles\Microsoft\EdgeWebView\Microsoft.Web.WebView2.Core.dll" -ErrorAction SilentlyContinue
    Add-Type -Path "$env:LocalAppData\Microsoft\EdgeWebView\Microsoft.Web.WebView2.Core.dll" -ErrorAction SilentlyContinue

    # 如果 WebView2 可用，使用它；否则回退到 IE WebBrowser 控件
    $web = New-Object System.Windows.Forms.WebBrowser
    $web.IsWebBrowserContextMenuEnabled = $false
    $web.ScriptErrorsSuppressed = $true
    $web.ScrollBarsEnabled = $true
    $web.Dock = [System.Windows.Forms.DockStyle]::Fill
    $webViewLoaded = $true
} catch {
    # IE WebBrowser 作为回退
    $web = New-Object System.Windows.Forms.WebBrowser
    $web.ScriptErrorsSuppressed = $true
    $web.Dock = [System.Windows.Forms.DockStyle]::Fill
}

# 等待服务器启动后加载页面
$web.Navigate("about:blank")
$form.Controls.Add($web)

# 异步等待服务器
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 1000
$retry = 0
$timer.Add_Tick({
    $script:retry++
    try {
        $req = [System.Net.WebRequest]::Create("http://localhost:3003/")
        $req.Timeout = 2000
        $resp = $req.GetResponse()
        if ($resp.StatusCode -eq 200) {
            $web.Navigate("http://localhost:3003")
            $timer.Stop()
            $timer.Dispose()
        }
        $resp.Close()
    } catch {
        if ($script:retry -gt 30) {
            $web.DocumentText = "<html><body style='background:#060a16;color:#c8d0e0;font-family:sans-serif;display:flex;align-items:center;justify-content:center;height:100vh;margin:0'><div style='text-align:center'><h2>BrainAgent 服务器未启动</h2><p>请先运行 一键启动.bat 启动服务</p></div></body></html>"
            $timer.Stop()
            $timer.Dispose()
        }
    }
})
$timer.Start()

# 窗口关闭时退出
$form.Add_FormClosed({
    $timer.Stop()
    $timer.Dispose()
    $form.Dispose()
    [System.Windows.Forms.Application]::Exit()
})

[System.Windows.Forms.Application]::Run($form)
