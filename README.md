# CLD-tools


[Русский](README.ru.md) |
[简体中文](README.zh.md) |
[Español](README.es.md) |
[한국어](README.ko.md)

A Perl-based utility for extracting, inspecting, and modifying CLD (Coffin Language Data) files used by *The Coffin of Andy and Leyley (TCOAAL)*.

CLD-tools allows users to unpack and examine the game's officially supported user translation files. It can extract embedded images, fonts, and translation data, and includes a repacker for applying modifications back to CLD files.

## Features

- **CLD Extraction:** Reads CLD files and extracts their internal data.
- **Image Extraction:** Decodes and extracts Base64-encoded image data.
- **Font Extraction:** Extracts embedded fonts and uses the specified font face as the output filename.
- **CSV Export:** Exports translation and other data into UTF-8 CSV files while preserving hierarchical keys.
- **CLD Repacking:** Applies modifications to translation data, images, and fonts.

## About the Repacker

CLD-tools includes an independent repacker that allows users to modify extracted CLD data and rebuild it into a CLD file.

The repacker was developed to provide a way to rebuild modified translation data and resources without relying on the official build tool.

The repacker is intended as a temporary solution while compatibility with the official build tool is being pursued.

Once compatibility with the official build tool has been established, the standalone repacker will be discontinued and removed from the project.

## Requirements

- Perl 5
- JSON::PP
- MIME::Base64
- Encode
- Text::CSV
- File::Path
- File::Basename
- File::Find

## Extractor Usage

    perl extract_cld.pl input.cld [output_folder]

If the output directory is omitted, the current working directory is used.

### Extractor Output

    output_folder/
    ├── output.csv
    ├── font.ttf
    └── imgFiles/
        └── directory
            └──extracted images...

The actual output structure depends on the contents of the input CLD file.

## Repacker Usage

    perl cld_repack.pl input.cld output.cld [output.csv] [image_folder] [font_file]

### Arguments

| Argument | Description | Default |
|---|---|---|
| input.cld | Original CLD file | Required |
| output.cld | Output CLD file | Required |
| output.csv | Modified CSV file | output.csv |
| image_folder | Directory containing modified images | ./img |
| font_file | Font file to apply | Unchanged if omitted |

### Examples

**Modify translation data**

    perl cld_repack.pl original.cld modified.cld output.csv

**Modify images**

    perl cld_repack.pl original.cld modified.cld output.csv ./img

**Modify fonts**

    perl cld_repack.pl original.cld modified.cld output.csv ./img ./font.ttf

## Repacking Process

- CSV values are matched using the section, key, and value columns.
- Image files are Base64-encoded and applied to their corresponding existing entries.
- If the image folder argument is omitted, ./img is used by default.
- If the image folder does not exist, image modifications are skipped and the original image data is preserved.
- If an individual image file is missing or its corresponding entry cannot be found, that entry is skipped and its original data is preserved.
- Font files are Base64-encoded, updating both fontFile and fontFace.
- If no font file is specified, the original font data is preserved.
- Missing or unmatched CSV entries are skipped while preserving the original data.
- The original CLD file is never overwritten. All changes are saved to the specified output file.

**Note:** The repacker is experimental. Always keep backups of your original files.

## TODO

- [ ] Establish compatibility with the official build tool.
- [ ] Improve repacker stability and compatibility.
- [ ] Improve error handling and diagnostic messages.
- [ ] Support additional CLD data structures.
- [ ] Improve overall usability.

## Contributing

Contributions are welcome!

Bug fixes, feature improvements, and other contributions are appreciated.

1. Fork this repository.
2. Create a new branch.
3. Make your changes and test them.
4. Commit your changes.
5. Submit a Pull Request.

All Pull Requests are subject to review before being merged.

**Note: Due to personal commitments and a busy schedule, I may not be able to regularly check Issues and Pull Requests. Responses and reviews may therefore be delayed. Thank you for your understanding and patience!**

## Disclaimer

CLD-tools is an independent project and is not affiliated with, endorsed by, or officially supported by the developers or publishers of TCOAAL.

This software is intended for personal research and legitimate user translation workflows.

Do not use this software for plagiarism, unauthorized copying, redistribution, or copyright infringement.

All extracted game assets and translation data remain the intellectual property of their respective owners.

Users are solely responsible for ensuring that their use complies with applicable laws, licenses, and terms of service in their jurisdiction.

The author assumes no responsibility for damages, data loss, or legal consequences resulting from misuse of this software, to the extent permitted by applicable law.

Use responsibly and at your own risk. Only use this software within the limits of the laws applicable to you.

## License

This project is licensed under the GNU General Public License v3.0 (GPL-3.0).

See LICENSE for the full license text.

---

CLD-tools — Inspect, extract, and modify Coffin Language Data.
