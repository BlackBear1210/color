# Godot 안전 검사 실행기

## 배경

2026-08-31에 PowerShell의 `Join-Path`에 `res://` 리소스 경로를 넘겨 검사 스크립트 인자가 사라졌다.
그 결과 Godot가 유효한 검사 대상을 받지 못한 상태로 실행되어 응용 프로그램 오류가 발생했다.

## 조치

- `tools/검사_안전실행.ps1`를 추가했다. Windows PowerShell 5.1의 인코딩 문제를 피하기 위해 실행기 코드는 ASCII로만 작성했다.
- 검사 파일을 디스크 경로로 먼저 확인한다.
- Godot 리소스 경로는 `"res://tools/<검사 파일>"` 문자열로만 만든다.
- 검사 파일이 없거나 Godot 실행 파일이 없으면 Godot를 실행하지 않고 즉시 중단한다.
- 검사는 D3D12 대신 OpenGL 호환 렌더러와 더미 오디오로 실행한다.
- 검사 프로세스가 비정상 종료해도 Windows 오류 대화상자가 사용자 화면에 뜨지 않도록 오류 모드를 설정한다.
- 프로젝트 기본 렌더러도 D3D12에서 OpenGL 호환 모드로 바꿨다. 이 게임은 2D 중심이라 호환 모드에서 필요한 CanvasItem 셰이더를 계속 사용할 수 있으며, 에디터·F5도 D3D12 초기화를 피한다.
- 기본은 `check_스마트월드.gd` 하나이며, `-전체`일 때만 14개 전체 검사를 실행한다.
- 프로젝트 루트의 `Godot_안전실행.cmd`를 추가했다. 이 파일은 공용 ASCII 경로의 콘솔 Godot만 사용하고, OpenGL 호환 렌더러를 강제한다. 앞으로 에디터와 F5는 이 실행기로 연 뒤 사용한다.
- 확인 중 Godot 4.6.3의 이 프로젝트 헤드리스 스크립트 실행 경로가 signal 11로 종료되는 것을 재현했다. 따라서 안전 검사기는 기본으로 Godot를 실행하지 않고 경고만 보인다. 강제 재현은 `-AllowHeadlessCrashProbe`를 명시해야 하며, 원인이 해결될 때까지 사용하지 않는다.

## 사용법

```powershell
powershell -ExecutionPolicy Bypass -File tools/검사_안전실행.ps1
powershell -ExecutionPolicy Bypass -File tools/검사_안전실행.ps1 -All
```

에디터는 프로젝트 루트의 `Godot_안전실행.cmd`를 실행해서 연다. 일반 `Godot_v4.6.3-stable_win64.exe`를 직접 실행하지 않는다.

위 두 검사 명령은 현재 Godot를 실행하지 않고 차단 이유만 출력한다. signal 11 재현용 명령은 `-AllowHeadlessCrashProbe`를 추가한 경우뿐이다.
