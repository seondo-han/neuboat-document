# document-tools

Avikus 기술 문서를 위한 AsciiDoc 기반 문서 템플릿 시스템입니다.  
Docker 위에서 실행되는 Asciidoctor 파이프라인으로 PDF와 HTML을 빌드합니다.

---

## 목차

- [document-tools](#document-tools)
  - [목차](#목차)
  - [요구사항](#요구사항)
  - [설치](#설치)
  - [명령어](#명령어)
    - [`avk-docs init`](#avk-docs-init)
    - [`avk-docs build pdf`](#avk-docs-build-pdf)
    - [`avk-docs build html`](#avk-docs-build-html)
    - [`avk-docs serve html`](#avk-docs-serve-html)
  - [문서 구조](#문서-구조)
    - [`document.adoc`](#documentadoc)
    - [`metadata.adoc`](#metadataadoc)
  - [템플릿 구조](#템플릿-구조)
  - [테마 커스터마이징](#테마-커스터마이징)
    - [기본 테마 선택](#기본-테마-선택)
    - [`flow` 테마 — 챕터 페이지나눔 직접 제어](#flow-테마--챕터-페이지나눔-직접-제어)
    - [헤더 / 푸터 수정](#헤더--푸터-수정)
  - [예시 워크플로우](#예시-워크플로우)

---

## 요구사항

| 도구                                                              | 버전                   | 용도                            |
| ----------------------------------------------------------------- | ---------------------- | ------------------------------- |
| [Docker Desktop](https://www.docker.com/products/docker-desktop/) | Docker Compose v2 이상 | PDF / HTML 빌드                 |
| Python 3                                                          | 任意                   | `avk-docs serve html` 로컬 서버 |

> **WSL2 사용자:** Docker Desktop의 WSL2 Integration이 활성화되어 있어야 합니다.  
> Docker Desktop → Settings → Resources → WSL Integration 에서 확인하세요.

---

## 설치

저장소를 클론한 뒤 인스톨러를 한 번만 실행합니다.

```bash
git clone https://github.com/seondo-han/neuboat-document.git
cd neuboat-document
sudo ./install.sh
```

인스톨러가 수행하는 작업:

1. 템플릿 에셋을 `/usr/local/share/document-tools/` 에 복사
2. `/usr/local/bin/avk-docs` 심링크 생성 (어느 디렉토리에서나 `avk-docs` 명령 사용 가능)
3. Docker 이미지 `neuboat-asciidoctor` 빌드
4. `docker` 그룹 생성 및 현재 사용자 추가 (sudo 없이 Docker 실행 가능하도록)
5. Docker 소켓 권한 설정 및 재시작 후에도 유지되도록 `~/.bashrc` 에 픽스 추가

설치 완료 후 **터미널을 새로 열거나** 아래 명령을 실행해야 그룹 변경이 적용됩니다.

```bash
newgrp docker
```

**커스텀 설치 경로:**

```bash
sudo PREFIX=/opt/local ./install.sh
```

**제거:**

```bash
sudo ./install.sh uninstall
```

---

## 명령어

모든 명령은 `avk-docs` CLI를 통해 실행합니다.

```
avk-docs <command> [subcommand] [options]
```

언제든지 `avk-docs --help` 또는 `avk-docs <command> --help` 로 도움말을 확인할 수 있습니다.

---

### `avk-docs init`

새 문서를 템플릿에서 초기화합니다.

```bash
avk-docs init <document-name>
```

현재 디렉토리 안에 `<document-name>/` 폴더가 생성됩니다.  
릴리즈 날짜를 입력하면 `<YYYY-MM-DD> <document-name>/` 형식으로 생성됩니다.

**대화형 입력 항목:**

| 항목                | 설명                                                      | 기본값                            |
| ------------------- | --------------------------------------------------------- | --------------------------------- |
| Document type       | `book` (챕터 번호 포함) 또는 `article` (간단한 편지·메모) | `book`                            |
| Title page          | 표지 포함 여부                                            | `book` → 포함, `article` → 미포함 |
| Product name        | 문서 소제목 (제품명)                                      | `-`                               |
| Document number     | 문서 번호 (예: `AVK-NAV-0001`)                            | `-`                               |
| Module name         | 모듈 이름                                                 | `-`                               |
| Document type       | 문서 유형 (예: `Test Plan`, `Design Document`)            | `-`                               |
| Project manager     | 프로젝트 관리자 (**필수**)                                | —                                 |
| Final editor        | 주 편집자 / 주 저자 (**필수**)                            | —                                 |
| Authors             | 추가 저자 (쉼표 구분)                                     | 공백                              |
| Document version    | 버전 (예: `1.0.0`)                                        | `-`                               |
| Release date        | 발행일 (`YYYY-MM-DD`)                                     | 미입력 시 생략                    |
| Inner cover         | 속표지 (문서 정보 페이지) 포함 여부                       | 포함                              |
| Revision history    | 변경 이력 포함 여부                                       | 포함                              |
| Table of contents   | 목차 포함 여부                                            | 포함                              |
| Figure / Table list | 그림·표 목록 포함 여부                                    | 포함                              |

선택하지 않은 섹션은 `document.adoc` 에서 주석 처리되며, `revision_history.adoc` 등 불필요한 파일은 자동 삭제됩니다.

**플래그로 비대화형 실행:**

```bash
# -y 로 대화형 생략 (모두 기본값 사용)
avk-docs init -y \
  --project-manager "Han Seondo" \
  --final-editor "Han Seondo" \
  --product-name "NEUBOAT" \
  --document-no "AVK-NAV-0001" \
  --document-type "Test Plan" \
  --document-version "1.0.0" \
  --release-date "2026-06-16" \
  my-document
```

---

### `avk-docs build pdf`

AsciiDoc 문서 디렉토리에서 PDF를 빌드합니다.

```bash
avk-docs build pdf <document-name> [version]
```

| 인수             | 설명                                                           |
| ---------------- | -------------------------------------------------------------- |
| `document-name`  | 문서 디렉토리 이름 (현재 디렉토리 기준 상대경로 또는 절대경로) |
| `version` (선택) | 출력 파일명에 붙일 버전 문자열                                 |

**출력 경로:**

```
<document-name>/output/<document-name>.pdf
<document-name>/output/<document-name>_<version>.pdf  ← version 지정 시
```

날짜 접두사 디렉토리 (`2026-06-16 my-document/`) 는 `my-document` 로 지정해도 자동으로 찾습니다.

```bash
avk-docs build pdf my-document
avk-docs build pdf my-document 1.0.0
avk-docs build pdf /absolute/path/to/my-document
```

---

### `avk-docs build html`

AsciiDoc 문서 디렉토리에서 HTML 사이트를 빌드합니다.

```bash
avk-docs build html <document-name>
```

**출력 경로:** `<document-name>/output/html/index.html`

```bash
avk-docs build html my-document
```

---

### `avk-docs serve html`

빌드된 HTML을 로컬 브라우저에서 미리봅니다.

```bash
avk-docs serve html <document-name>
```

`http://localhost:8000` 에서 확인할 수 있습니다.

> HTML이 아직 없다면 먼저 `avk-docs build html <document-name>` 을 실행하세요.

---

## 문서 구조

`avk-docs init` 으로 생성된 문서 디렉토리 구조입니다.

```
my-document/
├── document.adoc              # 문서 진입점 — 모든 섹션을 include 로 조립
├── metadata.adoc              # 문서 메타데이터 (제목, 저자, 버전, 날짜 등)
├── _document_settings.adoc    # AsciiDoc / PDF 렌더링 설정
├── revision_history.adoc      # 변경 이력 표
├── pages/                     # 사용자가 작성하는 본문 페이지 (선택)
├── images/                    # 문서에서 참조하는 이미지
├── generated-images/          # asciidoctor-diagram 자동 생성 이미지
└── output/                    # 빌드 출력 (PDF, HTML)
```

### `document.adoc`

문서 전체를 조립하는 메인 파일입니다. 섹션 포함 여부는 이 파일에서 주석 처리로 제어합니다.

```asciidoc
include::metadata.adoc[]
include::_document_settings.adoc[]

:doctype: book

= {document-title}: {product-name}

// 속표지 (문서 정보 페이지)
include::../template/pages/document_information.adoc[]

// 변경 이력
include::revision_history.adoc[]

// 목차
toc::[]

// 그림 목록
include::../template/pages/figure_list.adoc[]

// 표 목록
include::../template/pages/table_list.adoc[]

== Chapter 1

본문 내용을 여기에 작성합니다.
```

**표지(title page) 동작:**

| `doctype` | 기본      | 비활성화         | 활성화              |
| --------- | --------- | ---------------- | ------------------- |
| `book`    | 표지 포함 | `:notitle:` 추가 | —                   |
| `article` | 표지 없음 | —                | `:title-page:` 추가 |

### `metadata.adoc`

PDF 전체에서 참조되는 문서 속성입니다.

| 속성                 | 설명                                                               |
| -------------------- | ------------------------------------------------------------------ |
| `:product-name:`     | 제품명 — 문서 소제목                                               |
| `:document-title:`   | 문서 제목                                                          |
| `:document-number:`  | 문서 번호 (예: `AVK-NAV-0001`)                                     |
| `:module-name:`      | 모듈 이름, 없으면 `-`                                              |
| `:document-type:`    | 문서 유형 (예: `Design Document`, `Test Plan`)                     |
| `:project-manager:`  | 프로젝트 관리자                                                    |
| `:final-editor:`     | 주 편집자 / 주 저자                                                |
| `:authors:`          | 추가 저자 (쉼표 구분). 없어도 빈 값으로 유지                       |
| `:document-version:` | 버전 (예: `1.0.0`). 없으면 `-`                                     |
| `:release-date:`     | 발행일 (`YYYY-MM-DD`). 없으면 해당 줄과 `:revdate:` 모두 주석 처리 |

헤더에 문서 번호를 표시하지 않으려면:

```asciidoc
:header-left:
```

---

## 템플릿 구조

`template/` 는 모든 문서가 공유하는 레이아웃 에셋입니다. 문서 디렉토리에서 `../template/` 경로로 참조합니다.

```
template/
├── fonts/                     # 내장 폰트 (Inter, NotoSansCJKkr 등)
├── pages/
│   ├── document_information.adoc   # 속표지 (문서 정보 페이지)
│   ├── figure_list.adoc            # 그림 목록
│   └── table_list.adoc             # 표 목록
└── theme/
    ├── pdf-theme.yml          # 기본 PDF 테마 (여러 파일 조합)
    ├── flow-theme.yml         # 챕터 강제 페이지나눔 끈 변형 테마
    ├── cover-page-theme.yml   # 표지 레이아웃
    ├── page-theme.yml         # 헤더 / 푸터 / 여백
    ├── font-theme.yml         # 폰트 패밀리 정의
    ├── table-theme.yml        # 표 스타일
    ├── figure-theme.yml       # 그림 스타일
    └── text-boxes-theme.yml   # 콜아웃 박스 스타일
```

---

## 테마 커스터마이징

### 기본 테마 선택

`_document_settings.adoc` 에서 `:pdf-theme:` 속성으로 테마를 선택합니다.

```asciidoc
:pdf-themesdir: ../template/theme
:pdf-theme: pdf          ← 기본 (pdf-theme.yml)
```

### `flow` 테마 — 챕터 페이지나눔 직접 제어

기본 `book` 타입은 `==` 챕터마다 자동으로 새 페이지에서 시작합니다.  
`flow` 테마를 사용하면 이 동작을 끄고 `<<<` 로 페이지나눔을 직접 제어할 수 있습니다.

```asciidoc
:pdf-theme: flow          ← flow-theme.yml 사용
```

```asciidoc
== 3. 평가 항목
...
<<<                       ← 여기서 페이지나눔

=== 3.1 지표 측정 방법
...
<<<

== 4. 종합 판정
...
// <<< 없음 → 5장이 4장과 같은 페이지에 이어짐

== 5. 향후 계획
...
```

### 헤더 / 푸터 수정

`template/theme/page-theme.yml` 을 편집합니다.

```yaml
header:
  recto: &shared_header
    left:
      content: '{header-left}'      # metadata.adoc 의 :header-left: 값
    right:
      content: '{header-right}'     # metadata.adoc 의 :header-right: 값
  verso: *shared_header             # 홀·짝 동일 레이아웃 (YAML 앵커)

footer:
  recto: &shared_footer
    columns: <28mm <170mm =12mm
    left:
      content: image:avikus-logo.png[pdfwidth=21.6mm]
    center:
      content: '*Avikus Co. Ltd* ...'
    right:
      content: '{page-number}'
  verso: *shared_footer             # 홀·짝 동일 레이아웃
```

> `recto` 는 홀수 페이지, `verso` 는 짝수 페이지입니다.  
> YAML 앵커(`&`)와 별칭(`*`)으로 두 페이지에 동일 레이아웃을 적용합니다.

---

## 예시 워크플로우

```bash
# 1. 새 문서 초기화
cd ~/Documents/my-project
avk-docs init \
  --product-name "NEUBOAT" \
  --final-editor "Seondo Han" \
  --project-manager "Seondo Han" \
  --document-no "AVK-NAV-0001" \
  --document-type "Test Plan" \
  --release-date "2026-06-16" \
  gnss-sensor-comparison

# 2. 문서 작성
cd "2026-06-16 gnss-sensor-comparison"
# document.adoc 편집 ...

# 3. PDF 빌드
avk-docs build pdf gnss-sensor-comparison 1.0.0
# → 2026-06-16 gnss-sensor-comparison/output/gnss-sensor-comparison_1.0.0.pdf

# 4. HTML 빌드 및 미리보기
avk-docs build html gnss-sensor-comparison
avk-docs serve html gnss-sensor-comparison
# → http://localhost:8000
```
