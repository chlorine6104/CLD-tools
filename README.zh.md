# CLD-tools

一个基于 Perl 的工具，用于提取、检查和修改《The Coffin of Andy and Leyley (TCOAAL)》使用的 CLD（Coffin Language Data）文件。

CLD-tools 允许用户解包并检查游戏官方支持的用户翻译文件。它可以提取内嵌图像、字体和翻译数据，并提供重新打包工具，以便将修改应用到 CLD 文件中。

## 功能特性

- **CLD 提取：** 读取 CLD 文件并提取其中的数据。
- **图像提取：** 解码并提取 Base64 编码的图像数据。
- **字体提取：** 提取内嵌字体，并使用指定的字体名称作为输出文件名。
- **CSV 导出：** 将翻译数据和其他数据导出为 UTF-8 编码的 CSV 文件，同时保留层级键结构。
- **CLD 重新打包：** 将修改应用于翻译数据、图像和字体。

## 关于重新打包工具

CLD-tools 包含一个独立的重新打包工具，允许用户修改提取出的 CLD 数据，并将其重新构建为 CLD 文件。

该工具旨在无需依赖官方构建工具即可重新构建修改后的翻译数据和资源。

在寻求与官方构建工具兼容的过程中，该重新打包工具将作为临时解决方案使用。

一旦实现与官方构建工具的兼容，独立的重新打包工具将停止维护并从项目中移除。

## 环境要求

- Perl 5
- JSON::PP
- MIME::Base64
- Encode
- Text::CSV
- File::Path
- File::Basename
- File::Find

## 提取器用法

    perl extract_cld.pl input.cld [output_folder]

如果未指定输出目录，则使用当前工作目录。

### 提取结果

    output_folder/
    ├── output.csv
    ├── font.ttf
    └── imgFiles/
        └── extracted images...

实际输出结构取决于输入 CLD 文件的内容。

## 重新打包工具用法

    perl cld_repack.pl input.cld output.cld [output.csv] [image_folder] [font_file]

### 参数说明

| 参数 | 说明 | 默认值 |
|---|---|---|
| input.cld | 原始 CLD 文件 | 必填 |
| output.cld | 输出 CLD 文件 | 必填 |
| output.csv | 修改后的 CSV 文件 | output.csv |
| image_folder | 存放修改后图像的目录 | ./img |
| font_file | 要应用的字体文件 | 未指定时保持不变 |

### 使用示例

**修改翻译数据**

    perl cld_repack.pl original.cld modified.cld output.csv

**修改图像**

    perl cld_repack.pl original.cld modified.cld output.csv ./img

**修改字体**

    perl cld_repack.pl original.cld modified.cld output.csv ./img ./font.ttf

## 重新打包过程

- CSV 数据通过 section、key 和 value 列进行匹配。
- 图像文件会被编码为 Base64，并应用到对应的现有条目。
- 如果未指定图像目录，则默认使用 ./img。
- 如果图像目录不存在，则跳过图像修改并保留原始图像数据。
- 如果某个图像文件缺失，或者找不到对应条目，则跳过该条目并保留原始数据。
- 字体文件会被编码为 Base64，同时更新 fontFile 和 fontFace 两个字段。
- 如果未指定字体文件，则保留原始字体数据。
- 缺失或无法匹配的 CSV 条目将被跳过，并保留原始数据。
- 原始 CLD 文件绝不会被覆盖。所有修改都会保存到指定的输出文件中。

**注意：** 重新打包工具目前仍处于实验阶段。请务必保留原始文件的备份。

## TODO

- [ ] 实现与官方构建工具的兼容。
- [ ] 提高重新打包工具的稳定性和兼容性。
- [ ] 改进错误处理和诊断信息。
- [ ] 支持更多 CLD 数据结构。
- [ ] 提高整体易用性。

## 参与贡献

欢迎大家参与贡献！

我们欢迎错误修复、功能改进以及其他形式的贡献。

1. Fork 此仓库。
2. 创建一个新分支。
3. 进行修改并测试。
4. 提交 Commit。
5. 提交 Pull Request。

所有 Pull Request 在合并前都需要经过审核。

**注意：由于个人事务和日程繁忙，我可能无法定期查看 Issues 和 Pull Requests。因此，回复和审核可能会有所延迟。感谢大家的理解与耐心！**

## 免责声明

CLD-tools 是一个独立项目，与 TCOAAL 的开发者或发行商没有任何关联，也未获得其认可或官方支持。

本软件仅用于个人研究和合法的用户翻译工作。

请勿将本软件用于抄袭、未经授权的复制、再分发或侵犯版权的行为。

所有提取的游戏资源和翻译数据均为其各自所有者的知识产权。

用户有责任确保自己的使用行为符合所在司法管辖区适用的法律、许可证和服务条款。

在适用法律允许的范围内，作者不对因滥用本软件而造成的损害、数据丢失或法律后果承担责任。

请负责任地使用本软件，并自行承担使用风险。请始终遵守适用法律。

## 许可证

本项目采用 GNU General Public License v3.0 (GPL-3.0) 许可证。

完整许可证文本请参阅 LICENSE 文件。

---

CLD-tools — 检查、提取和修改 Coffin Language Data。
