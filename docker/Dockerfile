FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# 1. Unminimize (Cached layer)
RUN apt-get update && yes | unminimize

# 2. Install Tools
RUN apt-get update && apt-get install -y \
    autoconf \
    bash-completion \
    bc \
    binfmt-support \
    bison \
    build-essential \
    clang \
    cmake \
    cpio \
    curl \
    device-tree-compiler \
    dialog \
    dos2unix \
    expect \
    fakeroot \
    file \
    flex \
    g++ \
    g++-multilib \
    gawk \
    gcc \
    gcc-multilib \
    gettext \
    git \
    gperf \
    iputils-ping \
    jq \
    libelf-dev \
    libncurses5-dev \
    libssl-dev \
    lz4 \
    make \
    man-db \
    mc \
    module-assistant \
    nano \
    net-tools \
    openssh-client \
    openssh-server \
    openssl \
    parted \
    passwd \
    pkg-config \
    procps \
    python-is-python3 \
    python3 \
    python3-pip \
    python3-setuptools \
    qemu-user-static \
    rsync \
    screen \
    ssh \
    sudo \
    swig \
    texinfo \
    tmux \
    unzip \
    vim \
    wget \
    zlib1g-dev \
    zstd \
    && rm -rf /var/lib/apt/lists/*

# 3. Create 'builder' user
RUN useradd -m -s /bin/bash -G sudo builder

# 4. Configure Passwordless Sudo
RUN echo "builder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# 5. Setup Entrypoint Script
COPY start.sh /usr/local/bin/start.sh
# Fix line endings and make executable
RUN dos2unix /usr/local/bin/start.sh && \
    chmod +x /usr/local/bin/start.sh

# 6. Final Setup
USER builder
WORKDIR /work
ENTRYPOINT ["/usr/local/bin/start.sh"]
CMD ["bash"]
