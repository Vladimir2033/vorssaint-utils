#!/usr/bin/perl
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Vorssaint
# Syntex Utils: unofficial personal fork of Vorssaint, under the same license.
#
# Rewrites the app's name in the texts a person sees, for `./build.sh --syntex`.
#
# Why at build time: the repository keeps the upstream strings untouched, so
# every merge of a new Vorssaint release applies cleanly. About 1.400 visible
# strings in 15 languages name the app; editing them in place would conflict
# with almost every upstream release.
#
# What is rewritten: the word "Vorssaint" inside Swift string literals, and
# in Info.plist / InfoPlist.strings values. What is not:
#   - comments, identifiers, module and folder names (Sources/Vorssaint stays);
#   - copyright and license lines (anything with "©" or "Copyright");
#   - "Vorssaint Utils" and "Vorssaint.<word>" (the pre-2.5 official app name,
#     bundle file names and notification names keep pointing where they did);
#   - lowercase "vorssaint" (URLs, bundle ids, the upstream repository);
#   - SyntexFork.swift, whose About credit names the original on purpose;
#   - ReleaseNotes.swift, which matches the official release text word for
#     word to trim its install boilerplate.
#
# Usage:
#   syntex-branding.pl --swift OUTDIR FILE...
#       Writes OUTDIR/<FILE> for every Swift file whose literals change, only
#       when its content differs from what is there (keeps incremental builds
#       incremental), and prints "FILE<TAB>OUTDIR/FILE" for each one.
#   syntex-branding.pl --in-place FILE...
#       Rewrites plist / .strings files in place (the staged copies, never the
#       repository's).
use strict;
use warnings;
use File::Basename qw(dirname basename);
use File::Path qw(make_path);

my $NAME = "Syntex Utils";
my %SKIP = map { $_ => 1 } ("SyntexFork.swift", "ReleaseNotes.swift");

# Byte semantics on purpose: "Vorssaint를" (Korean particle) must still match,
# and under Unicode rules the Hangul would count as a word character.
sub brand_text {
    my ($text) = @_;
    $text =~ s/(?<![A-Za-z0-9_\/.-])Vorssaint(?![A-Za-z0-9_])(?! Utils)(?!\.[A-Za-z])/$NAME/g;
    return $text;
}

sub protected_line {
    my ($line) = @_;
    return $line =~ /\x{c2}\x{a9}|Copyright/;   # "©" as UTF-8 bytes
}

sub brand_swift_line {
    my ($line) = @_;
    return $line if protected_line($line);
    return $line if $line =~ m{^\s*(//|/\*|\*)};
    # Literals are matched as whole "..." runs with their escapes, so an
    # interpolation's own quotes stay balanced. A quoted word in a trailing
    # comment may change too; comments never reach the screen.
    $line =~ s{"((?:[^"\\]|\\.)*)"}{'"' . brand_text($1) . '"'}ge;
    return $line;
}

sub read_file {
    my ($path) = @_;
    open(my $fh, '<:raw', $path) or die "cannot read $path: $!\n";
    local $/;
    my $content = <$fh>;
    close $fh;
    return $content;
}

sub write_file {
    my ($path, $content) = @_;
    make_path(dirname($path));
    open(my $fh, '>:raw', $path) or die "cannot write $path: $!\n";
    print $fh $content;
    close $fh;
}

my $mode = shift @ARGV // '';
if ($mode eq '--swift') {
    my $out = shift @ARGV or die "--swift needs an output directory\n";
    for my $file (@ARGV) {
        next if $SKIP{basename($file)};
        my $original = read_file($file);
        my $in_block = 0;
        my @lines = split /(?<=\n)/, $original;
        for my $line (@lines) {
            # Multi-line literals hold shell and AppleScript sources, which
            # never reach the screen; leave them byte for byte.
            my $quotes = () = $line =~ /"""/g;
            if ($in_block || $quotes) {
                $in_block = !$in_block if $quotes % 2;
                next;
            }
            $line = brand_swift_line($line);
        }
        my $branded = join('', @lines);
        next if $branded eq $original;
        # Diagnostics and #file keep naming the repository's file and line.
        $branded = "#sourceLocation(file: \"$file\", line: 1)\n" . $branded;
        my $target = "$out/$file";
        my $current = -e $target ? read_file($target) : undef;
        write_file($target, $branded) unless defined $current && $current eq $branded;
        print "$file\t$target\n";
    }
} elsif ($mode eq '--in-place') {
    for my $file (@ARGV) {
        my @lines = split /(?<=\n)/, read_file($file);
        for my $line (@lines) {
            $line = brand_text($line) unless protected_line($line);
        }
        write_file($file, join('', @lines));
    }
} else {
    die "usage: $0 --swift OUTDIR FILE... | --in-place FILE...\n";
}
