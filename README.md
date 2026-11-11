# CLD-tools

[Русский](README.ru.md) | [简体中文](README.zh.md) | [Español](README.es.md) | [한국어](README.ko.md)

A toolkit for extracting, editing, repacking, and comparing CLD (Coffin Language Data) files used by _The Coffin of Andy and Leyley_ (TCOAAL).

It ships as a ready-to-run desktop app with a GUI and a command-line interface for Windows, Linux, and macOS. No Perl installation is needed. The underlying Perl scripts are also available for use directly.

## Features

- **CLD Extraction:** Extracts dialogue and resources from CLD files.
- **CSV Export:** Exports translation data into UTF-8 CSV files.
- **Template Support:** Uses the game's original `dialogue.csv` as a template.
- **Image Extraction:** Extracts embedded images.
- **Font Extraction:** Extracts embedded font files.
- **CLD Repacking:** Applies translation and resource changes to CLD files.
- **CLD Comparison:** Compares two CLD files and reports their differences (Perl script only).
- **GUI and CLI:** Run without arguments for the GUI, or pass a command for the CLI.

## Download

Get the build for your system from the [Releases](../../releases) page.

| Platform | File | Notes |
|---|---|---|
| Windows (x64) | `CLD-Tool-windows-x64.exe` | GUI |
| Windows (x64) | `CLD-Tool-cli-windows-x64.exe` | Command line. Keep `-cli` in the file name. |
| Linux (x64) | `CLD-Tool-linux-x64.tar.gz` | GUI and CLI in one executable |
| macOS (Apple Silicon) | `CLD-Tool-macos-arm64.zip` | GUI and CLI in one app bundle |
| macOS (Intel) | `CLD-Tool-macos-x64.zip` | GUI and CLI in one app bundle |

Each build bundles everything it needs. The first launch may take a few seconds longer while the bundled tools unpack.

**Linux:** extract with `tar -xzf CLD-Tool-linux-x64.tar.gz`, then run `./CLD-Tool`. A desktop environment with Tk support is required for the GUI.

**macOS:** the app is not notarized. If macOS blocks it on first launch, remove the quarantine flag:

    xattr -dr com.apple.quarantine CLD-Tool.app

## GUI

Run the app without arguments (double-click it on Windows and macOS, or run `./CLD-Tool` on Linux).

- **Extract tab:** choose a CLD file, optionally a template CSV and an output folder.
- **Repack tab:** choose the source CLD and the output CLD, plus an optional CSV, image folder, and font file. The switches remove images or the embedded font, and the field next to them sets the font face.

The window follows your system's light or dark theme. Progress and warnings appear in the log panel.

## Command Line

    CLD-Tool extract [-t dialogue.csv] <input.cld> [output_folder]
    CLD-Tool repack [options] <input.cld> <output.cld>
    CLD-Tool gui
    CLD-Tool --help

On Windows use `CLD-Tool-cli` (the console build). On macOS the executable is inside the app bundle:

    CLD-Tool.app/Contents/MacOS/CLD-Tool extract input.cld output_folder

Running the Linux or macOS executable with no arguments opens the GUI. The Windows `-cli` build prints the help text instead.

### Extract

    CLD-Tool extract [--template dialogue.csv] <input.cld> [output_folder]

The output folder defaults to a folder next to the input file, named after it.

To use `--template`, first generate the original `dialogue.csv` yourself using the game's `translator.exe`, then pass it in:

    CLD-Tool extract --template dialogue.csv input.cld output_folder

The template's layout, entry order, speaker names, and English text are preserved. Translation data is filled in by ID.

Output:

    output_folder/
    ├── dialogue.csv
    ├── img/
    └── font/

The actual contents depend on the input CLD file.

Without `--template`, a basic CSV with an empty English column is generated. This format can still be used for repacking.

### Repack

    CLD-Tool repack [options] <input.cld> <output.cld>

| Option | Description |
|---|---|
| `--csv FILE` | CSV containing translation data. Unchanged if omitted. |
| `--images FOLDER` | Folder containing modified PNG images. Unchanged if omitted. |
| `--font FILE` | Font file to insert. Unchanged if omitted. |
| `--no-images` | Removes all embedded image entries. Cannot be combined with `--images`. |
| `--no-font` | Removes the embedded font and resets the font face to `GameFont`. Cannot be combined with `--font`. |
| `--font-face NAME` | Sets the font face name. `GameFont` is reserved. |

The input and output paths must end in `.cld`, and the output path must differ from the input path.

**Examples**

Modify translation data:

    CLD-Tool repack original.cld modified.cld --csv dialogue.csv

Modify images and fonts:

    CLD-Tool repack original.cld modified.cld --csv dialogue.csv --images ./img --font ./font.ttf

Remove embedded images or the embedded font:

    CLD-Tool repack original.cld modified.cld --no-images
    CLD-Tool repack original.cld modified.cld --no-font

Exit codes: `0` on success, `2` for invalid arguments, otherwise the exit code of the underlying tool.

### Repacking Notes

- Empty translation cells preserve the original text.
- CSV entries are matched by ID.
- Consecutive rows with the same ID represent multiple lines.
- New IDs are not added to the CLD file.
- Missing CSV entries preserve the original data.
- Only existing image entries can be replaced.
- Images must be PNG files with valid PNG signatures.
- The original CLD file is never overwritten.
- The GUI and CLI never pick up `./img` or `./font` automatically. Pass the image folder and font file explicitly. Only the standalone Perl scripts do this (see below).

## Perl Scripts

The scripts in this repository are the original implementation, and the app runs bundled, self-contained builds of them. You can still run them directly if you prefer.

**Requirements:** Perl 5 and `Text::CSV` (required by `cld_extract.pl`). Other required modules are included with standard Perl distributions.

    perl cld_extract.pl [--template dialogue.csv] <input.cld> [output_folder]
    perl cld_repack.pl [options] <input.cld> <output.cld> [dialogue.csv] [image_folder] [font_file]

When run directly, the repacker also:

- uses `./img` as the default image folder (original images are preserved if it does not exist), and
- selects the font automatically if exactly one supported font is found in `./font`.

The output folder of the extractor defaults to the current working directory.

### Diff Tool

    perl cld_diff.pl <file_A.cld> <file_B.cld>

Compares two CLD files and reports modified entries, entries found only in file A, and entries found only in file B. Object key order and JSON whitespace are ignored. Array order is preserved. Image and font data are summarized by their encoded lengths instead of displaying the full data.

This tool is not included in the app and requires Perl. For a byte-level comparison, use `cmp file_A.cld file_B.cld` (on Windows: `fc /b file_A.cld file_B.cld`).

## Building from Source

Releases are built by GitHub Actions on Windows, Linux, and macOS:

1. The Perl scripts are packaged into standalone executables with [PAR::Packer](https://metacpan.org/pod/PAR::Packer).
2. [PyInstaller](https://pyinstaller.org) bundles those executables with `main.py` into the final app.

To run the app from source you need Python 3.13 and `customtkinter`:

    pip install customtkinter
    python main.py

Without bundled tools, the app falls back to a Perl found on your `PATH` and the `.pl` files next to `main.py`.

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

The released binaries also contain third-party components (Perl and its modules, Python, customtkinter, PyInstaller) under their own licenses. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

---

TCOAAL CLD Tools — Extract, edit, repack, and compare CLD files.
