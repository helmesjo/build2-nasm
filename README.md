# nasm - NASM, the Netwide Assembler

This is a `build2` package repository for [`Netwide Assembler (NASM)`](https://repo.or.cz/w/nasm.git),
an asssembler for the x86 CPU architecture portable to nearly every modern
platform, and with code generation for many platforms old and new.

This file contains setup instructions and other details that are more
appropriate for development rather than consumption. If you want to use
`nasm` in your `build2`-based project, then instead see the accompanying
[`PACKAGE-README.md`](./nasm/PACKAGE-README.md) file.

The development setup for `nasm` uses the standard `bdep`-based workflow.
For example:

```
git clone https://github.com/build2-packaging/nasm
cd nasm

bdep init -C @gcc cc config.cxx=g++
bdep update
bdep test
```
## New Version

Upstream uses a mix of `perl` and `make` to configure the project, which
we naturally don't want to use here. The current `build2` package doesn't
contain this logic, but instead there is the root `./gen-files.sh` bash
script that will parse the `./upstream/Makefile.in`, extract all `perl`
command lines, convert to `bash` syntax (eg. `${VAR}` instead of `$(VAR)`)
then execute each line one by one.

This is the update-procedure:
```bash
$ cd ./upstream
$ git pull && git checkout nasm-X.Y.Z
$ cd ../nasm/nasm/gen

$ ../../../gen-files.sh ../../../upstream # generated files will automatically be copied
                                          # relative to the current working directory
$ git -C ../../../upstream clean -fdx . # clean upstream
$ git status  # see generated files
$ bdep update # make sure it builds
```

Redundant files are listed in the `./nasm/nasm/.gitignore`, but append this
list if there are new uneccessary files.
