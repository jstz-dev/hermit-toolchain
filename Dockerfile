FROM rust:buster as builder-env

RUN set -eux
RUN apt-get update
# gcc nativeBuildInputs
RUN apt-get install -y --no-install-recommends \
    bison \
    flex \
    libgmp-dev \
    libmpc-dev \
    libmpfr-dev \
    libisl-dev \
    texinfo
RUN rm -rf /var/lib/apt/lists/*
WORKDIR /root/
ADD ./binutils/ /root/binutils/
ADD ./hermit/ /root/hermit/
ADD ./gcc/ /root/gcc/
ADD ./newlib/ /root/newlib/
ADD ./pte/ /root/pte/
ADD ./toolchain.sh /root/toolchain.sh

FROM builder-env as builder

RUN set -eux
ARG TARGET=x86_64-hermit
RUN ./toolchain.sh $TARGET

FROM rust:buster as toolchain

RUN set -eux
COPY --from=builder /root/prefix /root/prefix
ENV PATH=/root/prefix/bin:$PATH \
    LD_LIBRARY_PATH=/root/prefix/lib:$LD_LIBRARY_PATH
