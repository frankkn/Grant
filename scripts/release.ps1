<#
.SYNOPSIS
  Grant 發版腳本：一次完成版本號更新、README badge、changelog、commit 與 tag。

.DESCRIPTION
  會自動做以下事情：
    1. 讀取 pubspec.yaml 目前的 build number 並 +1，把版本改成 <Version>+<build>
    2. 更新 README 最上方的 version badge 與 release 連結
    3. 在 README「版本資訊」表格最上方插入一筆 changelog
    4. git commit「Release v<Version>」並建立 tag v<Version>
    5. 加上 -Push 時，順便 push main 與 tag（會觸發 APK 打包與網頁自動部署）

.PARAMETER Version
  語意化版本號，例如 1.2.2（不含 v）。

.PARAMETER Notes
  這個版本的更新內容（會寫進 changelog 表格那一列）。

.PARAMETER Date
  日期，預設今天（yyyy-MM-dd）。

.PARAMETER Push
  加上此旗標才會 push；不加則只在本機完成 commit 與 tag，並印出 push 指令。

.EXAMPLE
  ./scripts/release.ps1 -Version 1.2.2 -Notes "修正某某問題、新增某功能"

.EXAMPLE
  ./scripts/release.ps1 -Version 1.3.0 -Notes "重大改版" -Push
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$Version,
  [Parameter(Mandatory = $true)][string]$Notes,
  [string]$Date = (Get-Date -Format 'yyyy-MM-dd'),
  [switch]$Push
)

$ErrorActionPreference = 'Stop'

if ($Version -notmatch '^\d+\.\d+\.\d+$') {
  throw "Version 格式錯誤：請用語意化版本，例如 1.2.2（不要加 v）"
}

$root = Split-Path -Parent $PSScriptRoot
$pubspecPath = Join-Path $root 'pubspec.yaml'
$readmePath  = Join-Path $root 'README.md'

function Write-Utf8NoBom([string]$Path, [string]$Content) {
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Content, $enc)
}

# --- 1. pubspec.yaml：版本號 + build number 自動 +1 ---
$pubspec = [System.IO.File]::ReadAllText($pubspecPath)
if ($pubspec -notmatch 'version:\s*(\d+\.\d+\.\d+)\+(\d+)') {
  throw "在 pubspec.yaml 找不到 version: X.Y.Z+N 這一行"
}
$build = [int]$Matches[2] + 1
$newVersion = "$Version+$build"
$pubspec = [regex]::Replace($pubspec, 'version:\s*\d+\.\d+\.\d+\+\d+', "version: $newVersion")
Write-Utf8NoBom $pubspecPath $pubspec
Write-Host "pubspec.yaml → version: $newVersion"

# --- 2. README：version badge 與 release 連結 ---
$readme = [System.IO.File]::ReadAllText($readmePath)
$readme = [regex]::Replace($readme, 'version-v[\d.]+-pink', "version-v$Version-pink")
$readme = [regex]::Replace($readme, 'releases/tag/v[\d.]+', "releases/tag/v$Version")

# --- 3. README：在 changelog 表格表頭分隔線後插入新列 ---
$sep = [regex]::Match($readme, '\|-{3,}\|-{3,}\|-{3,}\|\r?\n')
if (-not $sep.Success) {
  throw "在 README 找不到版本資訊表格（| 版本 | 日期 | 更新內容 |）"
}
$pos = $sep.Index + $sep.Length
$row = "| v$Version | $Date | $Notes |`r`n"
$readme = $readme.Substring(0, $pos) + $row + $readme.Substring($pos)
Write-Utf8NoBom $readmePath $readme
Write-Host "README.md → badge 與 changelog 已更新"

# --- 4. git commit + tag ---
Push-Location $root
try {
  git add pubspec.yaml README.md
  git commit -m "Release v$Version"
  git tag "v$Version"
  Write-Host "已建立 commit 與 tag v$Version"

  if ($Push) {
    git push origin main
    git push origin "v$Version"
    Write-Host "已 push main 與 tag v$Version（APK 打包與網頁部署將自動觸發）"
  }
  else {
    Write-Host ""
    Write-Host "尚未 push。確認無誤後執行："
    Write-Host "  git push origin main; git push origin v$Version"
  }
}
finally {
  Pop-Location
}
