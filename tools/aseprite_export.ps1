# ============================================================================
# [2026-08-01 신규] Aseprite(.aseprite) → PNG 일괄 내보내기
# ----------------------------------------------------------------------------
# 왜 필요한가
#   Godot 은 .aseprite 파일을 읽지 못한다. (플러그인 없이는 임포트 자체가 안 됨)
#   그래서 아트를 고칠 때마다 PNG 로 다시 뽑아야 하는데, 파일이 20개가 넘으면
#   Aseprite 를 열어서 File > Export 를 20번 누르게 된다. 그 짓을 대신한다.
#
# 쓰는 법 (PowerShell 에서)
#   powershell -ExecutionPolicy Bypass -File tools\aseprite_export.ps1
#
#   폴더를 바꾸고 싶으면:
#   ... -File tools\aseprite_export.ps1 -Src "D:\내아트" -Dst "assets\textures\smartshape"
#
# 그 다음 반드시:
#   Godot --headless --path . --import      ← 새 PNG 를 Godot 이 인식하게 한다
#
# ⚠⚠ [2026-08-01 주의] 이 스크립트는 **.aseprite 원본이 최신일 때만** 쓸 것.
#   2026-08-01 에 실제로 사고가 났다: 아티스트가 PNG 를 뽑은 뒤 **PNG 쪽에서**
#   캔버스 크기를 32x16 으로 통일했는데, .aseprite 원본은 옛 크기 그대로였다.
#   그 상태에서 이 스크립트를 돌리면 옛 크기가 다시 덮어써져 작업이 날아간다.
#   → PNG 를 직접 손봤다면 이 스크립트 대신 아래처럼 **복사만** 할 것:
#       Copy-Item "<원본폴더>\*.png" "<프로젝트>\assets\textures\smartshape\" -Force
# ============================================================================

param(
    # 아티스트가 .aseprite 원본을 두는 곳 (Godot 프로젝트 밖이어도 된다)
    [string]$Src = "C:\Users\김도형\OneDrive\Desktop\타일셋도구들",
    # PNG 가 들어갈 곳 (Godot 프로젝트 안)
    [string]$Dst = "C:\Users\김도형\Documents\GitHub\color\assets\textures\smartshape",
    # Aseprite 실행 파일. 스팀판은 보통 SteamLibrary\steamapps\common\Aseprite 에 있다.
    [string]$Aseprite = "D:\SteamLibrary\steamapps\common\Aseprite\Aseprite.exe"
)

if (-not (Test-Path $Aseprite)) {
    Write-Error "Aseprite 를 못 찾음: $Aseprite  → -Aseprite 옵션으로 경로를 알려주세요"
    exit 1
}
if (-not (Test-Path $Dst)) { New-Item -ItemType Directory -Force -Path $Dst | Out-Null }

$files = Get-ChildItem "$Src\*.aseprite" -ErrorAction SilentlyContinue
if ($files.Count -eq 0) { Write-Warning "$Src 에 .aseprite 파일이 없습니다"; exit 0 }

foreach ($f in $files) {
    $out = Join-Path $Dst ($f.BaseName + ".png")
    # -b (--batch) = 창을 띄우지 않고 명령만 실행.
    # Aseprite 는 GUI 앱이라 `&` 로 부르면 PowerShell 이 끝날 때까지 안 기다린다 →
    # 반드시 Start-Process -Wait 로 불러야 다음 파일 처리 전에 저장이 끝난다.
    Start-Process -FilePath $Aseprite -Wait -NoNewWindow `
        -ArgumentList @("-b", "`"$($f.FullName)`"", "--save-as", "`"$out`"")
    if (Test-Path $out) { Write-Host "  OK   $($f.BaseName).png" }
    else { Write-Host "  FAIL $($f.BaseName)" -ForegroundColor Red }
}

Write-Host ""
Write-Host "완료: $($files.Count) 개 → $Dst"
Write-Host "다음: Godot --headless --path . --import 를 실행해 Godot 에 반영하세요."
