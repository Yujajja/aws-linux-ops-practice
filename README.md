# AWS EC2 기반 Linux 서버 운영 자동화 및 장애 1차 대응 실습

## 1. 프로젝트 개요

AWS EC2 기반 Linux 서버 운영 환경을 구성하고, Ansible을 활용해 서버 설정을 자동화한 실습 프로젝트입니다.

EC2 2대를 서로 다른 가용 영역에 배치하고 Application Load Balancer와 Target Group을 구성하여, 특정 서버에 장애가 발생해도 정상 서버로 트래픽이 유지되는 구조를 확인했습니다.

또한 Shell Script를 통해 서버 상태 점검 항목을 표준화하고, CloudWatch Alarm과 Runbook을 활용해 장애 감지 및 1차 대응 흐름을 정리했습니다.

---

## 2. 프로젝트 목표

- AWS EC2 기반 Linux 서버 운영 환경 구성
- VPC, Public Subnet, Security Group 기본 구조 이해
- Application Load Balancer와 Target Group 구성
- Ansible Playbook을 활용한 Nginx 설치 자동화
- Shell Script를 활용한 서버 상태 점검 자동화
- ALB Health Check를 통한 장애 감지 확인
- CloudWatch Alarm을 활용한 비정상 서버 감지
- 장애 1차 대응 Runbook 작성

---

## 3. 기술 스택

| 구분 | 기술 |
|---|---|
| Cloud | AWS EC2, VPC, Public Subnet, Internet Gateway, Route Table |
| Load Balancing | Application Load Balancer, Target Group |
| Security | Security Group |
| Monitoring | CloudWatch Alarm, ALB Health Check |
| OS | Amazon Linux 2023 |
| Web Server | Nginx |
| Automation | Ansible |
| Script | Shell Script |
| Documentation | Markdown, Runbook |

---

## 4. 프로젝트 구조

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

## 5. 인프라 구성 흐름
<p align="center">
    <img width="1448" height="910" alt="AWS Linux 운영 자동화 및 장애 대응 흐름도" src="https://github.com/user-attachments/assets/040d879f-75d5-4a15-bbbe-0e5fd6ba1cc0" />
</p>

```text
사용자 요청
    ↓
Application Load Balancer
    ↓
Target Group
    ↓
EC2 Web Server 1 / EC2 Web Server 2
    ↓
Nginx
```

### 구성 요약

```text
VPC
├─ Public Subnet A
│  └─ ops-web-1
│
├─ Public Subnet C
│  └─ ops-web-2
│
└─ Application Load Balancer
   └─ Target Group
      ├─ ops-web-1
      └─ ops-web-2
```

---

## 6. AWS 네트워크 구성

### 6.1 VPC

실습 전용 VPC를 생성하여 EC2, Subnet, ALB를 같은 네트워크 안에서 구성했습니다.

```text
VPC Name: ops-practice-vpc
CIDR: 10.0.0.0/16
```

---

### 6.2 Public Subnet

EC2 2대를 서로 다른 가용 영역에 배치하기 위해 Public Subnet 2개를 생성했습니다.

```text
ops-public-subnet-a: 10.0.1.0/24
ops-public-subnet-c: 10.0.2.0/24
```

서로 다른 가용 영역에 EC2를 배치하여 한 가용 영역에 문제가 발생하더라도 다른 서버가 서비스를 유지할 수 있는 구조를 실습했습니다.

---

### 6.3 Internet Gateway / Route Table

Public Subnet의 EC2와 ALB가 인터넷과 통신할 수 있도록 Internet Gateway와 Route Table을 구성했습니다.

```text
0.0.0.0/0 → Internet Gateway
```

---

## 7. 보안 그룹 구성

### 7.1 ALB Security Group

ALB는 사용자의 HTTP 요청을 받을 수 있도록 80번 포트를 허용했습니다.

| Type | Port | Source |
|---|---:|---|
| HTTP | 80 | 0.0.0.0/0 |

---

### 7.2 EC2 Security Group

EC2는 직접 HTTP 접속을 허용하지 않고, ALB Security Group에서 들어오는 80번 요청만 허용했습니다.

| Type | Port | Source |
|---|---:|---|
| SSH | 22 | My IP |
| SSH | 22 | EC2 Security Group |
| HTTP | 80 | ALB Security Group |

이를 통해 사용자는 EC2에 직접 접근하지 않고, ALB를 통해서만 웹 서버에 접근하도록 구성했습니다.

---

## 8. Ansible 자동화

Ansible Playbook을 사용하여 EC2 2대에 동일한 서버 설정을 자동화했습니다.

### 8.1 Inventory 구성

`inventory.ini` 파일에 Ansible이 접속할 서버 목록을 작성했습니다.

```ini
[web]
ops-web-1 ansible_host=10.0.1.67 ansible_user=ec2-user ansible_ssh_private_key_file=/home/ec2-user/ops-practice-key.pem
ops-web-2 ansible_host=10.0.2.188 ansible_user=ec2-user ansible_ssh_private_key_file=/home/ec2-user/ops-practice-key.pem

[web:vars]
ansible_python_interpreter=/usr/bin/python3.9
```

---

### 8.2 Playbook 주요 작업

`setup-server.yml` 파일을 통해 다음 작업을 자동화했습니다.

- Nginx 설치
- Nginx 서비스 시작
- Nginx 부팅 시 자동 실행 설정
- 서버별 index.html 생성
- `/opt/ops` 디렉터리 생성
- 서버 점검 Shell Script 배포
- 서버 점검 스크립트 실행 결과 확인

실행 명령어:

```bash
cd ~/aws-linux-ops-practice/ansible
ansible-playbook setup-server.yml
```

---

## 9. 서버 상태 점검 스크립트

`scripts/server_check.sh` 파일을 작성하여 Linux 서버 운영 시 확인해야 할 항목을 점검하도록 구성했습니다.

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

실행 명령어:

```bash
ansible web -b -m shell -a "/opt/ops/server_check.sh"
```

점검 결과는 서버 내부의 아래 위치에 저장되도록 구성했습니다.

```text
/tmp/server_check_result.txt
```

---

## 10. ALB와 Target Group 구성

Application Load Balancer를 생성하고 EC2 2대를 Target Group에 등록했습니다.

### 구성 목적

- 사용자는 ALB DNS로 접속
- ALB가 Target Group에 등록된 EC2로 트래픽 분산
- Health Check를 통해 비정상 EC2 감지
- 비정상 서버는 트래픽 대상에서 제외

### 확인 결과

ALB DNS로 접속했을 때 Nginx 웹페이지가 정상적으로 응답하는 것을 확인했습니다.

새로고침 시 `ops-web-1`, `ops-web-2`가 번갈아 응답하여 ALB가 두 서버로 트래픽을 분산하는 것을 확인했습니다.

---

## 11. 장애 재현 및 복구

`ops-web-1`의 Nginx 서비스를 중지하여 장애 상황을 재현했습니다.

### 11.1 장애 재현

```bash
ansible ops-web-1 -b -m shell -a "systemctl stop nginx"
```

장애 확인 명령어:

```bash
ansible web -b -m shell -a "systemctl is-active nginx || true"
```

예상 결과:

```text
ops-web-1: inactive
ops-web-2: active
```

---

### 11.2 Target Group Health Check 확인

Nginx가 중지된 `ops-web-1`은 Target Group에서 unhealthy 상태로 전환되었습니다.

반면 `ops-web-2`는 healthy 상태를 유지했고, ALB는 정상 서버로 트래픽을 전달하여 서비스 접속이 유지되는 것을 확인했습니다.

```text
ops-web-1 → unhealthy
ops-web-2 → healthy
```

---

### 11.3 장애 복구

```bash
ansible ops-web-1 -b -m shell -a "systemctl start nginx"
```

복구 확인 명령어:

```bash
ansible web -b -m shell -a "systemctl is-active nginx || true"
```

복구 결과:

```text
ops-web-1: active
ops-web-2: active
```

이후 Target Group에서 두 서버 모두 healthy 상태로 복구되는 것을 확인했습니다.

---

## 12. CloudWatch Alarm 구성

ALB Target Group의 비정상 서버 발생 여부를 감지하기 위해 CloudWatch Alarm을 구성했습니다.

### 알람 설정

```text
Alarm Name: ops-alb-unhealthy-host-alarm
Metric: UnHealthyHostCount
Condition: UnHealthyHostCount >= 1
```

### 확인 결과

`ops-web-1`의 Nginx 중지 후 Target Group에서 unhealthy 상태가 발생했고, CloudWatch Alarm이 경보 상태로 전환되는 것을 확인했습니다.

복구 후 Nginx 상태와 Target Group 상태가 정상으로 돌아오는 것을 확인했습니다.

---

<p align="center">
  <img width="1619" height="608" alt="장애- 경보상태" src="https://github.com/user-attachments/assets/d0918653-6eb8-49e3-a787-c764d7c8b174" />
</p>

## 13. Runbook 작성

장애 발생 시 확인 및 복구 절차를 `docs/runbook.md`에 정리했습니다.

Runbook에는 다음 내용을 포함했습니다.

- 웹 서비스 접속 불가 시 확인 절차
- Target Group Health Check 이상 시 확인 절차
- Nginx 상태 확인 및 복구 명령어
- 서버 상태 점검 스크립트 실행 방법
- CloudWatch Alarm 확인 절차
- 보안 그룹 확인 포인트
- 장애 대응 순서 요약

---

## 14. 테스트 시나리오

### 14.1 정상 접속 확인

ALB DNS로 접속하여 Nginx 웹페이지가 정상적으로 응답하는지 확인했습니다.

예상 결과:

```text
ops-web-1 또는 ops-web-2 응답
Nginx is running
Configured by Ansible Playbook
```

---

### 14.2 EC2 한 대 장애 재현

`ops-web-1`의 Nginx를 중지했습니다.

```bash
ansible ops-web-1 -b -m shell -a "systemctl stop nginx"
```

예상 결과:

```text
ops-web-1 → inactive / unhealthy
ops-web-2 → active / healthy
```

---

### 14.3 ALB 서비스 유지 확인

한 대의 EC2가 unhealthy 상태가 되어도 ALB가 healthy 서버로 트래픽을 전달하는지 확인했습니다.

예상 결과:

```text
ALB 접속 유지
ops-web-2 응답 확인
```

---

### 14.4 장애 복구 확인

`ops-web-1`의 Nginx를 다시 시작했습니다.

```bash
ansible ops-web-1 -b -m shell -a "systemctl start nginx"
```

예상 결과:

```text
ops-web-1 → active / healthy
ops-web-2 → active / healthy
```

---

## 15. 트러블슈팅

### 15.1 SSH 접속 문제

EC2 접속 시 SSH 연결이 되지 않는 문제가 발생할 수 있습니다.

확인 항목:

```text
- EC2 Public IP 변경 여부
- Key Pair 경로
- Security Group의 SSH 22번 포트 허용 여부
- pem 파일 권한
```

Linux 환경에서 pem 파일 권한은 아래처럼 설정합니다.

```bash
chmod 400 ops-practice-key.pem
```

---

### 15.2 Ansible 접속 실패

Ansible ping 테스트가 실패할 경우 Inventory 설정과 SSH 접근 가능 여부를 확인했습니다.

확인 명령어:

```bash
ansible web -m ping
```

확인 항목:

```text
- inventory.ini의 private IP
- ansible_user 값
- ansible_ssh_private_key_file 경로
- EC2 간 SSH 허용 여부
```

---

### 15.3 Target Group unhealthy 발생

Target Group에서 EC2가 unhealthy로 표시될 경우 Nginx 상태와 80번 포트 상태를 확인했습니다.

확인 명령어:

```bash
ansible web -b -m shell -a "systemctl is-active nginx || true"
ansible web -m shell -a "ss -tulnp | grep ':80'"
```

해결:

```bash
ansible web -b -m shell -a "systemctl restart nginx"
```

---

### 15.4 CloudWatch Alarm 데이터 부족 상태

CloudWatch Alarm 생성 직후 `데이터 부족` 상태가 표시되었습니다.

원인:

```text
경보 상태를 판단할 만큼의 지표 데이터가 아직 충분히 수집되지 않음
```

해결:

```text
몇 분 대기 후 지표가 수집되면 정상 또는 경보 상태로 전환됨
```

---

## 16. 프로젝트 결과

- AWS EC2 2대를 서로 다른 가용 영역에 배치했습니다.
- Ansible Playbook으로 Nginx 설치와 실행을 자동화했습니다.
- Shell Script로 서버 상태 점검 항목을 표준화했습니다.
- ALB와 Target Group을 구성하여 트래픽 분산 구조를 확인했습니다.
- EC2 한 대의 Nginx 중지를 통해 장애 상황을 재현했습니다.
- Target Group Health Check에서 unhealthy 상태를 확인했습니다.
- CloudWatch Alarm으로 비정상 서버 감지를 확인했습니다.
- 장애 복구 후 두 서버가 healthy 상태로 돌아오는 것을 확인했습니다.
- 장애 1차 대응 Runbook을 작성했습니다.

---

## 17. 프로젝트를 통해 배운 점

단일 EC2 구성은 장애 발생 시 서비스 중단 위험이 있기 때문에, 최소 2대 이상의 EC2를 서로 다른 가용 영역에 배치하고 ALB를 통해 트래픽을 분산하는 구조가 필요하다는 것을 확인했습니다.

또한 Ansible Playbook을 통해 반복적인 서버 설정 작업을 자동화하고, Shell Script를 활용해 Linux 서버 점검 항목을 표준화하는 과정을 경험했습니다.

이번 실습을 통해 단순 서버 구축을 넘어, ALB Health Check와 CloudWatch Alarm을 활용한 장애 감지, Runbook 기반 장애 1차 대응 절차까지 운영 관점에서 정리할 수 있었습니다.

---

## 18. 향후 보완점

- Private Subnet과 Bastion Host 구조로 보안성 강화
- Auto Scaling Group을 활용한 EC2 자동 복구 구성
- CloudWatch Logs를 활용한 Nginx 로그 수집
- SNS 연동을 통한 장애 알림 자동화
- Ansible Role 구조로 Playbook 재사용성 개선
- Terraform을 활용한 AWS 인프라 구성 자동화
