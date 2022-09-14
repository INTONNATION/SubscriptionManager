FROM    ubuntu:focal

ENV     EVERDEV_VERSION=latest
ENV     EVERDEV_SOL_COMPILER_VERSION=0.64.0
ENV     EVERDEV_TVM_LINKER_VERSION=0.16.4
ENV     EVERDEV_TONOS_CLI_VERSION=0.27.34
ENV     RUSTUP_HOME=/opt/rust 
ENV     CARGO_HOME=/opt/cargo 
ENV     PATH=/opt/cargo/bin:$PATH
ENV     DEBIAN_FRONTEND=noninteractive

RUN     apt -y update &&\
        apt -y install make cmake curl build-essential openssl pkg-config libssl-dev libtool gcc-mingw-w64 jq git &&\
        curl -fsSL https://deb.nodesource.com/setup_18.x | sh &&\
        apt-get install -y nodejs &&\
        npm i -g everdev@$EVERDEV_VERSION &&\
        everdev sol set --compiler $EVERDEV_SOL_COMPILER_VERSION &&\
        everdev sol set --linker $EVERDEV_TVM_LINKER_VERSION &&\
        everdev tonos-cli set --version $EVERDEV_TONOS_CLI_VERSION
RUN     everdev sol set --compiler $EVERDEV_SOL_COMPILER_VERSION &&\
        everdev sol set --linker $EVERDEV_TVM_LINKER_VERSION &&\
        ln -s /root/.everdev/solidity/tvm_linker /usr/bin/tvm_linker
USER    root