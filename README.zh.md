# CLD-tools

[English](README.md) | [Русский](README.ru.md) | [Español](README.es.md) | [한국어](README.ko.md)

一套用于提取、编辑、重新打包和比较 *The Coffin of Andy and Leyley* (TCOAAL) 所使用的 CLD（Coffin Language Data）文件的 Perl 工具。

TCOAAL CLD Tools 可用于查看和修改游戏的用户翻译文件，支持提取对话、图片和字体，重新生成 CLD 文件，以及比较不同文件之间的改动。

## 功能

- **CLD 提取：** 从 CLD 文件中提取对话和资源。
- **CSV 导出：** 将翻译数据导出为 UTF-8 CSV 文件。
- **模板支持：** 使用游戏原版 `dialogue.csv` 作为模板。
- **图片提取：** 提取内嵌图片。
- **字体提取：** 提取内嵌字体文件。
- **CLD 重新打包：** 将翻译和资源修改应用到 CLD 文件。
- **CLD 比较：** 比较两个 CLD 文件并显示差异。

## 环境要求

- Perl 5
- Text::CSV（`cld_extract.pl` 所需）

其他所需模块已包含在标准 Perl 发行版中。

## 提取器用法

    perl cld_extract.pl [--template dialogue.csv] <input.cld> [output_folder]

如果未指定输出文件夹，则使用当前工作目录。

### 使用 `--template`

使用 `--template` 选项前，必须先通过游戏自带的 `translator.exe` 手动生成原版 `dialogue.csv`。

然后使用 `--template` 将生成的 CSV 文件传递给 `cld_extract.pl`。

    perl cld_extract.pl --template dialogue.csv input.cld output_folder

模板的布局、条目顺序、说话者名称和英文文本都会保留。翻译内容会根据 ID 填入。

### 提取结果

    output_folder/
    ├── dialogue.csv
    ├── img/
    └── font/

实际生成的内容取决于输入的 CLD 文件。

不使用 `--template` 时，提取器会生成一个英文列为空的基础 CSV 文件。该格式同样可以用于 `cld_repack.pl`。

## 重新打包用法

    perl cld_repack.pl [options] <input.cld> <output.cld> [dialogue.csv] [image_folder] [font_file]

输入和输出路径必须以 `.cld` 结尾。输出路径必须与输入路径不同。

### 参数

| 参数 | 说明 | 默认值 |
|---|---|---|
| input.cld | 原始 CLD 文件 | 必填 |
| output.cld | 输出 CLD 文件 | 必填 |
| dialogue.csv | 包含翻译数据的 CSV 文件 | 不指定则保留原数据 |
| image_folder | 存放修改后 PNG 图片的文件夹 | `./img` |
| font_file | 要添加的字体文件 | 不指定则保留原字体 |

### 选项

| 选项 | 说明 |
|---|---|
| `--no-images` | 删除所有内嵌图片条目。 |
| `--no-font` | 删除内嵌字体，并将字体名称重置为 `GameFont`。 |
| `--font-face NAME` | 设置字体名称。 |

### 示例

**修改翻译数据**

    perl cld_repack.pl original.cld modified.cld dialogue.csv

**修改图片**

    perl cld_repack.pl original.cld modified.cld dialogue.csv ./img

**修改字体**

    perl cld_repack.pl original.cld modified.cld dialogue.csv ./img ./font.ttf

**删除内嵌图片**

    perl cld_repack.pl --no-images original.cld modified.cld

**删除内嵌字体**

    perl cld_repack.pl --no-font original.cld modified.cld

### 重新打包说明

- 翻译单元格为空时，保留原始文本。
- CSV 条目根据 ID 匹配。
- 连续出现的相同 ID 行表示多行文本。
- 不会向 CLD 文件添加新的 ID。
- CSV 中缺失的条目会保留原始数据。
- 只能替换已有的图片条目。
- 图片必须是具有有效 PNG 签名的 PNG 文件。
- 如果 `./img` 文件夹不存在，则保留原始图片。
- 如果未指定字体文件，则保留原始字体。
- 如果 `./font` 中只找到一个受支持的字体文件，则会自动选择该文件。
- 不会覆盖原始 CLD 文件。

## Diff 工具用法

    perl cld_diff.pl <file_A.cld> <file_B.cld>

比较两个 CLD 文件，并显示：

- 已修改的条目。
- 仅存在于文件 A 中的条目。
- 仅存在于文件 B 中的条目。

比较时会忽略 JSON 对象键的顺序和空白字符，但会保留数组顺序。

图片和字体数据只显示编码后的数据长度，不会输出完整内容。

如需进行字节级比较，请使用：

    cmp file_A.cld file_B.cld

Windows 下使用：

    fc /b file_A.cld file_B.cld

## 参与贡献

欢迎参与项目贡献！

1. Fork 此仓库。
2. 创建新分支。
3. 修改并测试代码。
4. 提交 Commit。
5. 提交 Pull Request。

由于个人事务，Issues 和 Pull Requests 的回复可能会有所延迟。

## 免责声明

TCOAAL CLD Tools 是一个独立项目，与 *The Coffin of Andy and Leyley* 的开发者或发行商无关，也未获得其认可或官方支持。

本软件用于个人研究和用户翻译工作。所有提取的游戏资源和翻译数据均归其各自所有者所有。

用户有责任确保自己的使用方式符合适用法律及相关协议。

请按照官方翻译工具的用户协议使用这些工具。

## 许可证

本项目采用 GNU General Public License v3.0（GPL-3.0）许可证。

完整许可证文本请参阅 [LICENSE](LICENSE)。

---

TCOAAL CLD Tools — 提取、编辑、重新打包和比较 CLD 文件。
