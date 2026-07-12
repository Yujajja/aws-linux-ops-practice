# 장애 1차 대응 Runbook

## 1. 웹 서비스 접속 불가

### 증상
- ALB DNS로 접속 시 웹페이지가 열리지 않음
- 브라우저에서 응답 지연 또는 오류 발생
- Target Group의 대상 상태가 unhealthy로 표시됨

### 확인 명령어

```bash
ansible web -b -m shell -a "systemctl is-active nginx || true"
ansible web -m shell -a "curl -s http://localhost | grep ops-web"
```

### 확인 위치
- EC2 > 대상 그룹 > ops-web-tg > 대상
- Target 상태가 healthy인지 확인
- ALB DNS 접속 확인
- CloudWatch Alarm 상태 확인

### 원인 후보
- Nginx 서비스 중지
- EC2 인스턴스 장애
- 보안 그룹 80번 포트 설정 오류
- Target Group Health Check 실패
- ALB Listener 또는 Target Group 연결 오류

### 1차 조치

```bash
ansible web -b -m shell -a "systemctl start nginx"
ansible web -b -m shell -a "systemctl is-active nginx || true"
```

### 공유 기준
- Target Group에서 unhealthy 대상이 발생한 경우
- ALB DNS 접속이 지속적으로 실패하는 경우
- Nginx 재시작 후에도 복구되지 않는 경우
- CloudWatch Alarm이 경보 상태로 전환된 경우

---

## 2. EC2 한 대의 Nginx 중지

### 증상
- 특정 EC2의 Nginx 상태가 inactive로 표시됨
- Target Group에서 해당 EC2가 unhealthy로 표시됨
- ALB는 나머지 healthy 서버로 트래픽을 전달함

### 확인 명령어

```bash
ansible web -b -m shell -a "systemctl is-active nginx || true"
```

### 장애 재현 명령어

```bash
ansible ops-web-1 -b -m shell -a "systemctl stop nginx"
```

### 복구 명령어

```bash
ansible ops-web-1 -b -m shell -a "systemctl start nginx"
```

### 복구 확인 명령어

```bash
ansible web -b -m shell -a "systemctl is-active nginx || true"
```

### 확인 결과
- ops-web-1: Nginx 중지 시 Target Group에서 unhealthy 발생
- ops-web-2: healthy 상태 유지
- ALB 접속은 정상 서버인 ops-web-2로 유지됨
- ops-web-1 복구 후 다시 healthy 상태로 전환됨

### 재발 방지 메모
- CloudWatch Alarm의 UnHealthyHostCount 지표를 통해 비정상 대상 발생 여부를 감지한다.
- 장애 발생 시 Target Group Health Check와 Nginx 상태를 우선 확인한다.
- 단일 서버 장애가 전체 서비스 중단으로 이어지지 않도록 최소 2대 이상의 EC2를 Target Group에 등록한다.

---

## 3. ALB Target Group Health Check 이상

### 증상
- Target Group 대상 상태가 unhealthy로 표시됨
- ALB DNS 접속 시 특정 서버 응답이 제외됨
- CloudWatch Alarm이 경보 상태로 전환됨

### 확인 위치
- EC2 > 대상 그룹 > ops-web-tg > 대상
- 상태 확인 결과 healthy / unhealthy 확인
- 상태 확인 경로 `/` 확인
- 상태 확인 포트 `traffic-port` 확인

### 확인 명령어

```bash
ansible web -b -m shell -a "systemctl is-active nginx || true"
ansible web -m shell -a "curl -s http://localhost | grep ops-web"
ansible web -m shell -a "ss -tulnp | grep ':80'"
```

### 원인 후보
- Nginx 서비스 중지
- 80번 포트 미응답
- index.html 응답 실패
- EC2 보안 그룹에서 ALB 접근 차단
- Health Check 경로 설정 오류

### 1차 조치

```bash
ansible web -b -m shell -a "systemctl restart nginx"
ansible web -b -m shell -a "systemctl is-active nginx || true"
```

### 확인 기준
- Target Group에서 unhealthy 대상이 healthy로 복구되는지 확인
- ALB DNS 접속 시 정상 웹페이지가 응답하는지 확인

---

## 4. 서버 상태 점검

### 점검 스크립트 실행

```bash
ansible web -b -m shell -a "/opt/ops/server_check.sh"
```

### 점검 항목
- 서버 가동 시간
- CPU Load Average
- Memory 사용량
- Disk 사용량
- 22번 SSH 포트 상태
- 80번 HTTP 포트 상태
- Nginx active 상태
- Nginx enabled 상태
- 최근 Nginx 로그

### 점검 결과 저장 위치

```bash
/tmp/server_check_result.txt
```

### 점검 결과 확인 명령어

```bash
ansible web -b -m shell -a "cat /tmp/server_check_result.txt"
```

---

## 5. CloudWatch Alarm 확인

### 알람 이름

```text
ops-alb-unhealthy-host-alarm
```

### 감시 지표

```text
UnHealthyHostCount
```

### 경보 조건

```text
UnHealthyHostCount >= 1
```

### 의미
Target Group 안에 unhealthy 상태인 EC2가 1대 이상 발생하면 CloudWatch 경보 상태로 전환된다.

### 확인 위치
- CloudWatch > 경보 > 모든 경보
- ops-alb-unhealthy-host-alarm 상태 확인

### 장애 발생 시 확인 순서
1. CloudWatch Alarm이 경보 상태인지 확인
2. Target Group에서 어떤 EC2가 unhealthy인지 확인
3. 해당 EC2의 Nginx 상태 확인
4. 필요 시 Nginx 재시작
5. Target Group이 healthy로 복구되는지 확인

---

## 6. 보안 그룹 확인

### ALB 보안 그룹
- 보안 그룹 이름: ops-alb-sg
- 인바운드 규칙
  - HTTP 80
  - Source: 0.0.0.0/0

### EC2 보안 그룹
- 보안 그룹 이름: ops-web-sg
- 인바운드 규칙
  - SSH 22
  - Source: 내 IP
  - SSH 22
  - Source: ops-web-sg
  - HTTP 80
  - Source: ops-alb-sg

### 확인 포인트
- 사용자는 ALB로만 HTTP 접속한다.
- EC2의 80번 포트는 ALB 보안 그룹에서 오는 요청만 허용한다.
- SSH는 내 IP 또는 같은 보안 그룹 내 EC2끼리만 허용한다.

---

## 7. 장애 대응 순서 요약

1. ALB DNS 접속 확인
2. Target Group Health Check 상태 확인
3. CloudWatch Alarm 상태 확인
4. Nginx 서비스 상태 확인
5. 서버 점검 스크립트 실행
6. Nginx 재시작 또는 복구 명령 실행
7. Target Group healthy 복구 확인
8. ALB DNS 접속 정상 여부 확인
9. 장애 내용과 조치 결과 기록

---

## 8. 이번 실습에서 확인한 장애 대응 흐름

### 장애 재현
- ops-web-1의 Nginx 서비스를 중지하여 장애 상황을 재현했다.
- Target Group에서 ops-web-1이 unhealthy 상태로 전환되는 것을 확인했다.
- ops-web-2는 healthy 상태를 유지했다.
- ALB 접속은 정상 서버인 ops-web-2로 유지되는 것을 확인했다.

### 장애 복구
- Ansible ad-hoc 명령으로 ops-web-1의 Nginx 서비스를 다시 시작했다.
- ops-web-1과 ops-web-2 모두 active 상태임을 확인했다.
- Target Group에서 두 서버가 다시 healthy 상태로 복구되는 것을 확인했다.

### 사용 명령어

```bash
ansible ops-web-1 -b -m shell -a "systemctl stop nginx"
ansible web -b -m shell -a "systemctl is-active nginx || true"
ansible ops-web-1 -b -m shell -a "systemctl start nginx"
ansible web -b -m shell -a "systemctl is-active nginx || true"
```

---

## 9. 운영 관점에서 배운 점

- 단일 EC2 구성은 장애 발생 시 서비스 중단 위험이 있으므로, 최소 2대 이상의 EC2를 서로 다른 가용 영역에 배치하는 것이 가용성 측면에서 유리하다.
- ALB Target Group Health Check를 통해 비정상 서버를 자동으로 감지할 수 있다.
- Ansible을 사용하면 여러 서버에 동일한 설정을 반복적으로 적용할 수 있다.
- Shell Script를 활용하면 서버 상태 점검 항목을 표준화할 수 있다.
- CloudWatch Alarm을 통해 비정상 서버 발생 여부를 모니터링할 수 있다.
