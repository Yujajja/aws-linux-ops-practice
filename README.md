# AWS EC2 기반 Linux 서버 운영 자동화 및 장애 1차 대응 실습

## 1. 프로젝트 개요

AWS EC2 2대를 서로 다른 가용 영역에 배치하고, Application Load Balancer와 Target Group을 구성하여 기본적인 고가용성 웹 서버 구조를 실습했습니다.

Ansible Playbook으로 Nginx 설치와 서버 점검 스크립트 배포를 자동화하고, ALB Health Check와 CloudWatch Alarm을 통해 장애 감지 및 복구 흐름을 확인했습니다.

---

## 2. 사용 기술

- AWS EC2
- VPC / Public Subnet
- Security Group
- Application Load Balancer
- Target Group
- CloudWatch Alarm
- Amazon Linux 2023
- Nginx
- Ansible
- Shell Script

---

## 3. 아키텍처

```text
User
  ↓
Application Load Balancer
  ↓
Target Group
  ↓
EC2 Web Server 1 / EC2 Web Server 2
  ↓
Nginx
```

---

## 4. 폴더 구조

```text
aws-linux-ops-practice
├─ ansible
│  ├─ inventory.ini
│  ├─ ansible.cfg
│  └─ setup-server.yml
├─ scripts
│  └─ server_check.sh
├─ docs
│  └─ runbook.md
├─ .gitignore
└─ README.md
```

---

## 5. 주요 내용

### Ansible 자동화

- EC2 2대에 Nginx 설치
- Nginx 서비스 시작 및 자동 실행 설정
- 서버별 웹페이지 생성
- 서버 점검 Shell Script 배포
- 점검 스크립트 실행 결과 확인

### 서버 점검 스크립트

`scripts/server_check.sh`를 통해 다음 항목을 점검했습니다.

- 서버 가동 시간
- CPU Load Average
- Memory 사용량
- Disk 사용량
- 22번 SSH 포트 상태
- 80번 HTTP 포트 상태
- Nginx 서비스 상태
- 최근 Nginx 로그

---

## 6. 장애 재현 및 복구

`ops-web-1`의 Nginx 서비스를 중지하여 장애 상황을 재현했습니다.

```bash
ansible ops-web-1 -b -m shell -a "systemctl stop nginx"
```

장애 발생 후 Target Group에서 `ops-web-1`은 unhealthy 상태로 전환되었고, `ops-web-2`는 healthy 상태를 유지했습니다.

ALB는 정상 서버로 트래픽을 전달하여 서비스 접속이 유지되는 것을 확인했습니다.

복구는 아래 명령어로 진행했습니다.

```bash
ansible ops-web-1 -b -m shell -a "systemctl start nginx"
```

복구 후 두 서버 모두 active 상태로 돌아왔고, Target Group에서도 healthy 상태를 확인했습니다.

---

## 7. CloudWatch Alarm

ALB Target Group의 `UnHealthyHostCount` 지표를 기준으로 CloudWatch Alarm을 구성했습니다.

```text
Alarm Name: ops-alb-unhealthy-host-alarm
Metric: UnHealthyHostCount
Condition: UnHealthyHostCount >= 1
```

비정상 대상이 1대 이상 발생했을 때 CloudWatch 경보 상태로 전환되는 것을 확인했습니다.

---

## 8. Runbook

장애 발생 시 확인 및 복구 절차를 `docs/runbook.md`에 정리했습니다.

Runbook에는 다음 내용을 포함했습니다.

- 웹 서비스 접속 불가 시 확인 절차
- Target Group Health Check 확인 방법
- Nginx 상태 확인 및 복구 명령어
- CloudWatch Alarm 확인 절차
- 보안 그룹 확인 포인트
- 장애 대응 순서 요약

---

## 9. 실습 결과

- EC2 2대를 서로 다른 가용 영역에 배치했습니다.
- Ansible로 Nginx 설치와 서버 점검 스크립트 배포를 자동화했습니다.
- ALB와 Target Group을 구성하여 트래픽 분산 구조를 확인했습니다.
- Nginx 중지를 통해 장애 상황을 재현했습니다.
- Target Group Health Check와 CloudWatch Alarm을 통해 장애 감지를 확인했습니다.
- Runbook을 작성하여 장애 1차 대응 절차를 문서화했습니다.

---

## 10. 배운 점

이번 실습을 통해 단일 서버 구성의 한계를 이해하고, ALB와 Target Group을 활용한 기본적인 고가용성 구조를 경험했습니다.

또한 Ansible과 Shell Script를 활용해 반복적인 서버 운영 작업을 자동화하고, CloudWatch Alarm과 Runbook을 통해 장애 감지 및 1차 대응 흐름을 정리했습니다.
