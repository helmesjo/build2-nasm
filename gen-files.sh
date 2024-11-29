#!/usr/bin/env bash

# set -o pipefail # fail if subshell fails
# set -o errexit # error out when a command/script/function fails
# set -o nounset # fail when expanding an unset variable

export color_White=$'\e[1;37m';  export color_DarkWhite=$'\e[1;0m'
export color_Red=$'\e[1;31m';    export color_DarkRed=$'\e[0;31m';
export color_Green=$'\e[1;32m';  export color_DarkGreen=$'\e[0;32m';
export color_Yellow=$'\e[1;33m'; export color_DarkYellow=$'\e[0;33m';
export color_Default=$color_DarkWhite

script_dir="$(realpath -L $(dirname $0))"
script_dir="$(pwd)"

# NOTE: these names are expected by the perl scripts
srcdir="$(realpath -L $1)"
top_srcdir="$srcdir"
tools="${top_srcdir}/tools"
SUBDIRS="stdlib nasmlib include config output asm disasm x86 common macros"
XSUBDIRS="test doc nsis win"
DEPDIRS=". $SUBDIRS"
PERL="$(which perl)"
PERLFLAGS="-I./perllib/ -I./"
RUNPERL="$PERL $PERLFLAGS"
# -----------------------------------

makefiles=../Makefile.in #$(find ../Makefile.in -type f -name 'Makefile.in')
generated_files=()
failed=()
for file in ${makefiles[@]}; do
  echo "PARSING $file..."

  # 1. remove all trailing comments
  # 2. remove all escaped newlines (join multi-lines)
  # 3. remove empty lines
  # 4. Replace $(...) with ${...}
  # 5. grep all lines containing ${RUNPERL}
  # 6. trim whitespace
  # 7. Remove lines executing tests
  lines=$(cat "$file" \
    | sed -r 's%\s*#.*$%%g' \
    | sed -re :a -e '/\\$/N; s/\\\n//; ta' \
    | sed -r 's%\$\((\S+)\)%${\1}%g' \
    | grep '${RUNPERL}' \
    | sed -r 's%^\s+%%g' \
    | sed -r 's%\s+% %g' \
    | sed -r 's%\s*=\s*%=%' \
    | sed -r '/^\s*$/d' \
    | sed -r 's%'"'"'%%g' \
    | sed -r '/^.*performtest.pl.*$/d' \
    )

  lines=$(eval "echo \"$lines\"") || continue
  while read -r line; do
    echo "/usr/bin/env -C "$srcdir" $line"
    genfile=$(echo "${line[@]}" | sed -n -E "s%.* > (.*)\$%\1%p")

    stdout="$(mktemp)"
    before=$(mktemp)
    after=$(mktemp)

    # Record state before eval
    /usr/bin/env -C "$srcdir" find . -type f -printf "%T@ %p\n" | sort > "$before"

    ec=$(/usr/bin/env -C "$srcdir" bash -c "eval '${line[@]}' >>$stdout 2>>$stdout; echo \$?")
    out="$(cat $stdout)"

    # Record state after eval
    /usr/bin/env -C "$srcdir" find . -type f -printf "%T@ %p\n" | sort > "$after"

    # Compare to find new files
    new_files=$(comm -13 "$before" "$after")
    new_files=$(echo "$new_files" | awk '{print $2}')
    rm "$before" "$after"

    if [[ $ec -ne 0 ]]; then
      errstr="$(printf '%b%s\n  %b%s\n  %b%s\n' $color_Red "ERR ($ec): " $color_DarkYellow "$out" $color_Default "${line[@]}")"
      failed+=("$errstr")
      printf '%s\n\n' "$errstr" >&2
      continue
    elif [[ -z ${new_files[@]:-} ]]; then
      errstr="$(printf '%b%s\n  %b%s\n' $color_Yellow "WARN: " $color_Default "${line[@]}")"
      printf '%s\n\n' "$errstr" >&2
      continue
    else
      for newfile in ${new_files[@]}; do
        src="$srcdir/$newfile"
        dst="$script_dir/$newfile"
        mkdir -p $(dirname "$dst")
        cp "$src" "$dst"

        generated_files+=("$newfile")
        printf '%b%s%b%s\n\n' $color_Green "OK: " $color_Default "$dst"
      done
    fi
  done <<<$lines
done

printf '\n%b%s\n%b%s\n' $color_Green "GENERATED: " $color_Default "${generated_files[@]}" >&2
printf '\n%b%s\n%b%s\n' $color_Red "FAILED: " $color_Default "${failed[@]}" >&2
