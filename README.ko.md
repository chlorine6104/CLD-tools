# CLD-tools

[English](README.md) | [Русский](README.ru.md) | [简体中文](README.zh.md) | [Español](README.es.md)

_The Coffin of Andy and Leyley_ (TCOAAL)에서 사용하는 CLD(Coffin Language Data) 파일을 추출, 편집, 리패킹 및 비교하기 위한 Perl 도구 모음입니다.

TCOAAL CLD Tools를 사용하면 게임의 사용자 번역 파일을 확인하고 수정할 수 있습니다. 대사, 이미지, 폰트 추출부터 CLD 파일 재구성 및 파일 간 변경 사항 비교까지 지원합니다.

## 기능

- **CLD 추출:** CLD 파일에서 대사와 리소스를 추출합니다.
- **CSV 내보내기:** 번역 데이터를 UTF-8 CSV 파일로 내보냅니다.
- **템플릿 지원:** 게임의 원본 `dialogue.csv`를 템플릿으로 사용합니다.
- **이미지 추출:** 내장된 이미지를 추출합니다.
- **폰트 추출:** 내장된 폰트 파일을 추출합니다.
- **CLD 리패킹:** 번역 및 리소스 변경 사항을 CLD 파일에 적용합니다.
- **CLD 비교:** 두 CLD 파일의 차이점을 확인합니다.

## 요구 사항

- Perl 5
- Text::CSV (`cld_extract.pl`에서 필요)

그 외 필요한 모듈은 일반적인 Perl 배포판에 포함되어 있습니다.

## 추출기 사용법

    perl cld_extract.pl [--template dialogue.csv] <input.cld> [output_folder]

출력 폴더를 지정하지 않으면 현재 작업 디렉터리를 사용합니다.

### `--template` 사용하기

`--template` 옵션을 사용하려면 먼저 게임의 `translator.exe`를 통해 원본 `dialogue.csv`를 직접 생성해야 합니다.

그다음 생성한 CSV 파일을 `--template` 옵션으로 지정합니다.

    perl cld_extract.pl --template dialogue.csv input.cld output_folder

템플릿의 레이아웃, 항목 순서, 화자 이름 및 영어 텍스트는 유지되며, 번역 데이터는 ID를 기준으로 채워집니다.

### 추출 결과

    output_folder/
    ├── dialogue.csv
    ├── img/
    └── font/

실제 출력 내용은 입력한 CLD 파일에 따라 달라집니다.

`--template`을 사용하지 않으면 영어 열이 비어 있는 기본 CSV 파일을 생성합니다. 이 형식도 `cld_repack.pl`에서 사용할 수 있습니다.

## 리패커 사용법

    perl cld_repack.pl [options] <input.cld> <output.cld> [dialogue.csv] [image_folder] [font_file]

입력 및 출력 경로는 `.cld`로 끝나야 합니다. 출력 경로는 입력 경로와 달라야 합니다.

### 인수

| 인수 | 설명 | 기본값 |
|---|---|---|
| input.cld | 원본 CLD 파일 | 필수 |
| output.cld | 출력 CLD 파일 | 필수 |
| dialogue.csv | 번역 데이터가 포함된 CSV 파일 | 생략 시 기존 데이터 유지 |
| image_folder | 수정된 PNG 이미지 폴더 | `./img` |
| font_file | 적용할 폰트 파일 | 생략 시 기존 폰트 유지 |

### 옵션

| 옵션 | 설명 |
|---|---|
| `--no-images` | 모든 내장 이미지 항목을 제거합니다. |
| `--no-font` | 내장 폰트를 제거하고 폰트 이름을 `GameFont`로 설정합니다. |
| `--font-face NAME` | 폰트 이름을 지정합니다. |

### 예시

**번역 데이터 수정**

    perl cld_repack.pl original.cld modified.cld dialogue.csv

**이미지 수정**

    perl cld_repack.pl original.cld modified.cld dialogue.csv ./img

**폰트 수정**

    perl cld_repack.pl original.cld modified.cld dialogue.csv ./img ./font.ttf

**내장 이미지 제거**

    perl cld_repack.pl --no-images original.cld modified.cld

**내장 폰트 제거**

    perl cld_repack.pl --no-font original.cld modified.cld

### 리패킹 참고 사항

- 번역 셀이 비어 있으면 기존 텍스트를 유지합니다.
- CSV 항목은 ID를 기준으로 대응됩니다.
- 같은 ID가 연속된 행은 여러 줄의 대사를 의미합니다.
- 새로운 ID는 CLD 파일에 추가되지 않습니다.
- CSV에 없는 항목은 기존 데이터를 유지합니다.
- 기존에 존재하는 이미지 항목만 교체할 수 있습니다.
- 이미지는 유효한 PNG 시그니처를 가진 PNG 파일이어야 합니다.
- `./img` 폴더가 없으면 기존 이미지가 유지됩니다.
- 폰트 파일을 지정하지 않으면 기존 폰트가 유지됩니다.
- `./font`에서 지원되는 폰트 파일이 하나만 발견되면 자동으로 선택됩니다.
- 원본 CLD 파일은 덮어쓰지 않습니다.

## Diff 도구 사용법

    perl cld_diff.pl <file_A.cld> <file_B.cld>

두 CLD 파일을 비교하여 다음 항목을 표시합니다.

- 변경된 항목
- A 파일에만 존재하는 항목
- B 파일에만 존재하는 항목

JSON 객체의 키 순서와 공백은 비교에서 무시됩니다. 배열 순서는 유지됩니다.

이미지와 폰트 데이터는 전체 내용을 출력하지 않고 인코딩된 데이터의 길이로 표시합니다.

바이트 단위로 비교하려면 다음 명령어를 사용합니다.

    cmp file_A.cld file_B.cld

Windows에서는 다음 명령어를 사용합니다.

    fc /b file_A.cld file_B.cld

## 기여하기

기여는 언제나 환영합니다!

1. 이 저장소를 Fork합니다.
2. 새 브랜치를 생성합니다.
3. 변경 사항을 적용하고 테스트합니다.
4. Commit합니다.
5. Pull Request를 제출합니다.

개인적인 일정으로 인해 Issue 및 Pull Request에 대한 답변이 늦어질 수 있습니다.

## 면책 조항

TCOAAL CLD Tools는 독립적으로 개발된 프로젝트이며, *The Coffin of Andy and Leyley*의 개발자 또는 배급사와 제휴하거나 공식적으로 지원받지 않습니다.

이 소프트웨어는 개인적인 연구 및 사용자 번역 작업을 위한 것입니다. 추출된 게임 에셋과 번역 데이터의 지적 재산권은 각 소유자에게 있습니다.

사용자는 자신의 사용 방식이 관련 법률 및 약관을 준수하는지 확인해야 합니다.

공식 번역 도구의 사용자 계약에 따라 이 도구를 사용하세요.

## 라이선스

이 프로젝트는 GNU General Public License v3.0(GPL-3.0)을 따릅니다.

자세한 라이선스 내용은 [LICENSE](LICENSE)를 참고하세요.

---

TCOAAL CLD Tools — CLD 파일 추출, 편집, 리패킹 및 비교.
