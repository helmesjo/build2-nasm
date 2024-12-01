# nasm - An executable

This is a `build2` package for the [`nasm`](https://www.nasm.us) & [`ndisasm`](https://www.nasm.us) executables,
an assembler & disassembler targeting the Intel
x86 series of processors, with portable source.

## Usage

To start using `nasm` and/or `ndisasm` in your project, add the following build-time
`depends` value to your `manifest`, adjusting the version constraint as
appropriate:

```
depends: * nasm ^2.16.3
```

Then import the executable in your `buildfile`:

```
import! [metadata] nasm    = nasm%exe{nasm}
import! [metadata] ndisasm = nasm%exe{ndisasm}
```


## Importable targets

This package provides the following importable targets:

```
exe{nasm}
exe{ndisasm}
```

The Netwide Assembler (`nasm`) is an assembler targeting the Intel x86
series of processors, with portable source.

The Netwide Disassembler (`ndisasm`) is a small companion program to the
Netwide Assembler, NASM.
