# Android 로컬 한글 입력

Android에서 Windows 원격 세션의 더보기 메뉴 → **한글 입력**을 열고, 작성 후 **PC로 보내기**를 누릅니다. PC에서 입력할 위치를 먼저 선택하세요.

- 로그인이나 서버 저장 없이 입력창 안에서 임시로 작성합니다. 닫기/세션 종료 시 초안을 폐기합니다.
- view-only, 키보드 권한, 연결 상태를 전송 직전에 확인합니다. 전송 중 중복 탭을 차단합니다.
- 완성된 문자열은 기존 sessionInputString 경로로 전달합니다. 성공 메시지는 전송 요청 완료이며 PC 입력 결과의 수신 확인은 아닙니다.
- 기존 Note/로그인 기능과 실시간 키보드 로직을 바꾸지 않습니다.
- 앱 이름: RustDesk 한글 / 패키지: com.dodegun.rustdesk.ime. 공식 앱과 병행 설치합니다.
- 첫 빌드는 GitHub runner의 임시 debug 키로 서명한 release APK입니다. 공식 앱에 덮어쓸 수 없고, 다음 빌드에서 키가 달라지면 이 테스트 앱도 제거 후 설치해야 할 수 있습니다. 영구 배포 키는 포함하지 않습니다.

## 빌드와 검증 — 2026-10-02

- 기준: 공식 1.5.0, fada664df7a294d1d1a9ca3e7cd3637069122f17
- APK 소스: 82aee92fb3be960178a21dfdf7bb4138aa61d31a
- APK: RustDesk-IME-1.5.0-arm64.apk / arm64-v8a만 포함
- SHA-256: 4344496432f6d0065dbc2b7b68a9984698d4cc6796bf858baeeea3731f881023
- 위젯 테스트 4개, 신규 파일 분석, 원격 화면 통합 분석: 통과
- ARM64 APK 빌드: 성공
- Android 11 x86_64 ARM 변환: 첫 실행의 raster 스레드에서 SIGILL, libndk_translation.so 스택. 실패 기록 보존.
- Android 15 API 35 x86_64 ARM 변환: 동일 해시 APK 설치, 5회 cold start, 300회 seeded Monkey 이벤트, background/foreground 통과. crash buffer 비어 있음.
- 실제 ARM64 휴대폰/Android 16 및 Android→Windows 한글 입력: 미검증. 에뮬레이터 검사로 실기 입력 성공을 보장하지 않습니다.

빌드: https://github.com/Dodegun/rustdesk/actions/runs/37010002042
동일 APK 재검사: https://github.com/Dodegun/rustdesk/actions/runs/37013874079

실기에서는 받침·복합모음, 한영 혼합, 줄바꿈, 이모지, 조합 중 보내기, 연속 탭, 연결 종료, view-only/키보드 권한 철회를 확인해야 합니다.

자동 빌드 워크플로의 실행 검사 환경도 검증된 API 35로 맞췄습니다. 이 문서와 CI 변경은 APK 런타임 코드를 바꾸지 않습니다.
