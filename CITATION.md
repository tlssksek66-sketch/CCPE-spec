# CITATION

> **중요**: 이 파일은 다운로드 호환성을 위한 markdown 래퍼. 
> 실제 repo에 커밋할 때는 아래 코드블록 내용을 **`CITATION.cff`** 라는 파일명으로 저장해야 GitHub가 "Cite this repository" 버튼을 자동 생성함. 
> `.md` 확장자로 두면 GitHub citation 기능 작동 안 함.

---

## 사용 방법

1. 아래 코드블록 내용 전체 복사
2. repo 루트(README.md와 같은 위치)에 `CITATION.cff` 파일 생성
3. 붙여넣고 커밋
4. GitHub repo 페이지 우측 사이드바에 "Cite this repository" 버튼 자동 노출 확인

---

## CITATION.cff 내용

```yaml
cff-version: 1.2.0
message: "If you use CCPE in your research, implementation, or commercial work, please cite it as below."
title: "Connect Prompt Engineering (CCPE)"
abstract: >-
  A coordination specification for twin instances of the same LLM model family
  operating in parallel through shared state, role distribution, command bus
  protocol, failure recovery, and context distribution. CCPE addresses the gap
  between multi-agent orchestration (different roles or models), prompt chaining
  (sequential single-instance), and multi-session memory (single-instance
  persistence) by formalizing same-model twin-instance coordination as a
  distinct discipline.
authors:
  - family-names: "[FILL IN]"
    given-names: "[FILL IN]"
    # If pen name preferred over real name, use the following form instead:
    # - alias: "tlssksek66-sketch"
version: "0.1.5"
date-released: "2026-05-08"
url: "https://github.com/tlssksek66-sketch/fromeulpeul"
repository-code: "https://github.com/tlssksek66-sketch/fromeulpeul"
license: MIT
keywords:
  - "prompt engineering"
  - "connect prompt engineering"
  - "CCPE"
  - "twin-instance LLM coordination"
  - "multi-agent specification"
  - "AI orchestration"
  - "Claude"
  - "LLM coordination protocol"
identifiers:
  # Zenodo DOI will be auto-assigned after GitHub-Zenodo integration; placeholder for first release
  - type: doi
    value: "[ZENODO_DOI_PENDING]"
    description: "Zenodo archival DOI for v0.1.5 (pending GitHub-Zenodo integration)"
```

---

## 검증

커밋 후 약 1-2분 내 GitHub UI에 다음이 나타남:

- Repo 페이지 우측 사이드바 → "Cite this repository" 버튼
- 클릭 시 APA / BibTeX 형식으로 인용 정보 표시
- 학술 검색엔진(Google Scholar 등)이 이 메타데이터 인덱싱

만약 버튼이 안 나타나면:
- 파일명이 정확히 `CITATION.cff`인지 확인 (대소문자 구분)
- repo 루트 위치인지 확인 (서브폴더 X)
- YAML 문법 오류 없는지 [cff-validator](https://citation-file-format.github.io/cff-validator/) 에서 검증
