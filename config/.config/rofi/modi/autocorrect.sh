#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "$0")/common.sh"

# fix OUT: read text on stdin, write it with every misspelling replaced by
# aspell's first suggestion to OUT, and print one "wrong → right" per change.
if [[ ${1:-} == fix ]]; then
    work=$(mktemp -d "$RUNTIME/autocorrect.XXXXXX"); trap 'rm -rf -- "$work"' EXIT
    cat > "$work/text"
    # Prefix ^ prevents aspell pipe commands in user input.
    perl -CSD -pe 's/^/^/; s/\r//g; $_ .= "\n" unless /\n\z/' "$work/text" | aspell -a > "$work/aspell"
    perl -CSDA -e '
        use utf8;
        my ($text_file, $aspell_file, $out) = @ARGV;
        open my $t, "<", $text_file or die; local $/; my $text = <$t>; close $t;
        open my $fh, "<", $aspell_file or die; my @groups = split /^\n/m, <$fh>; close $fh;
        $groups[0] =~ s/^@[^\n]*\n// if @groups; # Version banner.
        my @lines = split /\n/, $text, -1;
        my @changes;
        for my $i (0 .. $#lines) {
            my @fix;
            for (split /\n/, $groups[$i] // "") {
                next unless /^& (\S+) \d+ (\d+): ([^,]+)/;
                next if lc $3 eq lc $1; # Case-only suggestions are usually wrong.
                push @fix, [$2 - 1, $1, $3];
            }
            for my $f (sort { $b->[0] <=> $a->[0] } @fix) {
                substr($lines[$i], $f->[0], length $f->[1]) = $f->[2]
                    if substr($lines[$i], $f->[0], length $f->[1]) eq $f->[1];
            }
            push @changes, map { "$_->[1] → $_->[2]" } @fix;
        }
        open my $o, ">", $out or die; print $o join("\n", @lines); close $o;
        print "$_\n" for @changes;
    ' "$work/text" "$work/aspell" "$2"
    exit
fi

live_page Autocorrect 'Type a word; select a suggestion to copy it.' '[]'
while IFS= read -r event; do
    name=$(jq -r .name <<<"$event")
    value=$(jq -r .value <<<"$event")
    case $name in
        'input change')
            if [[ -z $value ]]; then live_page Autocorrect 'Type a word.' '[]'; continue; fi
            result=$(printf '^%s\n' "${value//$'\n'/ }" | aspell -a)
            suggestions=$(sed -n 's/^&[^:]*: //p' <<<"$result" | tr ',' '\n' | sed 's/^ *//' | jq -Rsc 'split("\n")|map(select(length>0))|reduce .[] as $word ([]; if index($word)==null then .+[$word] else . end)')
            if [[ $suggestions == '[]' ]]; then
                if [[ $result == *$'\n#'* ]]; then live_page Autocorrect 'No suggestions found.' '[]'
                else live_page Autocorrect 'Spelling is correct.' "$(jq -cn --arg word "$value" '[$word]')"; fi
            else live_page Autocorrect 'Select a correction to copy it.' "$suggestions"; fi;;
        'select entry') printf '%s' "$value" | wl-copy; exit;;
    esac
done
