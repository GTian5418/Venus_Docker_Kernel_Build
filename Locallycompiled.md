apt update -y && apt install -y \
    git wget curl tar zip unzip make binutils bison flex libssl-dev \
    bc libelf-dev gcc-aarch64-linux-gnu gcc-arm-linux-gnueabi \
    build-essential python3 python3-pip libncurses5-dev libncursesw5-dev \
    pkg-config ccache android-sdk-libsparse-utils vim \
    cpio kmod u-boot-tools xz-utils fdisk util-linux


TOOLCHAIN="/root"
KERNEL="$TOOLCHAIN/k"
OUT_DIR="$TOOLCHAIN/o"
MOD_SYNC="$TOOLCHAIN/modules_sync"
export PATH="$TOOLCHAIN/clang/bin:$PATH"
export USE_CCACHE=1
export CCACHE_DIR="$TOOLCHAIN/.ccache"
CLANG_TRIPLE_ARGS="CLANG_TRIPLE=aarch64-linux-gnu-"
COMMON_ARGS="ARCH=arm64 LLVM=1 LLVM_IAS=1 $CLANG_TRIPLE_ARGS"
rm -rf "$OUT_DIR" "$MOD_SYNC"
mkdir -p "$OUT_DIR" "$MOD_SYNC"
ccache -z
ccache -M 50G
make -C "$KERNEL" O="$OUT_DIR" $COMMON_ARGS \
    vendor/lahaina-qgki_defconfig \
    vendor/xiaomi_QGKI.config \
    vendor/venus_QGKI.config
make -C "$KERNEL" O="$OUT_DIR" $COMMON_ARGS olddefconfig
make -C "$KERNEL" O="$OUT_DIR" $COMMON_ARGS  menuconfig
make -C "$KERNEL" O="$OUT_DIR" $COMMON_ARGS  savedefconfig
make -j$(nproc --all) -C "$KERNEL" O="$OUT_DIR" $COMMON_ARGS Image modules
make -C "$KERNEL" O="$OUT_DIR" $COMMON_ARGS INSTALL_MOD_PATH="$MOD_SYNC" modules_install
#########################
python3 /root/mkbootimg/unpack_bootimg.py --boot_img vendor_boot.img --out /root/vb_unpack
##########################
boot magic: VNDRBOOT
vendor boot image header version: 3
page size: 0x00001000
kernel load address: 0x00008000
ramdisk load address: 0x01000000
vendor ramdisk size: 20893983
vendor command line args: androidboot.console=ttyMSM0 androidboot.hardware=qcom androidboot.memcg=1 androidboot.usbcontroller=a600000.dwc3 cgroup.memory=nokmem,nosocket console=ttyMSM0,115200n8 loop.max_part=7 msm_rtb.filter=0x237 service_locator.enable=1 swiotlb=0 pcie_ports=compat iptable_raw.raw_before_defrag=1 ip6table_raw.raw_before_defrag=1
kernel tags load address: 0x00000100
product name:
vendor boot image header size: 2112
dtb size: 8000046
dtb address: 0x0000000001f00000
################################
cd /root/vb_unpack
mv vendor_ramdisk vendor_ramdisk.gz && gunzip vendor_ramdisk.gz
mkdir -p ramdisk_contents && cd ramdisk_contents
cpio -idmv < ../vendor_ramdisk
cd /root
########
root@t:~/vb_unpack/ramdisk_contents# ls lib/modules/modules.load.recovery
/root/vb_unpack/ramdisk_contents/lib/modules/modules.load.recovery
###########

mkdir /root/vd_stock
mount -o loop vendor_dlkm.img /root/vd_stock


1.sh \
    /root/vb_unpack/ramdisk_contents/lib/modules/modules.load.recovery \
    /root/o1
1.sh \
    /root/vd_stock/lib/modules/modules.dep \
    /root/o2	
		
	
mkdir	/root/final_vb_modules	
2.sh \
    /root/o1/modules_list.txt \
    /root/modules_sync/lib/modules/5.4.302-qgki \
    /root/vb_unpack/ramdisk_contents/lib/modules/modules.load.recovery \
    /root/o/System.map \
    /root/clang/bin/llvm-strip \
    /root/final_vb_modules	
	
mkdir	/root/final_vd_modules
3.sh \
    "/root/o2/modules_list.txt" \
    "/root/modules_sync/lib/modules/5.4.302-qgki" \
    "/root/vd_stock/lib/modules/modules.dep" \
    "/root/o/System.map" \
    "/root/clang/bin/llvm-strip" \
    "/root/final_vd_modules" \
    "/root/o1/modules_list.txt" \
    ""		

cd /root
dd if=/dev/zero of=vendor_dlkm_new.img bs=1M count=40
mkfs.ext2 -L vendor_dlkm -b 4096 -N 2000 vendor_dlkm_new.img
mkdir vd_new
mount -o loop vendor_dlkm_new.img /root/vd_new
mkdir -p /root/vd_new/lib/modules

cp -af /root/final_vd_modules/* /root/vd_new/lib/modules/

cp -af /root/vd_stock/etc /root/vd_new/ 2>/dev/null

cp -n /root/vd_stock/lib/modules/cs35l41_dlkm.ko /root/vd_new/lib/modules/ 2>/dev/null

df -h /root/vd_new
umount /root/vd_new
img2simg vendor_dlkm_new.img vendor_dlkm_docker.img	
ls -lh vendor_dlkm_docker.img



cd /root/vb_unpack/ramdisk_contents/lib/modules/
rm -rf *
cp -af /root/final_vb_modules/* .
mv modules.load modules.load.recovery

cd /root/vb_unpack/ramdisk_contents/
find . | cpio -H newc -o | gzip -n -9 > ../new_ramdisk.cpio.gz
cd /root

python3 /root/mkbootimg/mkbootimg.py \
    --header_version 3 \
    --vendor_boot vendor_boot_docker.img \
    --vendor_ramdisk /root/vb_unpack/new_ramdisk.cpio.gz \
    --dtb /root/vb_unpack/dtb \
    --vendor_cmdline "androidboot.console=ttyMSM0 androidboot.hardware=qcom androidboot.memcg=1 androidboot.usbcontroller=a600000.dwc3 cgroup.memory=nokmem,nosocket console=ttyMSM0,115200n8 loop.max_part=7 msm_rtb.filter=0x237 service_locator.enable=1 swiotlb=0 pcie_ports=compat iptable_raw.raw_before_defrag=1 ip6table_raw.raw_before_defrag=1" \
    --base 0x00000000 \
    --kernel_offset 0x00008000 \
    --ramdisk_offset 0x01000000 \
    --tags_offset 0x00000100 \
    --dtb_offset 0x01f00000 \
    --pagesize 0x00001000
truncate -s 96M vendor_boot_docker.img	

