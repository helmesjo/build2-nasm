#!/usr/bin/env bash

unalias -a

if [[ $(uname) == Darwin ]]; then
  if ! which gsed; then
    echo "Error: If on MacOS, install gsed: brew install gnu-sed"
    exit 1
  fi

  if ! which gfind; then
    echo "Error: If on MacOS, install gfind: brew install findutils"
    exit 1
  fi

  gfind() { command gfind "$@"; }
  export -f gfind
  gsed() { command gsed "$@"; }
  export -f gsed
else
  gsed() { command sed "$@"; }
  export -f gsed
  gfind() { command find "$@"; }
  export -f gfind
fi

export color_White=$'\e[1;37m';  export color_DarkWhite=$'\e[1;0m'
export color_Red=$'\e[1;31m';    export color_DarkRed=$'\e[0;31m';
export color_Green=$'\e[1;32m';  export color_DarkGreen=$'\e[0;32m';
export color_Blue=$'\e[1;34m';   export color_DarkBlue=$'\e[0;34m';
export color_Yellow=$'\e[1;33m'; export color_DarkYellow=$'\e[0;33m';
export color_Default=$color_DarkWhite

script_dir="$(pwd)"

# NOTE: these names are expected by the perl scripts
repo_root="$(git rev-parse --show-toplevel)"
if cygpath --version >/dev/null; then
  repo_root="$(cygpath -u $repo_root)"
fi
top_srcdir="$(readlink -f $1)"
objdir="$top_srcdir"
prefix=/build
exec_prefix=${prefix}
bindir=${exec_prefix}/bin
datarootdir=${prefix}/share
mandir=${datarootdir}/man

tools="${top_srcdir}/tools"
SUBDIRS="stdlib nasmlib include config output asm disasm x86 common macros"
XSUBDIRS="test doc nsis win"
DEPDIRS=". $SUBDIRS"
PERL="$(which perl)"
PERLFLAGS="-I./perllib/ -I./"
RUNPERL="$PERL $PERLFLAGS"
# -----------------------------------

makefiles=$(gfind $top_srcdir -type f -name 'Makefile.in')
generated_files=()
failed=()
for file in ${makefiles[@]}; do
  [[ "$file" == "$script_dir"/* ]] && continue
  srcdir="$(readlink -f $(dirname $file))"

  printf '\n%b%s%b%s\n\n' $color_Blue "PARSING in $srcdir: " $color_Default "$file"

  # 1. remove all trailing comments
  # 2. remove all escaped newlines (join multi-lines)
  # 3. remove empty lines
  # 4. Replace $(...) with ${...}
  # 5. grep all lines containing ${RUNPERL}
  # 6. trim whitespace
  # 7. Remove lines executing tests
  # 8. extract target & prerequisites & store as <key@value> pair
  lines=$(cat "$file" \
    | gsed -E 's%[[:space:]]*#.*$%%g' \
    | gsed -re :a -e '/\\$/N; s/\\\n//; ta' \
    | gsed -E 's%[[:space:]]+% %g' \
    | gsed -E 's%^[[:space:]]+%%g' \
    | gsed -E 's%[[:space:]]*=[[:space:]]*%=%' \
    | gsed -E 's%^(.+): (.*)$%<\1@\2>\\%g' \
    | gsed -re :a -e '/\\$/N; s/\\\n//; ta' \
    | gsed 's%\$@%\${__target}%g' \
    | gsed 's%\$<%\${__prereqs[0]}%g' \
    | gsed 's%\$\^%\${__prereqs[@]}%g' \
    | gsed 's%\$%\\$%g' \
    | gsed -E 's%\$\(([^)]+)\)%"\${\1}"%g' \
    | grep -E '\$\{RUNPERL\}' \
    | gsed -E '/^[[:space:]]*$/d' \
    | gsed -E 's%'"'"'%%g' \
    | gsed -E 's%"%%g' \
    | gsed -E '/^.*performtest.pl.*$/d' \
    )

  lines=$(eval "echo \"$lines\"")

  stdout=$(mktemp)
  before=$(mktemp)
  after=$(mktemp)

  while read -r line; do
    [[ -z "${line:-}" ]] && continue

    > $before
    > $after
    > $stdout

    # Record state before eval
    $(cd "$top_srcdir" && gfind . -type f -printf "%T@ %p\n" | sort > $before)

    # extract target & prerequisites '<target@prerequisites>'
    pair=
    [[ "$line" == *"<"*"@"*">"* ]] && pair="${line%%>*}";pair="${pair#<}"
    __target=
    __prereqs=
    val="${line%%@*}"; __target="${val#<}"
    val="${line#*@}"; __prereqs=(${val%%>*});
    [[ "$line" == "$__target" ]] && __target=
    [[ "$line" == "$__prereqs" ]] && __prereqs=
    line="${line#*>}"
    line=$(eval "echo \"$line\"")
    printf '%b%s%b%s\n%b%s%b%s\n' $color_Blue "> $__target: " $color_DarkBlue "${__prereqs[*]}" \
                                  $color_Blue "> " $color_Default "/usr/bin/env -C $top_srcdir $line"

    ec=$(cd "$top_srcdir" &&  bash -c "eval '${line[@]}' >>$stdout 2>>$stdout; echo \$?")
    out="$(cat $stdout)"

    # Record state after eval
    $(cd "$top_srcdir" && gfind . -type f -printf "%T@ %p\n" | sort > $after)

    # Compare to find new files
    new_files=$(comm -13 $before $after)
    new_files=$(echo "$new_files" | awk '{print $2}')

    if [[ $ec -ne 0 ]]; then
      errstr="$(printf '%b%s\n  %b> %s\n  %b> %s\n ' $color_Red "ERR ($ec): " $color_DarkYellow "$out" $color_Default "${line[@]}")"
      failed+=( "$errstr" )
      printf '%s\n' "$errstr" >&2
      continue
    elif [[ -z ${new_files:-} ]]; then
      errstr="$(printf '%b%s\n  %b> %s\n  %b> %s\n ' $color_Yellow "WARN: " $color_DarkYellow "${out:-No files generated}" $color_Default "${line[@]}")"
      failed+=( "$errstr" )
      printf '%s\n' "$errstr" >&2
      continue
    else
      for newfile in ${new_files[@]}; do
        src="$srcdir/$newfile"
        dst="$script_dir/${newfile#./}"
        mkdir -p $(dirname "$dst")
        cp "$src" "$dst"

        # clean up comments to not cause redundant diffs
        gsed -e "s|$top_srcdir/||g" -i "$dst"

        generated_files+=( "$newfile" )
        printf '%b%s%b%s\n' $color_Green "OK: " $color_Default "${src#"$repo_root/"} -> ./${dst#"$repo_root/"}"
      done
    fi
  done <<<$lines
  rm $before $after $stdout
done

printf '\n%b%s\n' $color_Green "GENERATED:"
for file in ${generated_files[@]}; do
  printf '%b%s\n' $color_Default "$file"
done

printf '\n%b%s\n' $color_Default "${failed[@]}" >&2

printf '\n%b%s%b%s\n' $color_Yellow "NOTE: " $color_DarkYellow "You may have to re-run in case any script depended on a generated file."
printf '%b%s%b%s\n'   $color_Yellow "      " $color_DarkYellow "Once done, cd into upstream and run 'git clean --fdx .' to avoid duplicates."
