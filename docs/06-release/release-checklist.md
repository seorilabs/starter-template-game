# 네이티브 내부 테스트 체크리스트

- [ ] npm test와 CI의 전체 입력 여정, 저장 복원, 작은 화면 렌더 확인
- [ ] npm run check:release로 두 네이티브 빌드 입력 확인
- [ ] 중앙 원장 최초 기준과 태그 영수증 확인
- [ ] Release에 마켓별 출시 노트와 같은 후보의 개발 근거 첨부
- [ ] 서명 AAB의 package, versionCode, target SDK, 인증서와 파일 해시 확인
- [ ] iOS archive의 Bundle ID, 버전, 배포 서명, 프로파일과 아이콘 확인
- [ ] Play internal 트랙과 테스터 참여 링크 확인
- [ ] TestFlight 처리 VALID와 내부 그룹, 빌드와 테스터 연결 확인
- [ ] 로그와 원본 증적의 NAS 복사 및 직접 읽기 해시 검증

이 목록은 실행 결과를 대신하지 않는다. 기기와 시뮬레이터는 사용하지 않으며 네이티브 설치, 실행, 결제와 운영 서버는 미검증이다. 심사와 공개 출시는 범위에 없다. AppsInToss와 Pages는 이번에 배포하지 않는다.
