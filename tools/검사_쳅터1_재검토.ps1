param([string]$Phase = 'after')
$ErrorActionPreference = 'Stop'
# 검사 중 Windows 오류 창이 반복되지 않게 자식 엔진 프로세스의 오류를 로그로만 남긴다.
Add-Type -TypeDefinition @'
using System.Runtime.InteropServices;
public static class ChapterReviewErrorMode {
    [DllImport("kernel32.dll")] public static extern uint SetErrorMode(uint mode);
}
'@
[ChapterReviewErrorMode]::SetErrorMode(0x0003) | Out-Null
$reviewRoot = Split-Path -Parent $PSScriptRoot
$reviewOut = Join-Path $reviewRoot "tools/_진단/챕터1_재검토_20261010/$Phase"
New-Item -ItemType Directory -Force -Path $reviewOut | Out-Null
$reviewTests = @('검사_쳅터1_씬불러오기', '시험_경로재생', '시험_기믹', '검사_체크포인트_빛', '시험_구조색_입구부활', '시험_새스테이지', '시험_거미방', '시험_거미방_풀이', '시험_누름계단', '시험_반사와외부', '시험_열쇠_반딧불_추가', '검사_쳅터1_지형겹침', '검사_쳅터1_실행')
$reviewResults = @()
foreach ($reviewTest in $reviewTests) {
    $reviewLog = Join-Path $reviewOut "$reviewTest.log"
    # 제한 환경에서는 엔진 시작 자체가 충돌할 수 있으므로 허용받은 일반 프로세스에서 실행한다.
    & 'C:/Users/Public/godot46/Godot_v4.6.3-stable_win64_console.exe' --headless --disable-crash-handler --rendering-method gl_compatibility --audio-driver Dummy --fixed-fps 60 --path $reviewRoot -s "res://tools/$reviewTest.gd" *> $reviewLog
    $reviewCode = $LASTEXITCODE
    $reviewLines = @(Get-Content -LiteralPath $reviewLog | Where-Object { $_ -match 'FAIL|실패|합계|오류|성공|ERROR|SCRIPT ERROR' })
    $reviewResults += [pscustomobject]@{test=$reviewTest; exit=$reviewCode; summary=$reviewLines}
    Write-Output "$reviewTest : exit=$reviewCode"
}
$reviewResults | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $reviewOut '엔진검사.json') -Encoding utf8
