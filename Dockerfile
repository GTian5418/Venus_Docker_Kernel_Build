FROM ubuntu:22.04

RUN apt update -y && apt install -y \
    git wget curl tar zip unzip make binutils bison flex libssl-dev \
    bc libelf-dev gcc-aarch64-linux-gnu gcc-arm-linux-gnueabi \
    build-essential python3 python3-pip libncurses5-dev libncursesw5-dev \
    pkg-config ccache android-sdk-libsparse-utils vim \
    cpio kmod u-boot-tools xz-utils fdisk util-linux

WORKDIR /root

RUN wget https://android.googlesource.com/platform/system/tools/mkbootimg/+archive/refs/heads/main.tar.gz -O mkb.tar.gz && \
    mkdir mkbootimg && tar -zxvf mkb.tar.gz -C mkbootimg && rm mkb.tar.gz

RUN wget https://github.com/GTian5418/LKM_Tools/archive/refs/heads/master.zip && \
    unzip master.zip && mv LKM_Tools-master/*.sh ./ && chmod +x *.sh && rm master.zip

RUN wget https://github.com/GTian5418/android_kernel_qcom_sm8350/archive/refs/heads/lineage-23.1.zip -O kernel.zip && \
    unzip kernel.zip && mv android_kernel_qcom_sm8350-lineage-23.1 k && rm kernel.zip

RUN wget https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/main/clang-r547379.tar.gz -O clang.tar.gz && \
    mkdir clang && tar -zxvf clang.tar.gz -C clang && rm clang.tar.gz

RUN wget https://github.com/GTian5418/Venus_Docker_Kernel_Build/releases/download/los23.1/vendor_boot.img && \
    wget https://github.com/GTian5418/Venus_Docker_Kernel_Build/releases/download/los23.1/vendor_dlkm.img

RUN wget https://github.com/GTian5418/AnyKernel3/archive/refs/heads/venus.zip -O Anykernel3.zip && \
    unzip Anykernel3.zip && mv AnyKernel3-venus AnyKernel3 && rm Anykernel3.zip

RUN sed -i 's/static int selinux_enforcing_boot;/static int selinux_enforcing_boot = 0;/g' /root/k/security/selinux/hooks.c && \
    sed -i 's/selinux_enforcing_boot = enforcing ? 1 : 0;/selinux_enforcing_boot = 0;/g' /root/k/security/selinux/hooks.c && \
    sed -i 's/#define selinux_enforcing_boot 1/#define selinux_enforcing_boot 0/g' /root/k/security/selinux/hooks.c && \
    sed -i 's/return enforcing;/return 0;/g' /root/k/security/selinux/hooks.c

COPY defconfig /root/k/arch/arm64/configs/defconfig
COPY build.sh /root/build.sh
RUN chmod +x /root/build.sh

CMD ["/bin/bash"]
