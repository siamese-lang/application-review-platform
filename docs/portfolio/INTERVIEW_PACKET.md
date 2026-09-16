# M12 Interview Packet

Status: FINAL INTERVIEW/APPLICATION COMPRESSION  
Primary use: Korean IT systems / infrastructure / operations interviews  
Evidence source: committed M9/M10/M11/M6 evidence cards only

## 1. 사용 원칙

이 문서는 문장을 그대로 암기하기 위한 스크립트가 아니다.

면접에서는 다음 순서를 유지한다.

`문제 → 확인한 근거 → 선택한 조치 → 재검증 → 남은 한계`

기술 이름을 먼저 나열하지 않는다. 숫자는 결과를 설명하는 데 필요한 경우에만 사용한다.

프로젝트 전체를 설명할 때도 M1부터 M11까지 작업 순서를 말하지 않는다. 최종 시스템과 세 가지 대표 문제해결 사례를 기준으로 설명한다.

## 2. 프로젝트 전체 소개

### 30초 버전

지원사업의 신청·심사 업무를 주제로, 신청서 작성과 제출, 심사, 보완 요청, 승인·반려, 첨부파일과 상태 이력까지 구현한 개인 프로젝트입니다. GCP IaaS 환경에 실제로 배포한 뒤 기능 구현에서 끝내지 않고 부하, 장애, 백업·복구 상황을 직접 재현했습니다. 대표적으로 PostgreSQL 병목을 실행계획으로 확인해 개선했고, 객체 저장소의 단일 접속 지점을 장애 실험으로 찾아 보완했으며, 별도 환경에서 DB PITR과 첨부파일까지 포함한 복구를 검증했습니다.

### 60초 버전

지원사업 신청·심사 플랫폼을 개인 프로젝트로 구현했습니다. 신청자는 공고를 확인하고 신청서를 작성·제출하며, 심사자는 제출된 신청서를 맡아 보완 요청이나 승인·반려를 처리하도록 했습니다. 이 과정에서 권한, 상태 전이, 이력, 감사 기록, 첨부파일까지 업무 상태로 묶어 관리했습니다.

운영 측면에서는 GCP의 edge, application, PostgreSQL, Garage object storage, observability 역할을 분리해 배포했고, 같은 시스템을 대상으로 실제 부하와 장애, 복구를 검증했습니다. 10만 건 합성 데이터 부하에서 PostgreSQL 쿼리 병목을 찾아 한 개의 인덱스로 개선했고, 3노드 객체 저장소에서도 고정 endpoint 때문에 첨부 기능이 실패하는 문제를 장애 실험으로 확인해 같은 장애 조건에서 다시 검증했습니다. 마지막으로 PostgreSQL PITR과 DB·첨부파일 checkpoint를 이용해 별도 환경을 재구축하고 실제 업무 흐름과 파일 무결성까지 확인했습니다.

## 3. 이력서·프로젝트 한 줄

### M9 — PostgreSQL 성능 진단

10만 건 합성 데이터의 반복 부하에서 PostgreSQL reviewer queue 병목을 `pg_stat_statements`와 `EXPLAIN (ANALYZE, BUFFERS)`로 추적하고, 단일 Flyway 인덱스 적용 후 동일 조건에서 p95 2.07초→80.9ms, DB CPU 평균 90.9%→37.1%로 개선했습니다.

### M10 — Garage endpoint 장애

3노드 Garage 복제 환경에서 저장 데이터는 유지되지만 고정 S3 endpoint 장애 시 첨부 요청의 28.692%가 실패하는 문제를 분리해 확인하고, app-local failover proxy 적용 후 동일 노드 장애 재시험에서 첨부 오류율을 0%로 검증했습니다.

### M11 — Disaster Recovery

PostgreSQL PITR에서 목표 시점 이전 상태 포함·이후 상태 제외와 27.229초 복구를 확인하고, PostgreSQL/Garage checkpoint를 별도 환경에 복원해 신청·심사 흐름과 첨부파일 SHA-256 무결성까지 검증했습니다.

### Supporting — M6 release/rollback

backend/frontend를 동일 source SHA와 checksum으로 묶는 immutable release 경로를 구성하고, schema-compatible rollback을 실제 수행해 38.346초 내 이전 release 복귀와 전체 업무·첨부 흐름 정상 동작을 확인했습니다.

## 4. M9 — PostgreSQL 성능 문제 설명

### 60–90초 답변

대표 부하에서 시스템이 느려졌을 때 바로 서버 사양이나 connection pool부터 늘리지 않고 원인을 먼저 좁혔습니다.

10만 건의 합성 신청 데이터를 넣고 동일한 업무 비율로 부하를 걸었는데, peak 조건에서 non-file p95가 약 2.07초까지 올라갔고 DB CPU 평균은 약 91%, Hikari pending도 평균 39개 수준이었습니다. 반면 edge 부하는 낮았고 애플리케이션 probe는 살아 있었기 때문에 DB 쪽을 우선 확인했습니다.

`pg_stat_statements`로 비용이 큰 SQL을 찾고 reviewer queue의 result와 count 쿼리를 `EXPLAIN ANALYZE BUFFERS`로 확인했습니다. application 테이블을 parallel sequential scan하고 정렬하는 비용이 컸습니다. 조건문만 단순화하는 방법도 먼저 비교했지만 scan과 buffer 사용량이 줄지 않아 적용하지 않았습니다.

그래서 status와 정렬 순서를 맞춘 인덱스 하나만 Flyway로 추가했습니다. 같은 부하를 다시 실행했을 때 p95는 2.07초에서 약 81ms, DB CPU 평균은 90.9%에서 37.1%로 내려갔고 완료된 업무 요청도 29,814건에서 44,097건으로 늘었습니다.

이 경험에서 가장 중요했던 점은 튜닝 방법을 먼저 정하지 않고, 부하와 실행계획으로 병목을 확인한 뒤 필요한 변경만 적용한 것입니다.

### 후속 질문 — 왜 connection pool을 먼저 늘리지 않았나?

Hikari pending이 많았지만 동시에 DB CPU가 거의 포화 상태였습니다. 이때 pool만 키우면 DB로 더 많은 동시 요청을 보내 압력을 높일 수 있습니다. pending은 원인이라기보다 DB 쿼리 비용 때문에 연결이 오래 점유된 결과일 가능성이 높았기 때문에 먼저 SQL 실행 비용을 확인했습니다.

### 후속 질문 — 왜 그 인덱스를 선택했나?

reviewer queue가 status 조건으로 대상을 좁히고 `updated_at, id` 순서로 결과를 가져오는 경로였습니다. 기존에는 조건을 만족하는 행을 찾은 뒤 별도 정렬이 필요했는데, `(status, updated_at, id) INCLUDE (reviewer_id)` 인덱스로 필터와 정렬 순서를 함께 지원하도록 했습니다. 적용 후 result 쿼리는 parallel sequential scan과 top-N sort 대신 ordered index scan으로 바뀌었습니다.

### 후속 질문 — 왜 Redis/cache를 쓰지 않았나?

측정된 문제는 캐시 부재가 아니라 reviewer queue의 DB access path였습니다. 캐시를 추가하면 invalidation과 일관성이라는 운영 문제가 새로 생기는데, 한 개의 인덱스로 병목이 해소됐기 때문에 추가 복잡성을 정당화할 근거가 없었습니다.

### 후속 질문 — count 쿼리도 완전히 해결됐나?

아닙니다. result 쿼리는 큰 폭으로 줄었지만 count는 여전히 matching set을 처리해야 해서 heap work가 남았습니다. 다만 전체 peak 조건에서 DB CPU와 pool waiting이 더 이상 포화되지 않았기 때문에 두 번째 최적화를 추가하면 측정 근거 없이 튜닝을 이어가는 상황이 된다고 판단했습니다.

### 반드시 함께 말할 한계

- 100 requests/s와 100 VU는 이 프로젝트가 정의한 bounded synthetic workload다.
- 결과를 실제 서비스 수용량이나 SLA로 말하지 않는다.
- 변경 후 일부 client/transport outlier의 정확한 원인은 확정하지 않았다.

## 5. M10 — 객체 저장소 장애 설명

### 60–90초 답변

첨부파일은 Garage를 3노드, replication factor 3으로 구성했습니다. 처음에는 복제본이 세 노드에 있으니 한 노드가 내려가도 첨부 기능이 유지될 것으로 예상했습니다.

장애 테스트에서 storage-02를 내렸을 때는 첨부 오류가 없었습니다. 그런데 애플리케이션이 S3 endpoint로 직접 사용하던 storage-01을 내리자 전체 첨부 요청의 약 28.7%가 실패했습니다. 이때 PostgreSQL과 Spring 애플리케이션, 나머지 Garage 두 노드, 첨부와 무관한 업무 요청은 정상이었습니다.

그래서 데이터 복제 문제와 client endpoint 가용성 문제를 분리할 수 있었습니다. 데이터는 다른 노드에 남아 있었지만 애플리케이션이 그 노드로 갈 경로가 없었습니다.

큰 HA 구조를 새로 만드는 대신 app-01 내부에 Nginx proxy를 두고 세 Garage endpoint를 upstream으로 구성했습니다. 이후 동일하게 storage-01 Garage를 중지하는 테스트를 다시 했고 기존 파일 조회, 업로드, 업로드 후 다운로드, 삭제까지 모두 오류율 0%였고 새 FAILED나 PENDING 상태도 남지 않았습니다.

이 사례에서는 '복제돼 있다'는 것과 '애플리케이션이 복제본에 접근할 수 있다'는 것이 다른 문제라는 점을 장애 실험으로 확인한 것이 핵심입니다.

### 후속 질문 — replication factor 3인데 왜 장애가 났나?

Garage 내부에서는 데이터 복제가 되어 있었지만 Spring 애플리케이션의 S3 client가 storage-01 하나만 endpoint로 알고 있었습니다. 따라서 storage-01이 내려가면 다른 두 노드에 데이터가 있어도 요청을 보낼 경로 자체가 없었습니다.

### 후속 질문 — 왜 별도 load balancer를 만들지 않았나?

실험에서 확인한 문제는 Garage endpoint 하나에 대한 의존이었습니다. app-01이 이미 단일 application failure domain이었기 때문에 app-local proxy를 두면 새로운 독립 failure domain을 추가하지 않으면서 필요한 endpoint failover를 만들 수 있었습니다. 새 managed load balancer나 storage 제품을 추가하는 것은 측정된 문제보다 범위가 컸습니다.

### 후속 질문 — Nginx proxy에서 주의한 부분은?

S3 요청은 SigV4 서명을 사용하기 때문에 요청의 Host 등 서명에 영향을 주는 값을 임의로 바꾸면 인증이 실패할 수 있습니다. 들어온 Host를 유지하면서 정상 upstream에는 그대로 전달하고, 연결 실패처럼 재시도가 가능한 경우 다른 Garage node로 넘기도록 구성했습니다.

### 후속 질문 — 기존 64개의 FAILED row는 자동으로 복구했나?

아닙니다. baseline 장애에서 생성된 64개 FAILED row는 동일 조건 재시험을 위해 synthetic Dataset M을 guarded reload하면서 초기화했습니다. 따라서 이 결과를 FAILED row 자동 reconciliation 기능의 증거로 사용하지 않습니다.

### 반드시 함께 말할 한계

- 검증 범위는 단일 Garage node 장애다.
- app-01 자체는 여전히 single application failure domain이다.
- network partition, 동시 다중 노드 장애, PostgreSQL HA는 증명하지 않았다.

## 6. M11 — Disaster Recovery 설명

### 60–90초 답변

복구 테스트에서는 서버 프로세스가 다시 뜨는 것과 실제 업무 데이터가 복구되는 것을 구분했습니다.

먼저 PostgreSQL은 별도 recovery VM에서 PITR을 수행했습니다. 목표 시점 전후에 PRE와 POST marker를 만들고 복구한 뒤 PRE는 존재하고 POST는 없어야 한다는 조건을 확인했습니다. 결과적으로 그 경계가 정확히 맞았고, DB가 검증 가능한 상태가 되기까지 27.229초가 걸렸습니다. 목표 시점과 복구된 marker 사이 차이는 1.087882초 이내였습니다.

그다음에는 DB와 Garage가 하나의 transaction이나 snapshot을 공유하지 않는다는 점을 고려했습니다. 신청 변경을 잠시 막고 background 작업을 정지한 뒤 attachment 상태가 안정됐는지 확인하고, 같은 maintenance window 안에서 PostgreSQL backup과 Garage object manifest를 만들었습니다.

이 checkpoint를 서울 기존 환경이 아니라 도쿄의 새 VM과 새 disk에 복원했습니다. DB뿐 아니라 21개 object의 key, size, SHA-256을 확인했고, 실제 HTTPS 경로에서 신청서 작성·제출, 첨부파일, 심사 시작·승인, 최종 이력까지 다시 실행했습니다. history, audit, attachment 검증도 모두 통과했습니다.

다만 전체 DR 시작부터 업무 가능 시점까지 하나의 공통 timestamp를 남기지 못했기 때문에 full-DR RTO는 주장하지 않습니다. 이처럼 확인한 범위와 확인하지 못한 범위를 분리한 것도 복구 증거의 일부라고 생각합니다.

### 후속 질문 — replication이 있는데 왜 backup이 필요한가?

replication은 현재 데이터의 복사본을 여러 노드에 유지하는 방식이라 논리적 삭제나 잘못된 변경도 복제될 수 있습니다. backup과 WAL archive는 과거 시점으로 돌아가기 위한 독립된 recovery boundary입니다. 그래서 M10의 replication availability와 M11의 backup/recovery를 다른 문제로 다뤘습니다.

### 후속 질문 — DB와 object storage를 어떻게 일관되게 백업했나?

PostgreSQL과 Garage 사이에 distributed transaction이나 공통 snapshot 기능이 없기 때문에 원자적이라고 가정하지 않았습니다. public mutation을 막고 in-flight 작업을 정리한 뒤 application/background reconciliation을 정지하고 attachment lifecycle에 PENDING, DELETE_PENDING, FAILED가 없는 것을 확인했습니다. 그 상태에서 DB backup과 Garage manifest/object copy를 만들고 검증한 후 서비스를 다시 열었습니다.

### 후속 질문 — PITR의 RPO가 1.087882초라는 뜻인가?

정확히는 marker-granularity recovery gap입니다. 요청한 target보다 1.087882초 앞의 PRE marker가 복구된 것을 확인했다는 의미입니다. WAL replay가 정확히 그 간격의 손실만 가진다고 일반화하지 않습니다. 프로젝트 내부의 DB RPO 목표 5분 이내라는 조건에는 충분히 들어왔습니다.

### 후속 질문 — full DR RTO는 얼마인가?

측정했다고 말하지 않습니다. PostgreSQL restore나 Garage restore 같은 component timing은 있지만, 장애 시작부터 전체 업무가 가능한 시점까지 하나의 authoritative start/end timestamp를 남기지 않았기 때문입니다. component 시간을 더해서 full-DR RTO처럼 표현하지 않았습니다.

### 후속 질문 — PostgreSQL HA를 왜 추가하지 않았나?

M11의 질문은 현재 architecture에서 backup과 recovery가 실제로 되는지였습니다. automatic failover는 별도의 availability architecture 문제입니다. 복구 증거를 만들기 위해 HA를 추가하면 실험 범위가 바뀌므로, single primary라는 제한을 그대로 남기고 PITR과 rebuild만 검증했습니다.

### 반드시 함께 말할 한계

- DB PITR RTO와 marker recovery gap만 측정했다.
- checkpoint maintenance time은 full-DR RTO가 아니다.
- full-system effective RPO도 측정하지 않았다.
- PostgreSQL single primary와 continuous multi-region availability는 남은 제한이다.

## 7. Supporting — M6 release/rollback

### 45–60초 답변

배포에서는 새 버전이 동작한다는 것뿐 아니라 어떤 source가 실행 중인지와 이전 버전으로 정확히 돌아갈 수 있는지를 확인하고 싶었습니다.

backend JAR과 frontend archive를 하나의 source SHA 기준 release bundle로 만들고 각각 checksum을 기록했습니다. bundle은 immutable OCI digest로 보관하고 서버에는 versioned release path로 설치해 current와 previous release identity를 남겼습니다.

그 상태에서 실제 B release에서 A release로 rollback했고 서비스 준비까지 38.346초가 걸렸습니다. DB migration은 되돌리지 않았고, 두 release 사이 schema compatibility를 먼저 확인한 상태에서 application binary만 rollback했습니다. 이후 HTTPS 신청·심사와 첨부파일 SHA 검증까지 통과한 뒤 다시 B release로 복귀했습니다.

이 사례는 배포 자동화 자체보다 배포 대상의 identity와 rollback 가능성을 검증한 경험으로 설명합니다.

### 후속 질문 — 왜 DB migration도 rollback하지 않았나?

Flyway는 forward migration을 기준으로 운영했고, 데이터가 포함된 schema down migration은 application binary rollback과 다른 위험을 가집니다. 따라서 rollback은 schema-compatible한 release pair에서만 허용하고 DB migration을 자동으로 되돌리지 않는 방식을 선택했습니다.

## 8. 직무별 사용 방법

### 시스템/클라우드/인프라 운영

우선순위:

1. M10 fault isolation;
2. M11 recovery;
3. M6 release/rollback;
4. M9 performance.

강조할 내용:

- 구성요소 간 failure domain을 구분한 방법;
- 장애 재현 시 control signal을 같이 본 방법;
- 조치 후 같은 fault를 반복한 방법;
- 복구 후 process가 아니라 업무 흐름을 확인한 방법;
- OpenTofu/Ansible과 exact release identity를 이용한 재현성.

### 전산/IT 시스템 운영

우선순위:

1. 프로젝트 전체 업무 흐름;
2. M11 business-state recovery;
3. M10 장애 영향 범위 확인;
4. M9 성능 원인 분석.

강조할 내용:

- 신청/심사 업무 상태와 이력의 일관성;
- 권한과 상태 규칙을 server-side에 둔 이유;
- 조치 이후 실제 업무가 끝까지 정상 처리되는지 확인한 방식;
- 기술 자체보다 업무 중단·데이터 오류 가능성을 기준으로 판단한 과정.

### DB/성능 질문이 강한 직무

M9를 첫 사례로 사용한다.

반드시 설명할 수 있어야 하는 것:

- sequential scan과 index scan 차이;
- `EXPLAIN (ANALYZE, BUFFERS)`에서 무엇을 봤는지;
- 왜 pool tuning보다 SQL access path를 먼저 본 것인지;
- composite index column 순서;
- count query residual work.

## 9. 답변에서 피해야 할 표현

다음 표현은 evidence보다 강하므로 사용하지 않는다.

- "production traffic에서 검증했다"
- "100 RPS를 안정적으로 처리한다"
- "무중단 HA를 구현했다"
- "3노드라서 장애가 발생하지 않는다"
- "DR RTO가 16초다"
- "RPO가 정확히 1.08초다"
- "multi-region DR을 구축했다"라고만 말해 continuous availability까지 암시하는 표현
- "Redis/Kubernetes를 쓰지 않아도 된다"처럼 일반화하는 표현

대신 해당 프로젝트의 조건을 붙인다.

예:

- "이 프로젝트의 10만 건 합성 데이터와 bounded peak 조건에서 확인했습니다."
- "단일 Garage node 장애 조건에서 같은 fault를 반복해 확인했습니다."
- "DB PITR은 27.229초로 측정했고 full-DR end-to-end RTO는 측정하지 않았습니다."

## 10. 면접 준비용 최소 기억 구조

세 사례의 세부 숫자를 모두 암기할 필요는 없다.

### M9

`2.07 s → SQL plan → one index → 80.9 ms`

보조 숫자:

`DB CPU 90.9% → 37.1%`

### M10

`replication OK / endpoint down → attachment error 28.692% → local failover proxy → same fault 0%`

### M11

`PITR PRE/POST boundary → 27.229 s → DB/Garage checkpoint → fresh rebuild → business + SHA integrity PASS`

### M6 supporting

`exact SHA/digest → current/previous → B→A rollback 38.346 s → full smoke → B restore`

숫자가 기억나지 않으면 임의로 말하지 말고 방향과 검증 방법을 정확히 설명한다.

## 11. 근거 문서

- 전체 포트폴리오:
  `docs/portfolio/PROJECT_PORTFOLIO.md`
- 최종 story selection:
  `docs/portfolio/M12_STORY_SELECTION.md`
- M9:
  `docs/portfolio/M8_POSTGRESQL_QUERY_BOTTLENECK_EVIDENCE.md`
- M10:
  `docs/portfolio/M10_GARAGE_ENDPOINT_FAILOVER_EVIDENCE.md`
- M11:
  `docs/portfolio/M11_DISASTER_RECOVERY_EVIDENCE.md`
- M6:
  `docs/portfolio/M6_IMMUTABLE_RELEASE_ROLLBACK_EVIDENCE.md`

## 12. Phase 3 conclusion

면접에서 이 프로젝트는 다음 세 문장으로 구분해 기억한다.

- **M9:** 느려졌을 때 추측으로 튜닝하지 않고 부하·SQL·실행계획으로 병목을 찾아 동일 조건에서 다시 측정했다.
- **M10:** 복제된 데이터가 있어도 접속 경로가 단일이면 기능은 실패할 수 있다는 점을 fault comparison으로 확인하고 같은 장애로 수정 효과를 검증했다.
- **M11:** 복구는 프로세스 기동이 아니라 특정 시점의 업무 데이터와 첨부파일이 다시 일관되게 사용 가능한지를 기준으로 검증했다.
