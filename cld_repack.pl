#!/usr/bin/env perl
use strict;
use warnings;

use Encode qw(decode encode);
use JSON::PP qw(decode_json encode_json);
use MIME::Base64 qw(encode_base64);
use Text::CSV;
use File::Find;

my ($input, $output, $csv_file, $img_dir, $font_file) = @ARGV;

die "Usage: perl cld_repack.pl input.cld output.cld [output.csv] [image_folder] [font_file]\n"
    unless defined $input && defined $output;

$csv_file //= 'output.csv';
$img_dir  //= './img';

open my $in, '<:raw', $input
    or die "Failed to open input file ($input): $!\n";
local $/;
my $bytes = <$in>;
close $in;

my $text = decode('UTF-8', $bytes);
$text =~ s/\ALANGDATA\s*//
    or die "The input file does not have the LANGDATA prefix.\n";

# Parse the JSON and record the original text positions of each value.
my $pos = 0;
my $length = length($text);

sub skip_ws {
    $pos++ while $pos < $length && substr($text, $pos, 1) =~ /\s/;
}

sub parse_string {
    my $start = $pos;

    die "Expected a JSON string (at position $pos).\n"
        unless substr($text, $pos, 1) eq '"';

    $pos++;

    while ($pos < $length) {
        my $char = substr($text, $pos, 1);

        if ($char eq '\\') {
            $pos += 2;
            next;
        }

        if ($char eq '"') {
            $pos++;
            my $raw_string = substr($text, $start, $pos - $start);
            my $decoded = decode_json($raw_string);
            return ($raw_string, $decoded, $start, $pos);
        }

        $pos++;
    }

    die "Unterminated JSON string.\n";
}

sub parse_value {
    skip_ws();

    my $start = $pos;
    my $char = substr($text, $pos, 1);

    if ($char eq '{') {
        $pos++;
        my %children;

        skip_ws();

        if (substr($text, $pos, 1) eq '}') {
            $pos++;
        } else {
            while (1) {
                skip_ws();
                my ($raw_key, $key) = parse_string();

                skip_ws();
                die "Expected a colon in the JSON object (at position $pos).\n"
                    unless substr($text, $pos++, 1) eq ':';

                $children{$key} = parse_value();

                skip_ws();
                my $next = substr($text, $pos++, 1);

                last if $next eq '}';
                die "Expected a comma in the JSON object.\n"
                    unless $next eq ',';
            }
        }

        return {
            type     => 'object',
            start    => $start,
            end      => $pos,
            children => \%children,
        };
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
                die "Expected a comma in the JSON array.\n"
                    unless $next eq ',';
            }
        }

        return {
            type     => 'array',
            start    => $start,
            end      => $pos,
            children => \@children,
        };
    }

    if ($char eq '"') {
        parse_string();
        return {
            type  => 'scalar',
            start => $start,
            end   => $pos,
        };
    }

    # Numbers, true, false, and null
    $pos++ while $pos < $length
        && substr($text, $pos, 1) !~ /[\s,\]}]/;

    die "Could not read a JSON value (at position $start).\n"
        if $pos == $start;

    return {
        type  => 'scalar',
        start => $start,
        end   => $pos,
    };
}

my $root = parse_value();

die "The top-level JSON value is not an object.\n"
    unless $root->{type} eq 'object';

skip_ws();
die "Unexpected content after the JSON value.\n"
    if $pos != $length;

my @patches;

sub node_at_path {
    my ($section, $key) = @_;

    my $node = $root->{children}{$section};
    return unless $node;

    return $node unless length $key;

    for my $part (split(/\./, $key, -1)) {
        if ($node->{type} eq 'object') {
            $node = $node->{children}{$part};
            return unless $node;
        } elsif ($node->{type} eq 'array' && $part =~ /\A\d+\z/) {
            $node = $node->{children}[$part];
            return unless $node;
        } else {
            return;
        }
    }

    return $node;
}

sub old_json_value {
    my ($node) = @_;

    return decode_json(
        substr($text, $node->{start}, $node->{end} - $node->{start})
    );
}

sub replacement_for_csv {
    my ($value, $node) = @_;
    my $old = old_json_value($node);

    if (JSON::PP::is_bool($old)) {
        return $value =~ /\A(?:true|1|yes)\z/i ? 'true' : 'false';
    }

    if (defined($old) && !ref($old)
        && $old =~ /\A-?\d+\z/
        && $value =~ /\A-?\d+\z/) {
        return encode_json(0 + $value);
    }

    if (defined($old) && !ref($old)
        && $old =~ /\A-?(?:\d+\.\d*|\d*\.\d+)(?:[eE][+-]?\d+)?\z/
        && $value =~ /\A-?(?:\d+\.\d*|\d*\.\d+)(?:[eE][+-]?\d+)?\z/) {
        return encode_json(0 + $value);
    }

    return encode_json($value);
}

sub add_patch {
    my ($node, $replacement, $label) = @_;

    push @patches, {
        start => $node->{start},
        end   => $node->{end},
        text  => $replacement,
        label => $label,
    };
}

# Apply CSV section,key,value rows to the corresponding paths in the original JSON.
if (-f $csv_file) {
    my $csv = Text::CSV->new({
        binary    => 1,
        auto_diag => 1,
    });

    open my $cfh, '<:encoding(UTF-8)', $csv_file
        or die "Failed to open CSV file ($csv_file): $!\n";

    my $header = $csv->getline($cfh);
    die "Could not read the CSV header.\n" unless $header;

    my %column;
    @column{@$header} = 0 .. $#$header;

    for my $name (qw(section key value)) {
        die "CSV is missing the '$name' column.\n"
            unless exists $column{$name};
    }

    while (my $row = $csv->getline($cfh)) {
        my ($section, $key, $value) =
            @$row[@column{qw(section key value)}];

        next if $section eq 'imgFiles' || $section eq 'fontFile';

        my $node = node_at_path($section, $key);

        unless ($node) {
            warn "CSV path not found in the original; skipping and preserving the original: "
                . "section=$section, key=$key\n";
            next;
        }

        add_patch(
            $node,
            replacement_for_csv($value, $node),
            "CSV $section,$key",
        );
    }

    close $cfh;
} else {
    warn "CSV file not found; skipping and preserving the original: $csv_file\n";
}

# Read all files under ./img and replace the corresponding imgFiles entries.
if (-d $img_dir) {
    my $img_node = $root->{children}{imgFiles};

    if (!$img_node || $img_node->{type} ne 'object') {
        warn "The original has no imgFiles object; skipping image updates "
            . "and preserving the original.\n";
    } else {
        find(
            {
                no_chdir => 1,
                wanted   => sub {
                    return unless -f $_;

                    my $full = $File::Find::name;
                    my $relative = $full;

                    # Remove the image folder path to get a relative path.
                    $relative =~ s{\A\Q$img_dir\E[\/\\]?}{};
                    $relative =~ s{\\}{/}g;

                    # Remove the file extension.
                    $relative =~ s{\.[^./]+\z}{};

                    # Add the img/ prefix to match the original imgFiles key format.
                    $relative = "img/$relative"
                        unless $relative =~ m{\Aimg/};

                    if ($relative =~ m{(?:\A|/)\.\.(?:/|\z)}) {
                        warn "Skipping unsafe image path: $relative\n";
                        return;
                    }

                    my $node = $img_node->{children}{$relative};

                    unless ($node) {
                        warn "Key not found in the original imgFiles; "
                            . "skipping and preserving the original: $relative\n";
                        return;
                    }

                    my $fh;
                    unless (open $fh, '<:raw', $full) {
                        warn "Could not read image; skipping and preserving the original: "
                            . "$full: $!\n";
                        return;
                    }

                    my $image = do { local $/; <$fh> };
                    close $fh;

                    my $b64 = encode_base64($image, '');

                    add_patch(
                        $node,
                        encode_json($b64),
                        "Image $relative",
                    );

                    print "Image updated: $relative\n";
                },
            },
            $img_dir,
        );
    }
} else {
    warn "Image folder not found; skipping image updates and preserving the original: "
        . "$img_dir\n";
}

# Update fontFile with the font file and fontFace with its name without the extension.
if (defined $font_file) {
    if (!-f $font_file) {
        warn "Font file not found; skipping font updates and preserving the original: "
            . "$font_file\n";
    } else {
        my $font_file_node = $root->{children}{fontFile};
        my $font_face_node = $root->{children}{fontFace};

        if (!$font_file_node || !$font_face_node) {
            warn "The original is missing fontFile or fontFace; skipping font updates "
                . "and preserving the original.\n";
        } else {
            my $fh;

            unless (open $fh, '<:raw', $font_file) {
                warn "Could not read font file; skipping font updates and preserving the original: "
                    . "$font_file: $!\n";
                $fh = undef;
            }

            if ($fh) {
                my $font = do { local $/; <$fh> };
                close $fh;

                my $font_name = $font_file;
                $font_name =~ s{.*[\/\\]}{};
                $font_name =~ s{\.[^.]+\z}{};

                add_patch(
                    $font_file_node,
                    encode_json(encode_base64($font, '')),
                    'fontFile',
                );

                add_patch(
                    $font_face_node,
                    encode_json($font_name),
                    'fontFace',
                );

                print "Font updated: $font_file (fontFace=$font_name)\n";
            }
        }
    }
}

# Apply replacements from the end of the source text so earlier positions remain unchanged.
@patches = sort { $b->{start} <=> $a->{start} } @patches;

my $last_start = $length + 1;

for my $patch (@patches) {
    die "Overlapping replacement positions: $patch->{label}\n"
        if $patch->{end} > $last_start;

    substr(
        $text,
        $patch->{start},
        $patch->{end} - $patch->{start},
        $patch->{text},
    );

    $last_start = $patch->{start};
}

# Save to a new file. The original file is not overwritten.
open my $out, '>:raw', $output
    or die "Failed to open output file ($output): $!\n";

print {$out} encode('UTF-8', "LANGDATA$text");
close $out or die "Failed to save output file ($output): $!\n";

print "Repacking complete: $output\n";