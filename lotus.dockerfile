# build container stage
FROM golang:1.15 AS build-env
ENV RUSTFLAGS="-C target-cpu=native -g"
ENV FFI_BUILD_FROM_SOURCE=1
RUN apt-get update -y && \
    apt-get install sudo curl git mesa-opencl-icd ocl-icd-opencl-dev gcc git bzr jq pkg-config clang libhwloc-dev -y
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs -o rustup-init.sh && \
    chmod +x rustup-init.sh && \
    ./rustup-init.sh -y 
ENV PATH="$PATH:/root/.cargo/bin"
RUN git clone https://github.com/filecoin-project/lotus.git && \
    cd lotus && \
    git pull && \
    git fetch --tags && \
    latestTag=$(git describe --tags `git rev-list --tags --max-count=1`) && \
    #git checkout $latestTag && \
    git checkout v1.2.0 && \
    /bin/bash -c "source /root/.cargo/env" && \
    make clean deps build lotus-bench lotus-shed && \
    install -C ./lotus /usr/local/bin/lotus && \
    install -C ./lotus-miner /usr/local/bin/lotus-miner && \
    install -C ./lotus-worker /usr/local/bin/lotus-worker && \
    install -C ./lotus-bench /usr/local/bin/lotus-bench && \
    install -C ./lotus-shed /usr/local/bin/lotus-shed

# runtime container stage
FROM nvidia/opencl:runtime-ubuntu18.04 
ENV DEBIAN_FRONTEND=noninteractive
RUN apt update && \
    apt upgrade -y && \
    apt install jq -y
COPY --from=build-env /usr/local/bin/lotus /usr/local/bin/lotus
COPY --from=build-env /usr/local/bin/lotus-miner /usr/local/bin/lotus-miner
COPY --from=build-env /usr/local/bin/lotus-worker /usr/local/bin/lotus-worker
COPY --from=build-env /usr/local/bin/lotus-bench /usr/local/bin/lotus-bench
COPY --from=build-env /usr/local/bin/lotus-shed /usr/local/bin/lotus-shed
COPY --from=build-env /etc/ssl/certs /etc/ssl/certs
COPY LOTUS_VERSION /VERSION

COPY --from=build-env /lib/x86_64-linux-gnu/libdl.so.2 /lib/libdl.so.2
COPY --from=build-env /lib/x86_64-linux-gnu/libutil.so.1 /lib/libutil.so.1 
COPY --from=build-env /usr/lib/x86_64-linux-gnu/libOpenCL.so.1.0.0 /lib/libOpenCL.so.1
COPY --from=build-env /lib/x86_64-linux-gnu/librt.so.1 /lib/librt.so.1
COPY --from=build-env /lib/x86_64-linux-gnu/libgcc_s.so.1 /lib/libgcc_s.so.1
COPY --from=build-env /usr/lib/x86_64-linux-gnu/libhwloc.so.5 /lib/libhwloc.so.5
COPY --from=build-env /usr/lib/x86_64-linux-gnu/libnuma.so.1 /lib/libnuma.so.1
COPY --from=build-env /usr/lib/x86_64-linux-gnu/libltdl.so.7 /lib/libltdl.so.7

# API port
EXPOSE 1234/tcp

# P2P port
EXPOSE 1235/tcp

ENTRYPOINT ["/bin/entrypoint"]

