# hermit-toolchain

This repository contains scripts to build a GCC cross-compiler targetting the Rust-based unikernel [Hermit OS](https://github.com/hermit-os/kernel).

## Requirements

> [!WARNING]
> The build process has only been tested on **Linux** systems (using GCC). 
> To make the build process more portable, we recommend to use
> the Docker image defined [here](./Dockerfile).


The following system dependencies are required to build Hermit's toolchain on Linux:
* GNU Make, GNU Binutils, GCC
* Tools and libraries to build *binutils* and *GCC* (e.g. flex, bison, texinfo, MPFR library, GMP library, MPC library, ISL library)
* Rustup (Rust toolchain manager)

On Debian-based systems the packages can be installed by executing:
```
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
sudo apt-get install libmpfr-dev libmpc-dev libgmp-dev libisl-dev flex bison texinfo
```

## Building the Hermit's toolchain

To build the toolchain just call the script as follow:

```bash
./toolchain.sh x86_64-hermit
```

The first argument of the script specifies the target architecture.  The supported architectures are:
* x86_64-hermit
* aarch64-hermit
* riscv64-hermit

To create the toolchain, write access to the current directory is required. The installation (sysroot) is located in the subdirectory `prefix`.

Alternatively, you can use Docker to build the toolchain. The following command will build the toolchain for the riscv64 target:

```bash
docker build . --build-arg TARGET=riscv64-hermit -t hermit-toolchain
```
