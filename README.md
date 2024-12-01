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
