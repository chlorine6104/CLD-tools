# CLD-tools


[Русский](README.ru.md) | [简体中文](README.zh.md) | [Español](README.es.md) | [한국어](README.ko.md)

A collection of Perl tools for extracting, editing, repacking, and comparing CLD (Coffin Language Data) files used by _The Coffin of Andy and Leyley_ (TCOAAL).

TCOAAL CLD Tools allows users to inspect and modify the game's user translation files. It includes tools for extracting dialogue, images, and fonts, rebuilding CLD files, and comparing changes between files.

## Features

- **CLD Extraction:** Extracts dialogue and resources from CLD files.
- **CSV Export:** Exports translation data into UTF-8 CSV files.
- **Template Support:** Uses the game's original `dialogue.csv` as a template.
- **Image Extraction:** Extracts embedded images.
- **Font Extraction:** Extracts embedded font files.
- **CLD Repacking:** Applies translation and resource changes to CLD files.
- **CLD Comparison:** Compares two CLD files and reports their differences.

## Requirements

- Perl 5
- Text::CSV (required by `cld_extract.pl`)

Other required modules are included with standard Perl distributions.

## Extractor Usage

    perl cld_extract.pl [--template dialogue.csv] <input.cld> [output_folder]

The output folder defaults to the current working directory.

### Using `--template`

To use the `--template` option, you must first generate the original `dialogue.csv` yourself using the game's `translator.exe`.

Then, pass the generated CSV file to `cld_extract.pl` with `--template`.

    perl cld_extract.pl --template dialogue.csv input.cld output_folder

The template's layout, entry order, speaker names, and English text are preserved. Translation data is filled in by ID.

### Extractor Output

    output_folder/
    ├── dialogue.csv
    ├── img/
    └── font/

The actual contents depend on the input CLD file.

Without `--template`, the extractor generates a basic CSV file with an empty English column. This format can still be used with `cld_repack.pl`.

## Repacker Usage

    perl cld_repack.pl [options] <input.cld> <output.cld> [dialogue.csv] [image_folder] [font_file]

The input and output paths must end in `.cld`. The output path must differ from the input path.

### Arguments

| Argument | Description | Default |
|---|---|---|
| input.cld | Original CLD file | Required |
| output.cld | Output CLD file | Required |
| dialogue.csv | CSV containing translation data | Unchanged if omitted |
| image_folder | Folder containing modified PNG images | `./img` |
| font_file | Font file to insert | Unchanged if omitted |

### Options

| Option | Description |
|---|---|
| `--no-images` | Removes all embedded image entries. |
| `--no-font` | Removes the embedded font and resets the font face to `GameFont`. |
| `--font-face NAME` | Sets the font face name. |

### Examples

**Modify translation data**

    perl cld_repack.pl original.cld modified.cld dialogue.csv

**Modify images**

    perl cld_repack.pl original.cld modified.cld dialogue.csv ./img

**Modify fonts**

    perl cld_repack.pl original.cld modified.cld dialogue.csv ./img ./font.ttf

**Remove embedded images**

    perl cld_repack.pl --no-images original.cld modified.cld

**Remove the embedded font**

    perl cld_repack.pl --no-font original.cld modified.cld

### Repacking Notes

- Empty translation cells preserve the original text.
- CSV entries are matched by ID.
- Consecutive rows with the same ID represent multiple lines.
- New IDs are not added to the CLD file.
- Missing CSV entries preserve the original data.
- Only existing image entries can be replaced.
- Images must be PNG files with valid PNG signatures.
- If `./img` does not exist, original images are preserved.
- If no font file is specified, the original font is preserved.
- If exactly one supported font is found in `./font`, it is selected automatically.
- The original CLD file is never overwritten.

## Diff Tool Usage

    perl cld_diff.pl <file_A.cld> <file_B.cld>

Compares two CLD files and reports:

- Modified entries.
- Entries found only in file A.
- Entries found only in file B.

Object key order and JSON whitespace are ignored. Array order is preserved.

Image and font data are summarized by their encoded lengths instead of displaying the full data.

For a byte-level comparison, use:

    cmp file_A.cld file_B.cld

On Windows:

    fc /b file_A.cld file_B.cld

## Contributing

Contributions are welcome!

1. Fork this repository.
2. Create a new branch.
3. Make your changes and test them.
4. Commit your changes.
5. Submit a Pull Request.

Responses to Issues and Pull Requests may be delayed due to personal commitments.

## Disclaimer

TCOAAL CLD Tools is an independent project and is not affiliated with, endorsed by, or officially supported by the developers or publishers of *The Coffin of Andy and Leyley*.

This software is intended for personal research and user translation workflows. All extracted game assets and translation data remain the intellectual property of their respective owners.

Users are responsible for ensuring that their use complies with applicable laws and agreements.

Use these tools in accordance with the official translation tool's user agreement.

## License

This project is licensed under the GNU General Public License v3.0 (GPL-3.0).

See [LICENSE](LICENSE) for the full license text.

---

TCOAAL CLD Tools — Extract, edit, repack, and compare CLD files.
