# 强制以管理员权限以运行
$currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
$testadmin = $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
if ($testadmin -eq $false) {
    Start-Process powershell.exe -Verb RunAs -ArgumentList ('-noprofile -noexit -file "{0}" -elevated' -f ($myinvocation.MyCommand.Definition))
    exit $LASTEXITCODE
}

$script:LICENCE = @"
**********************************************
* Author:  Mogeko                            *
* Github:  https://github.com/Mogeko/KMS     *
* LICENCE: GNU General Public License v3.0   *
**********************************************
"@
$script:KMS_SERVER = 'kms.mogeko.me'
$script:DATA_JSON_URL = 'https://mogeko.github.io/kms/data.json'
# $script:DATA_JSON_URL = 'http://localhost:8000/data.json' # TEST

if (Test-Path .\data.json) {
    $script:MENU_INFO = Get-Content .\data.json | ConvertFrom-Json
} else {
    for ($i = 0; $i -lt 5; $i++) {
        try {
            Write-Host "正在加载 data.json..." -f green
            $tmp = New-TemporaryFile
            Invoke-WebRequest $script:DATA_JSON_URL -OutFile $tmp
            $script:MENU_INFO = Get-Content $tmp | ConvertFrom-Json
        } catch {
            Write-Host "加载 data.json 失败！重试"($i+1) -f red
        } finally {
            Remove-Item $tmp
        }
        if ($script:MENU_INFO) {
            break
        } elseif ($i -eq 4) {
            Write-Host "$nl"
            Write-Host "无法加载 data.json，程序即将退出" -f red
            Start-Sleep -s 5
            exit 1
        }
    }
}


function Main {
    param (
        $main
    )
    $flag = $true;
    while ($flag) {
        # Drew Menu
        Invoke-Expression 'cls';
        Write-Host $script:LICENCE;
        Write-Host "$nl";
        Write-Host $main.description;
        Write-Host "$nl";
        for ($i = 0; $i -lt $main.option.Count; $i++) {
            "    {0}) {1}" -f ($i+1), $main.option[$i].Name;
        }
        Write-Host "    $nl";
        Write-Host "    0) 返回上级菜单 (没有则退出程序)";
        Write-Host "    q) 退出程序";
        Write-Host "    $nl";
        # INPUT
        $input = Read-Host "输入序号 (可多选)";
        $input = $input.ToCharArray() | Sort-Object -Unique;
        # Menu logic
        foreach($inputItem in $input) {
            if ($inputItem -eq "q") {
                Invoke-Expression 'cls';
                exit 0;
            } elseif($inputItem -eq "0") {
                Invoke-Expression 'cls';
                $flag = $false;
            } elseif ($main.option[$inputItem-49].submenu) {
                Main  $main.option[$inputItem-49].submenu;
            } elseif ($main.option[$inputItem-49].action -eq "ActivateWindows") {
                ActivateWindows $main.option[$inputItem-49].name;
            } elseif ($main.option[$inputItem-49].action -eq "ActivateOffice") {
                ActivateOffice $main.Option[$inputItem-49].name $main.option[$inputItem-49].key $main.option[$inputItem-49].osppdir;
            } elseif ($main.option[$inputItem-49].action -eq "ConvertOffice") {
                ConvertOffice $main.Option[$inputItem-49].name $main.option[$inputItem-49].osppdir $main.option[$inputItem-49].licenses;
            }
        }
    }
}

function ActivateWindows {
    param (
        [String]$name
    )
    $cmd = 'slmgr'
    $WARNING = @"
作者用爱发电，出了任何问题都是不会负责的
回车后就没有回头路了，你是否真的想好了？
"@
    Invoke-Expression 'cls';
    "正在{0}..." -f $name
    "使用 KMS Server: {0}" -f $script:KMS_SERVER;
    Write-Host $WARNING -f red
    Invoke-Expression 'Pause'

    Invoke-Expression "$cmd /skms $script:KMS_SERVER";
    Invoke-Expression "$cmd /ato";
}

function CheckOSPP {
    param (
        [String]$verion
    )
    if (Test-Path "$env:ProgramFiles\Microsoft Office\$verion\ospp.vbs") {
        return "$env:ProgramFiles\Microsoft Office\$verion\ospp.vbs"
    } elseif (Test-Path "$env:ProgramFiles(x86)\Microsoft Office\$verion\ospp.vbs") {
        return "$env:ProgramFiles(x86)\Microsoft Office\$verion\ospp.vbs"
    } else {
        while ($true) {
            Invoke-Expression 'cls'
            Write-Host "错误！未找到 ospp.vbs 文件" -f red
            Write-Host "请输入 ospp.vbs 文件的位置 (一般在 Office 的安装目录中)" -f green
            Write-Host "使用 Ctrl+C 强制退出" -f green
            $ospp = Read-Host "ospp.vbs"
            if (Test-Path $ospp) {
                return $ospp
            }
        }
    }
}

function ActivateOffice {
    param (
        [String]$name, [String]$key, [String]$osppPath
    )
    $cmd = 'cscript'
    $ospp = CheckOSPP $osppPath
    $WARNING = @"
作者用爱发电，出了任何问题都是不会负责的
回车后就没有回头路了，你是否真的想好了？
如果 ospp.vbs 位置不对请立即 Ctrl+C 强制退出
"@
    Invoke-Expression 'cls';
    "正在激活 {0}..." -f $name
    "ospp.vbs 位置: {0}" -f $ospp;
    "使用 KMS Server: {0}" -f $script:KMS_SERVER;
    "使用 KMS Key: {0}" -f $key
    Write-Host $WARNING -f red
    Invoke-Expression 'Pause'

    Invoke-Expression "$cmd `"$ospp`" /inpkey:$key"
    Invoke-Expression "$cmd `"$ospp`" /sethst:$script:KMS_SERVER"
    Invoke-Expression "$cmd `"$ospp`" /act"

    Write-Host "$nl"
    Write-Host "激活完成！！"-f green
    Write-Host "当前 $name 的激活状态:" -f green
    Write-Host "$nl"
    Invoke-Expression "$cmd `"$ospp`" /dstatus"
    Invoke-Expression 'Pause'
}

function ConvertOffice {
    param (
        [String]$name, [String]$osppPath, [Array]$licenses
    )
    $cmd = 'cscript'
    $ospp = CheckOSPP $osppPath
    $WARNING = @"
作者用爱发电，出了任何问题都是不会负责的
回车后就没有回头路了，你是否真的想好了？
如果 ospp.vbs 位置不对请立即 Ctrl+C 强制退出
"@
    Invoke-Expression 'cls';
    "正在{0}..." -f $name
    "ospp.vbs 位置: {0}" -f $ospp;
    foreach ($licitem in $licenses) {
        "license 位置(相对于 ospp.vbs): ..\root\{0}" -f $licitem
    }
    Write-Host $WARNING -f red
    Invoke-Expression 'Pause'

    # cscript "%ospp%" /inslic:"..\root\Licenses16\ProPlusVL_KMS_Client-ppd.xrm-ms"
    foreach ($licitem in $licenses) {
        Write-Host "$cmd `"$ospp`" /inslic:`"..\root\$licitem`""
        # Invoke-Expression "$cmd `"$ospp`" /inslic:$licitem"
    }
    Invoke-Expression 'Pause'
}

Main $script:MENU_INFO
