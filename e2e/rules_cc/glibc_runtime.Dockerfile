ARG BASE_IMAGE=ubuntu:24.04@sha256:18b33ff3829707f31ada654a963b9ee35f2e6f0241b964bd17a22a9b330cb63d
FROM ${BASE_IMAGE}
ARG GCC_VERSION=13
RUN apt-get -o Acquire::Check-Valid-Until=false update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    gcc-${GCC_VERSION} g++-${GCC_VERSION} libc6-dev binutils make gawk bison \
    python3 curl ca-certificates xz-utils texinfo
ENV CC=gcc-${GCC_VERSION}
ENV CXX=g++-${GCC_VERSION}
