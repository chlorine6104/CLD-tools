#!/usr/bin/env perl
# Usage:
#   perl cld_repack.pl [options] input.cld output.cld [output.csv] [image_folder] [font_file]
#
# Options:
#   --no-images       empty imgFiles ("imgFiles": {})
#   --no-font         remove the embedded font ("fontFile": null) and use fontFace GameFont
#   --font-face NAME  override fontFace; with --no-font, use NAME instead of GameFont
#                     (GameFont is reserved and cannot be passed explicitly)
#
# Only existing entries are replaced in place; missing entries are skipped.
# Only PNG image files with a valid PNG signature are accepted.
use strict;
use warnings;

use Encode qw(decode encode);
use JSON::PP;
use MIME::Base64 qw(encode_base64);
use Text::CSV;
use File::Find;
use Getopt::Long;

my ($no_images, $no_font, $font_face_opt) = (0, 0, undef);
GetOptions(
    'no-images'   => \$no_images,
    'no-font'     => \$no_font,
    'font-face=s' => \$font_face_opt,
) or exit 1;

my ($input, $output, $csv_file, $img_dir, $font_file) = @ARGV;

die "Usage: perl cld_repack.pl [--no-images] [--no-font] [--font-face NAME] "
  . "SOURCE_CLD OUTPUT_CLD [dialogue.csv] [image_folder] [font_file]\n"
    unless defined $input && defined $output;

die "Input file must have a .cld extension: $input\n"
    unless $input =~ /\.cld\z/i;

die "Output file must have a .cld extension: $output\n"
    unless $output =~ /\.cld\z/i;
    
die "--no-font cannot be combined with a font file argument.\n" if $no_font && defined $font_file;
die "The output file must be different from the input file.\n"
    if $input eq $output;
if (defined $font_face_opt) {
    die "--font-face requires a non-empty font name.\n" unless $font_face_opt =~ /\S/;
    die "GameFont is reserved; omit --font-face to use the --no-font default.\n"
        if $font_face_opt =~ /\A\s*GameFont\s*\z/i;
}

# CSV is optional. When omitted, no default output.csv is read or modified.
$img_dir //= './img';

# No font argument: use the single font file in ./font (skipped with --no-font)
if (!defined $font_file && !$no_font && -d './font') {
    my @fonts = grep { -f } glob('./font/*.{ttf,otf,woff,woff2,svg,eot}');
    if    (@fonts == 1) { $font_file = $fonts[0] }
    elsif (@fonts  > 1) { warn "Multiple fonts in ./font; specify one explicitly: @fonts\n" }
}

# ASCII-only output (\uXXXX escapes) like the original file; no double UTF-8 encoding.
my $ENC = JSON::PP->new->ascii->allow_nonref;
my $DEC = JSON::PP->new->allow_nonref;

open my $in, '<:raw', $input
    or die "Failed to open input file ($input): $!\n";
my $bytes = do { local $/; <$in> };
close $in;

my $text = decode('UTF-8', $bytes);
$text =~ s/\ALANGDATA\s*//
    or die "The input file does not have the LANGDATA prefix.\n";

# ==================================================
# JSON parser that records the text position of every value
# ==================================================

my $pos    = 0;
my $length = length($text);

sub skip_ws {
    pos($text) = $pos;
    $text =~ /\G\s*/gc;
    $pos = pos($text);
}

sub parse_string {                         # returns the raw JSON string, quotes included
    pos($text) = $pos;
    $text =~ /\G"[^"\\]*+(?:\\.[^"\\]*+)*+"/gcs
        or die "Expected a JSON string (at position $pos).\n";
    my $raw = substr($text, $pos, pos($text) - $pos);
    $pos = pos($text);
    return $raw;
}

sub parse_value {
    skip_ws();

    my $start = $pos;
    my $char  = substr($text, $pos, 1);

    if ($char eq '{') {
        $pos++;
        my %children;

        skip_ws();
        if (substr($text, $pos, 1) eq '}') {
            $pos++;
        } else {
            while (1) {
                skip_ws();
                my $key = $DEC->decode(parse_string());

                skip_ws();
                die "Expected a colon in the JSON object (at position $pos).\n"
                    unless substr($text, $pos++, 1) eq ':';

                $children{$key} = parse_value();

                skip_ws();
                my $next = substr($text, $pos++, 1);
                last if $next eq '}';
                die "Expected a comma in the JSON object (at position $pos).\n"
                    unless $next eq ',';
            }
        }
        return { type => 'object', start => $start, end => $pos, children => \%children };
    }

    if ($char eq '[') {
        $pos++;
        my @children;

        skip_ws();
        if (substr($text, $pos, 1) eq ']') {
            $pos++;
        } else {
            while (1) {
                push @children, parse_value();

                skip_ws();
                my $next = substr($text, $pos++, 1);
                last if $next eq ']';
                die "Expected a comma in the JSON array (at position $pos).\n"
                    unless $next eq ',';
            }
        }
        return { type => 'array', start => $start, end => $pos, children => \@children };
    }

    if ($char eq '"') {
        parse_string();
        return { type => 'scalar', start => $start, end => $pos };
    }

    # Numbers, true, false, null
    pos($text) = $pos;
    $text =~ /\G[^\s,\]}]+/gc
        or die "Could not read a JSON value (at position $start).\n";
    $pos = pos($text);
    return { type => 'scalar', start => $start, end => $pos };
}

my $root = parse_value();
die "The top-level JSON value is not an object.\n" unless $root->{type} eq 'object';
skip_ws();
die "Unexpected content after the JSON value.\n" if $pos != $length;

# ==================================================
# Patch bookkeeping
# ==================================================

my %patch;          # start position => { start, end, text, label }
my %stats;

sub node_raw   { my ($n) = @_; substr($text, $n->{start}, $n->{end} - $n->{start}) }
sub node_value { my ($n) = @_; $DEC->decode(node_raw($n)) }

sub add_patch {
    my ($node, $replacement, $label) = @_;
    $patch{ $node->{start} } = {
        start => $node->{start}, end => $node->{end},
        text  => $replacement,   label => $label,
    };
}

# ==================================================
# CSV (dialogue.csv layout) -> patches
# ==================================================

my %KIND = (sysLabel => 'str', sysMenus => 'str', labelLUT => 'str', linesLUT => 'lines');

sub placeholder {
    my ($v) = @_;
    return 1 if $v =~ /\A(?:translated text|Detected (?:Language|Font File|font size)|name(?:\(probably can be omitted\))?)\z/;
    return 0;
}

sub set_top_field {                        # langName, fontFace, fontSize, langInfo
    my ($name, $value, $json_text, $same) = @_;
    my $node = $root->{children}{$name};
    if ($node) {
        if ($same->(node_value($node))) { $stats{unchanged}++; return }
        add_patch($node, $json_text, "field $name");
        $stats{fields}++;
    }
    else {
        $stats{missing_fields}{$name}++;
    }
}

sub apply_entry {
    my ($table, $key, $value) = @_;

    my $container = $root->{children}{$table};
    my $node = ($container && $container->{type} eq 'object') ? $container->{children}{$key} : undef;

    my $as_lines = $KIND{$table} eq 'lines';
    my @lines    = $as_lines ? @$value : ();          # one CSV row = one line

    if ($node) {
        my $old = node_value($node);
        my ($json_text, $same);

        if ($node->{type} eq 'array') {
            my @new = $as_lines ? @lines : ($value);
            $json_text = $ENC->encode([ @new ]);
            $same = ref($old) eq 'ARRAY' && @$old == @new
                 && join("\x1f", @$old) eq join("\x1f", @new);
        } else {
            my $str = $as_lines ? join("\n", @lines) : $value;
            $json_text = $ENC->encode("$str");
            $same = !ref($old) && defined $old && "$old" eq $str;
        }

        if ($same) { $stats{unchanged}++; return }
        add_patch($node, $json_text, "$table.$key");
        $stats{replaced}++;
        return;
    }

    $stats{missing}++;
    push @{ $stats{missing_examples} }, "$table.$key"
        if !$stats{missing_examples} || @{ $stats{missing_examples} } < 5;
}

if (defined $csv_file && length $csv_file && -f $csv_file) {
    my $csv = Text::CSV->new({ binary => 1, auto_diag => 1 });
    open my $cfh, '<:encoding(UTF-8)', $csv_file
        or die "Failed to open CSV file ($csv_file): $!\n";

    my $trim = sub { my ($x) = @_; $x = '' unless defined $x; $x =~ s/\A\s+|\s+\z//g; $x };

    # Where does an ID live?  linesLUT first, then labelLUT (CHOICE rows etc.), else the section default.
    my $resolve = sub {
        my ($key, $default) = @_;
        for my $t (qw(linesLUT labelLUT)) {
            my $c = $root->{children}{$t};
            return $t if $c && $c->{type} eq 'object' && $c->{children}{$key};
        }
        return $default;
    };

    # Consecutive rows with the same ID are the lines of ONE entry.
    my ($pt, $pk, @pv);
    my $flush = sub {
        if (defined $pk) {
            my @l = map { placeholder($_) ? '' : $_ } @pv;
            pop @l while @l && $l[-1] eq '';            # trailing blank Translation rows are not lines
            if (@l) {
                if ($KIND{$pt} eq 'lines') { apply_entry($pt, $pk, \@l) }
                else                       { apply_entry($pt, $pk, join("\n", @l)) }
            }
        }
        ($pt, $pk, @pv) = ();
    };

    # Rows are recognised by their HEADER row (a row containing "Translation"), not by blank rows or
    # "Section" markers, so unknown section layouts (e.g. Map*.json) are handled as well.
    my ($expect, $first, $hdr, $dlg_default) = ('', 1, undef, 'linesLUT');

    while (my $r = $csv->getline($cfh)) {
        my @r = map { defined $_ ? $_ : '' } @$r;
        $r[0] =~ s/\A\x{FEFF}// if $first;
        $first = 0;

        unless (grep { length } @r) {                 # blank row
            $flush->();
            ($expect, $hdr) = ('', undef);
            next;
        }

        my ($c0, $c1) = ($trim->($r[0]), $trim->($r[1]));

        if ($expect eq 'info1') {                     # value row: Language / Font File / Font Size
            my ($lang, $face, $size) = @r[0, 1, 2];
            if (length $lang && !placeholder($lang)) {
                set_top_field('langName', $lang, $ENC->encode("$lang"), sub { !ref($_[0]) && "$_[0]" eq $lang });
            }
            if (length $face && !placeholder($face)) {
                set_top_field('fontFace', $face, $ENC->encode("$face"), sub { !ref($_[0]) && "$_[0]" eq $face });
            }
            if ($size =~ /\A\d+\z/) {
                set_top_field('fontSize', $size, 0 + $size, sub { !ref($_[0]) && "$_[0]" eq "$size" });
            }
            $expect = '';
            next;
        }
        if ($expect eq 'info2') {                     # value row: credits
            my @c = map { placeholder($_) ? '' : $_ } @r[0 .. 2];
            if (grep { length } @c) {
                set_top_field('langInfo', \@c, $ENC->encode([ map { "$_" } @c ]),
                    sub { ref($_[0]) eq 'ARRAY' && join("\x1f", @{ $_[0] }) eq join("\x1f", @c) });
            }
            $expect = '';
            next;
        }
        if ($c0 eq 'Language' && $c1 eq 'Font File') { $flush->(); ($expect, $hdr) = ('info1', undef); next }
        if ($c0 eq 'Credit 1')                       { $flush->(); ($expect, $hdr) = ('info2', undef); next }
        if ($c0 eq 'Section') {                       # "Section,<name>": a plain-mode name picks the default table
            $flush->();
            $hdr = undef;
            $dlg_default = $c1 eq 'labelLUT' ? 'labelLUT' : 'linesLUT';
            next;
        }

        # Header row: has a "Translation" cell and an "English" cell (or is the Menus / ID header)
        my ($ti) = grep { $trim->($r[$_]) eq 'Translation' } 0 .. $#r;
        my ($ei) = grep { $trim->($r[$_]) eq 'English' }     0 .. $#r;
        if (defined $ti && (defined $ei || $c0 eq 'Menus' || $c0 eq 'ID')) {
            $flush->();
            my $kind = $c0 eq 'Labels'                       ? 'labels'
                     : $c0 eq 'Menus'                        ? 'menus'
                     : ($c0 eq 'Speakers' || $c0 eq 'Items') ? 'lbl'
                     : $c0 eq 'Descriptions'                 ? 'desc'
                     :                                         'dlg';
            $hdr = { kind => $kind, col => $ti };
            next;
        }

        next unless $hdr;                             # stray row outside any section

        my $key   = $c0;
        my $value = defined $r[ $hdr->{col} ] ? $r[ $hdr->{col} ] : '';
        next unless length $key;

        if ($hdr->{kind} eq 'dlg' || $hdr->{kind} eq 'desc') {
            my $table = $resolve->($key, $hdr->{kind} eq 'desc' ? 'linesLUT' : $dlg_default);
            if (defined $pk && $pt eq $table && $pk eq $key) { push @pv, $value }
            else { $flush->(); ($pt, $pk, @pv) = ($table, $key, $value) }
        }
        else {
            next if $value eq '' || placeholder($value);   # empty -> keep the original
            my $table = $hdr->{kind} eq 'labels' ? 'sysLabel'
                      : $hdr->{kind} eq 'menus'  ? 'sysMenus'
                      :                            'labelLUT';
            apply_entry($table, $key, $value);
        }
    }
    $flush->();
    close $cfh;
}

elsif (defined $csv_file && length $csv_file) {
    warn "CSV file not found; skipping and preserving the original: $csv_file\n";
}
else {
    print "No CSV supplied; translation data will be preserved.\n";
}

# ==================================================
# Images
# ==================================================

sub image_type {                           # the official tool only uses PNG
    my ($b) = @_;
    return 'image/png' if substr($b, 0, 8) eq "\x89PNG\r\n\x1a\n";
    return;
}

if ($no_images) {
    my $n = $root->{children}{imgFiles};
    if ($n && $n->{type} eq 'object') {
        my $count = scalar keys %{ $n->{children} };
        add_patch($n, '{}', 'no images') if $count;
        $stats{images_removed} = $count;
        print "Images removed: $count entries (imgFiles = {})\n";
    }
    elsif (!$n) {
        print "imgFiles is absent; no image entries to remove.\n";
    }
    else {
        warn "imgFiles is not an object; cannot replace it with an empty object.\n";
    }
}
elsif (-d $img_dir) {
    my $img_node = $root->{children}{imgFiles};

    if ($img_node && $img_node->{type} ne 'object') {
        warn "imgFiles is not an object in the original; skipping image updates.\n";
    } else {
        find(
            {
                no_chdir => 1,
                wanted   => sub {
                    return unless -f $_;
                    return unless /\.png\z/i;            # the official tool only uses PNG files

                    my $full     = $File::Find::name;
                    my $relative = $full;
                    $relative =~ s{\A\Q$img_dir\E[\/\\]?}{};
                    $relative =~ s{\\}{/}g;
                    $relative =~ s{\.[^./]+\z}{};
                    $relative = "img/$relative" unless $relative =~ m{\Aimg/};

                    if ($relative =~ m{\A/} || $relative =~ m{(?:\A|/)\.\.(?:/|\z)}) {
                        warn "Skipping unsafe image path: $relative\n";
                        return;
                    }

                    my $fh;
                    unless (open $fh, '<:raw', $full) {
                        warn "Could not read image; skipping: $full: $!\n";
                        return;
                    }
                    my $image = do { local $/; <$fh> };
                    close $fh;

                    my $mime = image_type($image);
                    unless ($mime) {
                        warn "Not a valid PNG file; skipping: $full\n";
                        return;
                    }

                    my $b64  = encode_base64($image, '');
                    my $node = $img_node ? $img_node->{children}{$relative} : undef;

                    if ($node) {
                        my $prefix = node_raw($node) =~ /\A"(data:[^,"]*,)/ ? $1 : '';
                        my $value_json = $ENC->encode($prefix . $b64);
                        add_patch($node, $value_json, "Image $relative");
                        $stats{images_replaced}++;
                        print "Image updated: $relative\n";
                        return;
                    }

                    warn "Image key not found in the original imgFiles; skipping: $relative\n";
                    $stats{images_missing}++;
                },
            },
            $img_dir,
        );

    }
}
else {
    warn "Image folder not found; skipping image updates and preserving the original: $img_dir\n";
}

# ==================================================
# Font
# ==================================================

if ($no_font) {
    my ($file_node, $face_node) = @{ $root->{children} }{qw(fontFile fontFace)};
    my $face = defined $font_face_opt ? $font_face_opt : 'GameFont';

    if ($file_node) {
        add_patch($file_node, 'null', 'fontFile');
    } else {
        warn "fontFile is absent in the original; nothing to clear.\n";
    }

    if ($face_node) {
        add_patch($face_node, $ENC->encode($face), 'fontFace');
    } else {
        warn "fontFace is absent in the original; cannot set $face.\n";
    }
    print "Font removed (fontFile = null, fontFace = $face)\n";
}
elsif (defined $font_file) {
    if (!-f $font_file) {
        warn "Font file not found; skipping font updates and preserving the original: $font_file\n";
    } else {
        open my $fh, '<:raw', $font_file
            or die "Could not read font file ($font_file): $!\n";
        my $font = do { local $/; <$fh> };
        close $fh;

        my $font_name = $font_file;
        $font_name =~ s{.*[\/\\]}{};
        $font_name =~ s{\.[^.]+\z}{};
        $font_name = $font_face_opt if defined $font_face_opt;

        my $b64 = encode_base64($font, '');
        my ($file_node, $face_node) = @{ $root->{children} }{qw(fontFile fontFace)};

        if ($file_node && $face_node) {
            add_patch($file_node, $ENC->encode($b64),       'fontFile');
            add_patch($face_node, $ENC->encode($font_name), 'fontFace');
            print "Font updated: $font_file (fontFace=$font_name)\n";
        }
        else {
            warn "The original is missing fontFile or fontFace; skipping font updates.\n";
        }
    }
}
elsif (defined $font_face_opt) {
    # An explicit face name without a font file changes only fontFace and keeps fontFile.
    my $face_node = $root->{children}{fontFace};
    if ($face_node) {
        add_patch($face_node, $ENC->encode($font_face_opt), 'fontFace');
        print "fontFace updated: $font_face_opt (fontFile preserved)\n";
    } else {
        warn "fontFace is absent in the original; cannot set $font_face_opt.\n";
    }
}

# ==================================================
# Apply everything and save
# ==================================================

my @ordered = sort { $b->{start} <=> $a->{start} } values %patch;
my $last_start = $length + 1;

for my $p (@ordered) {
    die "Overlapping replacement positions: $p->{label}\n" if $p->{end} > $last_start;
    substr($text, $p->{start}, $p->{end} - $p->{start}, $p->{text});
    $last_start = $p->{start};
}

open my $out, '>:raw', $output
    or die "Failed to open output file ($output): $!\n";
print {$out} encode('UTF-8', "LANGDATA$text");
close $out or die "Failed to save output file ($output): $!\n";

print "\nSummary\n";
printf "  replaced: %d, unchanged: %d, fields: %d\n",
    map { $_ // 0 } @stats{qw(replaced unchanged fields)};
printf "  images replaced: %d, images missing: %d, images removed: %d\n",
    map { $_ // 0 } @stats{qw(images_replaced images_missing images_removed)};
if ($stats{missing}) {
    warn "  CSV entries not found in the original (skipped): $stats{missing}\n";
    warn "    e.g. $_\n" for @{ $stats{missing_examples} };
}
for my $name (sort keys %{ $stats{missing_fields} // {} }) {
    warn "  Top-level field missing in the original (not added): $name\n";
}
warn "  Images not in the original (skipped): $stats{images_missing}\n" if $stats{images_missing};

print "Repacking complete: $output\n";
