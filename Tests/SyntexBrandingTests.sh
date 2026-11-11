#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Vorssaint
# Syntex Utils: unofficial personal fork of Vorssaint, under the same license.

# What these tests protect: `./build.sh --syntex` shows "Syntex Utils" wherever
# a person reads the app's name, and touches nothing else. Two bad outcomes:
# a screen that still says "Vorssaint" in the fork, or a rewrite that reaches
# code (identifiers, notification names, file names the app looks for), the
# copyright line, or the credit that names the original project.
# Runs with perl alone, so it also runs off the Mac.

set -euo pipefail
cd "$(dirname "$0")/.."
work=$(mktemp -d)
trap 'command rm -rf "$work"' EXIT
failures=0
expect() {
    if [[ "$2" != "$3" ]]; then
        print -r -- "✗ $1"
        print -r -- "    expected: $3"
        print -r -- "    got:      $2"
        failures=$((failures + 1))
    fi
}

mkdir -p "$work/src"
cat > "$work/src/Sample.swift" <<'EOF'
// Vorssaint keeps this comment
let title = "Quit Vorssaint"
let sentence = "Allow Vorssaint."
let korean = "Vorssaint를 다시 켜세요"
let identifier = keepAwakeActiveIconVorssaint
let copyright = "© 2026 Vorssaint"
let oldApp = "Vorssaint Utils.app"
let newApp = "Vorssaint.app"
let note = Notification.Name("Vorssaint.launchAtLoginRefresh")
let url = "https://github.com/vorssaint/vorssaint-utils"
let both = "\(name) for Vorssaint \(flag ? "on" : "off") Vorssaint"
let script = """
    echo Vorssaint
    """
/// Used by "Uninstall Vorssaint completely".
EOF
cat > "$work/src/Plain.swift" <<'EOF'
let nothing = "no app name here"
EOF
cat > "$work/src/SyntexFork.swift" <<'EOF'
let credit = "Unofficial fork of Vorssaint"
EOF

map="$(perl Tools/syntex-branding.pl --swift "$work/out" \
    "$work/src/Sample.swift" "$work/src/Plain.swift" "$work/src/SyntexFork.swift")"
expect "only files whose texts change are listed" \
    "$map" "$work/src/Sample.swift"$'\t'"$work/out/$work/src/Sample.swift"
branded="$work/out/$work/src/Sample.swift"
expect "the copy points diagnostics at the repository's file" \
    "$(sed -n 1p "$branded")" "#sourceLocation(file: \"$work/src/Sample.swift\", line: 1)"
expect "lines keep their numbers after the location line" \
    "$(sed 1d "$branded" | wc -l | tr -d ' ')" "$(wc -l < "$work/src/Sample.swift" | tr -d ' ')"
line() { sed -n "$(($1 + 1))p" "$branded"; }
expect "comments keep the original name" "$(line 1)" "// Vorssaint keeps this comment"
expect "a visible string is renamed" "$(line 2)" 'let title = "Quit Syntex Utils"'
expect "a sentence ending in a full stop is renamed" "$(line 3)" 'let sentence = "Allow Syntex Utils."'
expect "a name glued to a Korean particle is renamed" "$(line 4)" 'let korean = "Syntex Utils를 다시 켜세요"'
expect "identifiers are not renamed" "$(line 5)" "let identifier = keepAwakeActiveIconVorssaint"
expect "the copyright line is kept" "$(line 6)" 'let copyright = "© 2026 Vorssaint"'
expect "the pre-2.5 app name is kept" "$(line 7)" 'let oldApp = "Vorssaint Utils.app"'
expect "bundle file names are kept" "$(line 8)" 'let newApp = "Vorssaint.app"'
expect "notification names are kept" "$(line 9)" 'let note = Notification.Name("Vorssaint.launchAtLoginRefresh")'
expect "lowercase URLs are kept" "$(line 10)" 'let url = "https://github.com/vorssaint/vorssaint-utils"'
expect "interpolations keep their own quotes balanced" "$(line 11)" \
    'let both = "\(name) for Syntex Utils \(flag ? "on" : "off") Syntex Utils"'
expect "multi-line literals (shell, AppleScript) are kept" "$(line 13)" "    echo Vorssaint"
expect "quoted names in comments are kept" "$(line 15)" '/// Used by "Uninstall Vorssaint completely".'
[[ ! -e "$work/out/$work/src/SyntexFork.swift" ]] \
    || { print "✗ the fork's credit file is never rewritten"; failures=$((failures + 1)); }

# An unchanged copy is not written again: the compiler would rebuild it.
touch -t 202001010000 "$branded"
perl Tools/syntex-branding.pl --swift "$work/out" "$work/src/Sample.swift" >/dev/null
expect "a second run leaves an identical copy untouched" \
    "$(find "$branded" -newer "$work/src/Plain.swift" | wc -l | tr -d ' ')" "0"

# Plist and .strings values, rewritten in the staged copies.
cat > "$work/Info.plist" <<'EOF'
	<string>Vorssaint</string>
	<string>Vorssaint uses Bluetooth only to read the battery level.</string>
	<string>© 2026 Vorssaint</string>
EOF
perl Tools/syntex-branding.pl --in-place "$work/Info.plist"
expect "plist values are renamed and the copyright is kept" "$(cat "$work/Info.plist")" \
    $'\t<string>Syntex Utils</string>\n\t<string>Syntex Utils uses Bluetooth only to read the battery level.</string>\n\t<string>© 2026 Vorssaint</string>'

# The real sources: after the rewrite, a string literal may name Vorssaint
# only where that is the point. A new upstream string slips through here.
setopt extended_glob
real_map="$(perl Tools/syntex-branding.pl --swift "$work/real" Sources/Vorssaint/**/*.swift)"
leftovers="$(perl -e '
    my %branded = map { chomp; split /\t/ } split /\n/, shift;
    my %allowed = map { $_ => 1 } qw(
        AppInfo.swift BundleMigration.swift ReleaseNotes.swift SyntexFork.swift
        GeneralPasteboardAccess.swift LaunchAtLoginSupport.swift UpdateInstallerSupport.swift);
    for my $file (@ARGV) {
        my ($name) = $file =~ m{([^/]+)$};
        next if $allowed{$name};
        open(my $fh, "<", $branded{$file} // $file) or die;
        while (<$fh>) {
            next if m{^\s*(//|/\*|\*)};
            print "$file:$.: $_" if /"(?:[^"\\]|\\.)*(?<![A-Za-z0-9_\/.-])Vorssaint(?![A-Za-z0-9_])/;
        }
    }' "$real_map" Sources/Vorssaint/**/*.swift)"
expect "no visible string still names Vorssaint in the fork" "$leftovers" ""
expect "the allowed files still name Vorssaint only on purpose" \
    "$(grep -c 'static let copyright = "© 2026 Vorssaint"' Sources/Vorssaint/Core/AppInfo.swift)" "1"

if (( failures )); then
    print "SYNTEX BRANDING TESTS FAILED: $failures"
    exit 1
fi
print 'SYNTEX BRANDING TESTS OK'
