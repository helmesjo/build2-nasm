#!/usr/bin/env bash

# set -o pipefail # fail if subshell fails
# set -o errexit # error out when a command/script/function fails
# set -o nounset # fail when expanding an unset variable

export color_White=$'\e[1;37m';  export color_DarkWhite=$'\e[1;0m'
export color_Red=$'\e[1;31m';    export color_DarkRed=$'\e[0;31m';
export color_Green=$'\e[1;32m';  export color_DarkGreen=$'\e[0;32m';
export color_Blue=$'\e[1;34m';   export color_DarkBlue=$'\e[0;34m';
export color_Yellow=$'\e[1;33m'; export color_DarkYellow=$'\e[0;33m';
export color_Default=$color_DarkWhite

script_dir="$(pwd)"

# NOTE: these names are expected by the perl scripts
top_srcdir="$(readlink -f $1)"
tools="${top_srcdir}/tools"
SUBDIRS="stdlib nasmlib include config output asm disasm x86 common macros"
XSUBDIRS="test doc nsis win"
DEPDIRS=". $SUBDIRS"
PERL="$(which perl)"
PERLFLAGS="-I./perllib/ -I./"
RUNPERL="$PERL $PERLFLAGS"
# -----------------------------------

if ! find . -maxdepth 0 -printf "%T@\n" 2>/dev/null; then
  found="$(find $(brew --prefix)/opt/findutils/ -name gfind)"
  if [[ -z ${found:-} ]]; then
    echo "Error: If on MacOS, install gfind: brew install findutils"
    exit 1
  fi

  gfind() { $found "$@"; }
  export -f gfind
else
  gfind() { find "$@"; }
  export -f gfind
fi

makefiles=$(find $top_srcdir -type f -name 'Makefile.in')
generated_files=()
failed=()
for file in ${makefiles[@]}; do
  srcdir="$(dirname $file)"
  [[ "$file" == "$script_dir"/* ]] && continue

  printf '\n%b%s%b%s\n\n' $color_Blue "PARSING in $srcdir: " $color_Default "$file"

  # 1. remove all trailing comments
  # 2. remove all escaped newlines (join multi-lines)
  # 3. remove empty lines
  # 4. Replace $(...) with ${...}
  # 5. grep all lines containing ${RUNPERL}
  # 6. trim whitespace
  # 7. Remove lines executing tests
  lines=$(cat "$file" \
    | sed -E 's%[[:space:]]*#.*$%%g' \
    | sed -re :a -e '/\\$/N; s/\\\n//; ta' \
    | sed -E 's%\$\(([^)]+)\)%\${\1}%g' \
    | grep -E '\$\{RUNPERL\}' \
    | sed -E 's%^[[:space:]]+%%g' \
    | sed -E 's%[[:space:]]+% %g' \
    | sed -E 's%[[:space:]]*=[[:space:]]*%=%' \
    | sed -E '/^[[:space:]]*$/d' \
    | sed -E 's%'"'"'%%g' \
    | sed -E '/^.*performtest.pl.*$/d' \
    )

  before=$(mktemp)
  after=$(mktemp)
  lines=$(eval "echo \"$lines\"") || continue
  while read -r line; do
    [[ -z "$line" ]] && continue
    echo "/usr/bin/env -C "$top_srcdir" && $line"

    $(cd "$top_srcdir" && gfind . -type f -printf "%T@ %p\n" | sort > "$before")

    stdout="$(mktemp)"
    ec=$(cd "$top_srcdir" &&  bash -c "eval '${line[@]}' >>$stdout 2>>$stdout; echo \$?")
    out="$(cat $stdout)"

    # Record state after eval
    $(cd "$top_srcdir" && gfind . -type f -printf "%T@ %p\n" | sort > "$after")

    # Compare to find new files
    new_files=$(comm -13 "$before" "$after")
    new_files=$(echo "$new_files" | awk '{print $2}')
    echo "${new_files[@]}"
    rm "$stdout" "$before" "$after"

    if [[ $ec -ne 0 ]]; then
      errstr="$(printf '%b%s\n  %b> %s\n  %b> %s\n ' $color_Red "ERR ($ec): " $color_DarkYellow "$out" $color_Default "${line[@]}")"
      failed+=("$errstr")
      printf '%s' "$errstr" >&2
      continue
    elif [[ -z ${new_files:-} ]]; then
      errstr="$(printf '%b%s\n  %b> %s\n  %b> %s\n ' $color_Yellow "WARN: " $color_DarkYellow "${out:-No files generated}" $color_Default "${line[@]}")"
      failed+=("$errstr")
      printf '%s' "$errstr" >&2
      continue
    else
      for newfile in ${new_files[@]}; do
        src="$srcdir/$newfile"
        dst="$script_dir/$newfile"
        mkdir -p $(dirname "$dst")
        cp "$src" "$dst"

        sed -e "s|$top_srcdir/||g" -i -- $dst

        generated_files+=("$newfile")
        printf '%b%s%b%s\n' $color_Green "OK: " $color_Default "$dst"
      done
    fi
  done <<<$lines
done

printf '\n%b%s\n%b%s\n' $color_Green "GENERATED: " $color_Default "${generated_files[@]}" >&2
printf '\n%b%s\n%b%s\n' $color_Red "FAILED: " $color_Default "${failed[*]}" >&2
