#!/usr/bin/env perl
use strict;
use warnings;

use JSON::PP qw(decode_json);
use MIME::Base64 qw(decode_base64);
use File::Path qw(make_path);
use File::Basename qw(dirname);

my $input = shift or die "Usage: perl extract_cld.pl input.cld [output_folder]\n";
my $root  = shift // '.';

open my $in, '<:raw', $input or die "Failed to open input file: $!\n";
local $/;
my $data = <$in>;
close $in;

# Remove the LANGDATA prefix at the beginning of the file
$data =~ s/\ALANGDATA\s*//;

my $json = eval { decode_json($data) };
die "JSON parsing failed: $@" if $@;
die "The top-level data is not a JSON object.\n"
    unless ref($json) eq 'HASH';

sub make_parent_dir {
    my ($path) = @_;
    my $dir = dirname($path);
    make_path($dir) unless -d $dir;
}

sub decode_b64 {
    my ($value) = @_;
    $value =~ s/\Adata:[^,]*,//;
    return decode_base64($value);
}

sub csv_field {
    my ($value) = @_;

    $value = '' unless defined $value;
    $value = "$value";
    $value =~ s/"/""/g;

    return qq{"$value"};
}

# ==================================================
# imgFiles: Save Base64 images by path
# ==================================================

if (ref($json->{imgFiles}) eq 'HASH') {

    for my $path (sort keys %{$json->{imgFiles}}) {

        if ($path =~ m{^[/\\]}
            || $path =~ m{(?:^|[/\\])\.\.(?:[/\\]|$)}) {

            warn "Skipping unsafe image path: $path\n";
            next;
        }

        my $value = $json->{imgFiles}{$path};

        unless (defined $value && !ref($value)) {
            warn "Skipping image because its data is not a string: $path\n";
            next;
        }

        my $bytes = decode_b64($value);

        my $ext = '.bin';

        if (substr($bytes, 0, 8) eq "\x89PNG\r\n\x1a\n") {
            $ext = '.png';
        }
        elsif (substr($bytes, 0, 3) eq "\xFF\xD8\xFF") {
            $ext = '.jpg';
        }
        elsif (substr($bytes, 0, 6) =~ /\AGIF8[79]a/) {
            $ext = '.gif';
        }
        elsif (substr($bytes, 0, 4) eq 'RIFF'
            && substr($bytes, 8, 4) eq 'WEBP') {
            $ext = '.webp';
        }
        elsif (substr($bytes, 0, 2) eq 'BM') {
            $ext = '.bmp';
        }
        elsif (substr($bytes, 0, 4) eq "\x00\x00\x01\x00") {
            $ext = '.ico';
        }

        my $out_path = "$root/$path$ext";

        make_parent_dir($out_path);

        open my $img, '>:raw', $out_path
            or do {
                warn "Failed to save image ($out_path): $!\n";
                next;
            };

        print {$img} $bytes;
        close $img;

        print "Image saved: $out_path\n";
    }
}

# ==================================================
# fontFile: Save the font using the fontFace name
# ==================================================

if (defined $json->{fontFile}
    && !ref($json->{fontFile})
    && length $json->{fontFile}) {

    my $bytes = decode_b64($json->{fontFile});

    my $ext = '.bin';
    my $signature = substr($bytes, 0, 4);

    if ($signature eq 'OTTO') {
        $ext = '.otf';
    }
    elsif ($signature eq "\x00\x01\x00\x00"
        || $signature eq 'true') {
        $ext = '.ttf';
    }

    my $font_name = $json->{fontFace} // 'font';

    $font_name =~ s/[\/\\:*?"<>|]/_/g;
    $font_name =~ s/^\.+//;
    $font_name = 'font' if $font_name eq '';

    my $font_path = "$root/$font_name$ext";

    make_parent_dir($font_path);

    open my $font, '>:raw', $font_path
        or die "Failed to save font ($font_path): $!\n";

    print {$font} $bytes;
    close $font;

    print "Font saved: $font_path\n";

}
else {
    warn "fontFile data is missing or empty.\n";
}

# ==================================================
# Recursive CSV writing function
# ==================================================

sub write_csv_recursive {
    my ($fh, $section, $key, $value) = @_;

    # Handle JSON objects
    if (ref($value) eq 'HASH') {

        for my $subkey (sort keys %$value) {

            my $new_key = length($key)
                ? "$key.$subkey"
                : $subkey;

            write_csv_recursive(
                $fh,
                $section,
                $new_key,
                $value->{$subkey}
            );
        }
    }

    # Handle JSON arrays
    elsif (ref($value) eq 'ARRAY') {

        for my $i (0 .. $#$value) {

            my $new_key = length($key)
                ? "$key.$i"
                : "$i";

            write_csv_recursive(
                $fh,
                $section,
                $new_key,
                $value->[$i]
            );
        }
    }

    # Handle scalar values
    elsif (!ref($value)) {

        print {$fh}
            csv_field($section), ',',
            csv_field($key), ',',
            csv_field($value), "\n";
    }
}

# ==================================================
# Save the remaining JSON data as CSV
# ==================================================

my $csv_path = "$root/output.csv";

make_parent_dir($csv_path);

open my $csv, '>:encoding(UTF-8)', $csv_path
    or die "Failed to open CSV file ($csv_path): $!\n";

print {$csv} "section,key,value\n";

for my $section (sort keys %$json) {

    # Do not include actual file data in the CSV
    next if $section eq 'imgFiles' || $section eq 'fontFile';

    print "Processing CSV: $section\n";

    write_csv_recursive(
        $csv,
        $section,
        '',
        $json->{$section}
    );
}

close $csv;

print "CSV saved: $csv_path\n";
print "All tasks completed!\n";
