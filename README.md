# 🚕 Taxi Mate (Taxi-Sharing Matching Service)
> **"함께 타고, 함께 아끼세요"** > 대학생들의 등하교 교통비 부담을 줄이고 편리한 이동을 돕는 택시 동승자 매칭 서비스
22
---

<br>

## 💡 프로젝트 소개
- **서비스명:** Taxi Mate
- **핵심 가치:** 비용 절감, 이동 편의성, 신뢰 기반 동승
- **주요 기능**

  1️⃣ **실시간 핀 생성 및 검색** <br>
  &nbsp; &nbsp; 출발지, 목적지, 시각에 따라 다른 사용자와 실시간으로 동승 그룹을 만들거나 찾아보세요.

  2️⃣ **동승자 간 실시간 매칭 및 채팅** <br>
  &nbsp; &nbsp; 실시간으로 동승 그룹에 참여하고 채팅을 통해 탑승 위치를 맞추고 안전하게 소통하세요.

  3️⃣ **동승 이용 현황** <br>
  &nbsp; &nbsp; 내가 참여 중인 동승 그룹의 출발 시간, 매칭 인원, 정산 상태를 실시간으로 확인하고 관리할 수 있습니다.

  4️⃣ **간편한 정산 시스템** <br>
  &nbsp; &nbsp; 이용 현황과 채팅을 통해 정산을 요청하고 간편하게 관리할 수 있습니다.

  5️⃣ **사용자 신뢰도** <br>
  &nbsp; &nbsp; 매너 온도 및 태그 시스템으로 안전한 이용을 보장합니다.
 
 
  
 
 
<br><br>

## 🎬 소개 영상
*이미지를 클릭하면 시연 영상으로 이동합니다.(영상 제작 예정)*
<br><br>

## 👨‍👩‍👧‍👦 팀 소개 (Crescit)
'자라다', '성장하다'라는 의미를 가진 팀 **Crescit**입니다.

<table style="width:100%;">
  <tr>
    <th>이름</th>
    <th>역할</th>
    <th>주요 담당 업무</th>
  </tr>
  <tr>
    <td>김태림</td>
    <td>Project Lead / Backend Engineer</td>
    <td>프로젝트 총괄 <br> 백엔드 아키텍처 및 핵심 기능 개발</td>
  </tr>
  <tr>
    <td>김서현</td>
    <td>Backend Engineer</td>
    <td>API 설계 및 서버 로직 구현</td>
  </tr>
  <tr>
    <td>박소윤</td>
    <td>Frontend Engineer</td>
    <td>사용자 인터페이스 및 클라이언트 기능 개발</td>
  </tr>
  <tr>
    <td>한윤구</td>
    <td>Data & Backend Engineer</td>
    <td>데이터베이스 설계 및 관리<br>서비스 아이디어 기획 참여</td>
  </tr>
</table>

<br><br>


## 💻 이용 안내
배포 예정

<br><br>


## 🛠️ 기술 스택
<table>
  <thead>
    <tr>
      <th>영역</th>
      <th>기술</th>
      <th>선정 이유</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Frontend</td>
      <td>Flutter (3.41.4), Dart (3.11.1)</td>
      <td>단일 코드베이스로 Android/iOS 동시 지원, 선언적 UI</td>
    </tr>
    <tr>
      <td>Backend</td>
      <td>Django (Python)</td>
      <td>ORM 기반 빠른 개발, 마이그레이션 관리, 내장 인증/관리자</td>
    </tr>
    <tr>
      <td>Database</td>
      <td>PostgreSQL</td>
      <td>트랜잭션 안전성, 외래키 무결성, 반경 내 모집 탐색</td>
    </tr>
    <tr>
      <td>실시간 통신</td>
      <td>Django Channels (WebSocket)</td>
      <td>채팅 메시지 송수신, 매칭 알림 실시간 전달</td>
    </tr>
    <tr>
      <td>캐시</td>
      <td>Redis (ElastiCache)</td>
      <td>WebSocket 채널 레이어, 세션/캐시 관리</td>
    </tr>
    <tr>
      <td>파일 저장</td>
      <td>AWS S3</td>
      <td>영수증/프로필 이미지 저장 (Presigned URL 업로드)</td>
    </tr>
    <tr>
      <td rowspan="2">외부 API</td>
      <td>Kakao Map API</td>
      <td>지도 렌더링, 위치/핀 표시</td>
    </tr>
    <tr>
      <td>KakaoPay 송금 링크</td>
      <td>정산 시 외부 송금 페이지로 딥링크 이동</td>
    </tr>
  </tbody>
</table>

<br><br>


## 🌐 시스템 아키텍쳐
<img src="https://raw.githubusercontent.com/kookmin-sw/2026-capstone-19/master/System%20Architecture.jpeg" 
     alt="시스템 아키텍쳐 이미지" width="700">




<br><br>


## 📂 소개 자료
보고서, 발표 피피티 등 삽입 예정
