# CITATION

> **중요**: 이 파일은 다운로드 호환성을 위한 markdown 래퍼. 
> 실제 repo의 인용 메타데이터는 루트의 **`CITATION.cff`** 파일이며, GitHub가 이를 파싱해 "Cite this repository" 버튼을 자동 생성함. 
> 이 `CITATION.md`는 인용 형식·등록 절차 안내용 문서.

---

## 현재 배포된 CITATION.cff 내용

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
  - name: "eulpeul"
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
# identifiers:
#   - type: doi
#     value: "10.5281/zenodo.XXXXXXX"
#     description: "Zenodo archival DOI for v0.1.5 (assigned after GitHub-Zenodo integration)"
```

**필드 설명**:
- `authors[0].name: "eulpeul"` — entity form. Zenodo가 creator 매핑 시 `family-names`/`name` 필드를 기대하므로, 단일 필명 케이스에서는 `alias:`가 아닌 `name:` 사용.
- `identifiers` 블록은 GitHub-Zenodo 연동 완료 + 첫 release 발급 후 주석 해제 + 실제 DOI 삽입.

---

## 인용 형식 (사용자용)

**APA**:
> eulpeul. (2026). *Connect Prompt Engineering (CCPE)* (Version 0.1.5) [Computer software]. https://github.com/tlssksek66-sketch/fromeulpeul

**BibTeX**:
```bibtex
@software{eulpeul_ccpe_2026,
  author = {eulpeul},
  title = {Connect Prompt Engineering (CCPE)},
  version = {0.1.5},
  year = {2026},
  url = {https://github.com/tlssksek66-sketch/fromeulpeul},
  license = {MIT}
}
```

**Prose**:
> eulpeul (2026). *Connect Prompt Engineering (CCPE) Specification v0.1.5*. GitHub: `tlssksek66-sketch/fromeulpeul`. https://github.com/tlssksek66-sketch/fromeulpeul

DOI 발급 후에는 위 형식에 `DOI: 10.5281/zenodo.XXXXXXX` 추가.

---

## 검증

GitHub citation 인프라 정상 작동 확인 방법:

1. Repo 페이지 → 우측 사이드바 "**Cite this repository**" 버튼 노출
2. 클릭 시 APA / BibTeX 형식으로 위 내용 표시
3. Repo 메타정보 영역에 `CITATION.cff` 파일 인식 표시

만약 버튼이 안 나타나면:
- 파일명이 정확히 `CITATION.cff`인지 확인 (대소문자 구분)
- repo 루트 위치인지 확인 (서브폴더 X)
- YAML 문법 오류 없는지 [cff-validator](https://citation-file-format.github.io/cff-validator/) 에서 검증

---

## Zenodo DOI 발급 절차

GitHub-Zenodo 연동 후 자동 DOI 발급 워크플로:

1. https://zenodo.org/login/github 접속 → GitHub 계정으로 로그인
2. Zenodo에 GitHub 권한 부여 (repo metadata 접근)
3. Settings → GitHub → repo 목록에서 `CCPE-spec` 토글 ON
4. GitHub repo로 돌아가 새 release 생성 (tag: `v0.1.5`, title: "CCPE v0.1.5")
5. Zenodo가 자동으로 DOI 발급 (보통 5-10분 내)
6. 발급된 DOI를 `CITATION.cff` `identifiers` 블록 주석 해제 + 값 삽입 후 커밋

이후 release마다 자동 DOI 발급 (releases workflow).
