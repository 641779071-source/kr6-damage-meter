# kr6-damage-meter 卸载脚本
# 只删本模组写进存档目录的文件，不碰游戏存档。

param(
    [string]$SaveDir = '',
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$Identity = 'kingdom_rush_genesis'

function Say($msg)  { Write-Host $msg }
function Fail($msg) { Write-Host "错误：$msg" -ForegroundColor Red; exit 1 }

$OurFiles = @(
    'all/director.lua', '_kr6dmg.lua', '_kr6dmg_boot.txt', '_kr6dmg_err.txt'
)
$KeepPrefixes = @('_kr6_slot_backup', '_kr6_global_backup', '_kr6trainer')

if (-not $SaveDir -and -not $env:APPDATA) {
    Fail '环境变量 APPDATA 不存在，请用 -SaveDir 指定目录'
}
$save = if ($SaveDir) { $SaveDir } else { $env:APPDATA + '\' + $Identity }
$save = $save.TrimEnd('\')
if (-not (Test-Path $save)) { Fail "目录不存在：$save" }

$victims = @()
foreach ($rel in $OurFiles) {
    $p = Join-Path $save ($rel -replace '/', '\')
    if (Test-Path $p -PathType Leaf) { $victims += $p }
}
foreach ($f in (Get-ChildItem -Path $save -File -ErrorAction SilentlyContinue)) {
    $keep = $false
    foreach ($kp in $KeepPrefixes) { if ($f.Name.StartsWith($kp)) { $keep = $true } }
    if ($keep) { continue }
    if ($f.Name.StartsWith('_kr6dmg') -or $f.Name.StartsWith('damage_')) {
        if ($victims -notcontains $f.FullName) { $victims += $f.FullName }
    }
}
$origDir = Join-Path $save '_orig'
if (Test-Path $origDir) { $victims += $origDir }

if ($victims.Count -eq 0) { Say '没有找到要删的文件（本来就没装？）'; exit 0 }

Say "存档目录：$save"
foreach ($v in $victims) { Say ('  删除 ' + (Split-Path -Leaf $v)) }
if ($DryRun) { Say "`n（-DryRun：什么都没删）"; exit 0 }

foreach ($v in $victims) { Remove-Item -Recurse -Force $v }
$allDir = Join-Path $save 'all'
if ((Test-Path $allDir) -and -not (Get-ChildItem $allDir -Force)) { Remove-Item $allDir -Force }

Say ''
Say '卸载完成。若曾同时使用 trainer，请重新安装 trainer。'
Say '  ⚠ 游戏开着时请重启一次才会彻底生效。'
