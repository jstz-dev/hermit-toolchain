#!/bin/bash

# script to build Hermit's toolchain
#
# $1 = specifies the target architecture
 
# exit when any command fails
set -e

SUPPORTED_TARGETS="x86_64-hermit aarch64-hermit riscv64-hermit"
TARGET=$1
if [ -z "$TARGET" ]; then
  echo "Usage: $0 <target>"
  exit 1
fi

if ! echo "$SUPPORTED_TARGETS" | grep -q "$TARGET"; then
  echo "Unsupported target: $TARGET"
  echo "Supported targets: $SUPPORTED_TARGETS"
  exit 1
fi

ARCH=
case "$TARGET" in
  x86_64-*)
    ARCH=x86_64
    ;;
  aarch64-*)
    ARCH=aarch64
    ;;
  riscv64-*)
    ARCH=riscv64
    ;;
  default)
    echo "Unable to parse a supported architecture from $TARGET"
    exit 1
    ;;
esac

NJOBS=-j"$(nproc)"

SCRIPTDIR="$(dirname "$0")"
HERE="$(cd "$SCRIPTDIR" && pwd)"

PREFIX="$HERE/prefix"
BUILDDIR="$HERE/build"
PATH=$PATH:$PREFIX/bin

export CFLAGS="-w"
export CXXFLAGS="-w"

# -O3 to enable optimizations
# -fPIE to enable position-independent code
# -fpermissive to downgrade the implicit declaration errors to warnings (occurs when compiling newlib with GCC 14)
export CFLAGS_FOR_TARGET="-O3 -fPIE -fpermissive"
export CXXFLAGS_FOR_TARGET="-O3 -fPIE -fpermissive"

case "$TARGET" in
  x86_64-*)
    export CFLAGS_FOR_TARGET+=" -m64"
    export CXXFLAGS_FOR_TARGET+=" -m64"        
    ;;
esac

echo "Build Hermit toolchain (target: $TARGET, arch: $ARCH, jobs: $NJOBS, prefix: $PREFIX)."

mkdir -p "$BUILDDIR"

echo
echo "*********************"
echo "* Building binutils *"
echo "*********************"
echo

if [ ! -d "$BUILDDIR/binutils" ]; then
mkdir -p "$BUILDDIR/binutils"
pushd "$BUILDDIR/binutils"
"$HERE/binutils/configure" \
    --target="$TARGET" \
    --prefix="$PREFIX" \
    --with-sysroot \
    --disable-werror \
    --disable-multilib \
    --disable-shared \
    --disable-nls \
    --disable-gdb \
    --disable-libdecnumber \
    --disable-readline \
    --disable-sim \
    --enable-tls \
    --enable-lto \
    --enable-plugin
make "$NJOBS" -O
make install
popd
fi

echo
echo "************************"
echo "* Building stage 1 GCC *"
echo "************************"
echo

if [ ! -d "$BUILDDIR/gcc-1" ]; then
mkdir -p "$BUILDDIR/gcc-1"
pushd "$BUILDDIR/gcc-1"
"$HERE/gcc/configure" \
    --target="$TARGET" \
    --prefix="$PREFIX" \
    --without-headers \
    --disable-multilib \
    --with-isl \
    --enable-languages=c,c++,lto \
    --disable-nls \
    --disable-shared \
    --disable-libssp \
    --disable-libgomp \
    --enable-threads=posix \
    --enable-tls \
    --enable-lto \
    --disable-symvers
make "$NJOBS" -O all-gcc
make install-gcc
popd
fi

echo
echo "**************************"
echo "* Building Hermit kernel *"
echo "**************************"
echo

mkdir -p "$BUILDDIR/hermit"

pushd "$HERE/hermit"
cargo run --package=xtask build --arch "$ARCH" --release --no-default-features --features pci,smp,acpi,newlib,tcp,dhcpv4 --target-dir "$BUILDDIR/hermit"
popd 

mkdir -p "$PREFIX/$TARGET/lib"
cp "$BUILDDIR/hermit/$ARCH/release/libhermit.a" "$PREFIX/$TARGET/lib/libhermit.a"

echo
echo "*****************************"
echo "* Building Newlib C library *"
echo "*****************************"
echo

if [ ! -d "$BUILDDIR/newlib" ]; then
mkdir -p "$BUILDDIR/newlib"
pushd "$BUILDDIR/newlib"
"$HERE/newlib/configure" \
    --target="$TARGET" \
    --prefix="$PREFIX" \
    --disable-shared \
    --disable-multilib \
    --enable-lto \
    --enable-newlib-io-c99-formats \
    --enable-newlib-multithread
make -O "$NJOBS"
make install
# Newlib overwrites crt0.o with the one from libgloss, 
# so we need to restore it manually
mv -f "$BUILDDIR/newlib/$TARGET/newlib/crt0.o" "$PREFIX/$TARGET/lib/crt0.o"
popd
fi

echo
echo "***************************************"
echo "* Building pthread-embedded C library *"
echo "***************************************"
echo

if [ ! -d "$BUILDDIR/pte" ]; then
cp -r "$HERE/pte" "$BUILDDIR"
pushd "$BUILDDIR/pte"
"$BUILDDIR/pte/configure" \
    --target="$TARGET" \
    --prefix="$PREFIX"
make -O "$NJOBS"
make install
popd
fi

echo
echo "************************"
echo "* Building stage 2 GCC *"
echo "************************"
echo

if [ ! -d "$BUILDDIR/gcc-2" ]; then
mkdir -p "$BUILDDIR/gcc-2"
pushd "$BUILDDIR/gcc-2"
"$HERE/gcc/configure" \
    --target="$TARGET" \
    --prefix="$PREFIX" \
    --with-newlib \
    --with-isl \
    --disable-multilib \
    --without-libatomic \
    --enable-languages=c,c++,lto \
    --disable-nls \
    --disable-shared \
    --enable-libssp \
    --enable-threads=posix \
    --enable-libgomp \
    --enable-tls \
    --enable-lto \
    --disable-symver
make -O "$NJOBS"
make install
popd
fi
