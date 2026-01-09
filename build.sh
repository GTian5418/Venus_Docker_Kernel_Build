#!/bin/bash
TOOLCHAIN=$(pwd)
KERNEL="$TOOLCHAIN/k"
OUT_DIR="$TOOLCHAIN/o"
MOD_SYNC="$TOOLCHAIN/modules_sync"
VB_UNPACK="$TOOLCHAIN/vb_unpack"
ANYKERNEL="$TOOLCHAIN/AnyKernel3"
DIST="$TOOLCHAIN/dist"
export PATH="$TOOLCHAIN/clang/bin:$PATH"
export USE_CCACHE=1
export CCACHE_DIR="$TOOLCHAIN/.ccache"
COMMON_ARGS="ARCH=arm64 LLVM=1 LLVM_IAS=1 CLANG_TRIPLE=aarch64-linux-gnu-"
mkdir -p "$DIST" "$MOD_SYNC" "$OUT_DIR" "$TOOLCHAIN/vd_stock" "$VB_UNPACK" \
         "$TOOLCHAIN/vd_new/lib/modules" "$TOOLCHAIN/vd_new" \
         "$TOOLCHAIN/o1" "$TOOLCHAIN/o2" \
         "$TOOLCHAIN/final_vb_modules" "$TOOLCHAIN/final_vd_modules"
echo ">>> Starting Kernel Build..."
make -C "$KERNEL" O="$OUT_DIR" $COMMON_ARGS defconfig
make -C "$KERNEL" O="$OUT_DIR" $COMMON_ARGS olddefconfig
make -j$(nproc --all) -C "$KERNEL" O="$OUT_DIR" $COMMON_ARGS Image modules
make -C "$KERNEL" O="$OUT_DIR" $COMMON_ARGS INSTALL_MOD_PATH="$MOD_SYNC" modules_install
REAL_VER=$(ls "$MOD_SYNC/lib/modules/" | head -n 1)
echo ">>> Detected Kernel Version: $REAL_VER"
echo ">>> Unpacking vendor_boot..."
python3 "$TOOLCHAIN/mkbootimg/unpack_bootimg.py" --boot_img vendor_boot.img --out "$VB_UNPACK"
cd "$VB_UNPACK"
mv vendor_ramdisk vendor_ramdisk.gz && gunzip vendor_ramdisk.gz
mkdir -p ramdisk_contents && cd ramdisk_contents
cpio -idmv < ../vendor_ramdisk
cd "$TOOLCHAIN"
python3 "$TOOLCHAIN/mkbootimg/unpack_bootimg.py" --boot_img boot.img --out "$TOOLCHAIN/boot"
cp boot/ramdisk magiskboot/
cd magiskboot
chmod +x magiskboot
./magiskboot decompress ramdisk ramdisk.cpio
./magiskboot cpio ramdisk.cpio "add 0750 init magiskinit" \
                             "mkdir 0750 overlay.d" \
                             "mkdir 0750 overlay.d/sbin" \
                             "add 0644 overlay.d/sbin/magisk.xz magisk.xz" \
                             "add 0644 overlay.d/sbin/stub.xz stub.xz" \
                             "add 0644 overlay.d/sbin/init-ld.xz init-ld.xz" \
                             "patch" \
                             "mkdir 000 .backup" \
                             "add 000 .backup/.magisk config"
./magiskboot compress=gzip ramdisk.cpio ramdisk_patched
./magiskboot cpio ramdisk.cpio test; echo $?
python3 "$TOOLCHAIN/mkbootimg/mkbootimg.py" \
    --kernel $OUT_DIR/arch/arm64/boot/Image \
    --ramdisk $TOOLCHAIN/magiskboot/ramdisk_patched \
    --header_version 3 \
    --os_version 16.0.0 \
    --os_patch_level 2025-12 \
    -o "$DIST/boot_docker_magisk_alpha.img"
truncate -s 192M "$DIST/boot_docker_magisk_alpha.img"
cd "$TOOLCHAIN"
cp boot/ramdisk magisk/
cd magisk
chmod +x magiskboot
./magiskboot decompress ramdisk ramdisk.cpio
./magiskboot cpio ramdisk.cpio "add 0750 init magiskinit" \
                             "mkdir 0750 overlay.d" \
                             "mkdir 0750 overlay.d/sbin" \
                             "add 0644 overlay.d/sbin/magisk.xz magisk.xz" \
                             "add 0644 overlay.d/sbin/stub.xz stub.xz" \
                             "add 0644 overlay.d/sbin/init-ld.xz init-ld.xz" \
                             "patch" \
                             "mkdir 000 .backup" \
                             "add 000 .backup/.magisk config"
./magiskboot compress=gzip ramdisk.cpio ramdisk_patched
./magiskboot cpio ramdisk.cpio test; echo $?
python3 "$TOOLCHAIN/mkbootimg/mkbootimg.py" \
    --kernel $OUT_DIR/arch/arm64/boot/Image \
    --ramdisk $TOOLCHAIN/magisk/ramdisk_patched \
    --header_version 3 \
    --os_version 16.0.0 \
    --os_patch_level 2025-12 \
    -o "$DIST/boot_docker_magisk.img"
truncate -s 192M "$DIST/boot_docker_magisk.img"
cd "$TOOLCHAIN"
echo ">>> Processing Modules..."
sudo [ -e /dev/loop0 ] || sudo mknod /dev/loop0 b 7 0 || true
sudo mount -o loop vendor_dlkm.img "$TOOLCHAIN/vd_stock"
"$TOOLCHAIN/01.module_dep.sh" "$VB_UNPACK/ramdisk_contents/lib/modules/modules.load.recovery" "$TOOLCHAIN/o1"
"$TOOLCHAIN/01.module_dep.sh" "$TOOLCHAIN/vd_stock/lib/modules/modules.dep" "$TOOLCHAIN/o2"
"$TOOLCHAIN/02.prepare_vendor_boot_modules.sh" "$TOOLCHAIN/o1/modules_list.txt" "$MOD_SYNC/lib/modules/$REAL_VER" \
          "$VB_UNPACK/ramdisk_contents/lib/modules/modules.load.recovery" \
          "$OUT_DIR/System.map" "$TOOLCHAIN/clang/bin/llvm-strip" "$TOOLCHAIN/final_vb_modules"
"$TOOLCHAIN/03.prepare_vendor_dlkm.sh" "$TOOLCHAIN/o2/modules_list.txt" "$MOD_SYNC/lib/modules/$REAL_VER" \
          "$TOOLCHAIN/vd_stock/lib/modules/modules.dep" \
          "$OUT_DIR/System.map" "$TOOLCHAIN/clang/bin/llvm-strip" \
          "$TOOLCHAIN/final_vd_modules" "$TOOLCHAIN/o1/modules_list.txt" ""
echo ">>> Building new vendor_dlkm..."
dd if=/dev/zero of=vendor_dlkm_new.img bs=1M count=64
mkfs.ext2 -F -L vendor_dlkm -b 4096 -N 3000 vendor_dlkm_new.img
sudo umount -l "$TOOLCHAIN/vd_new" || true
sudo mount -o loop vendor_dlkm_new.img "$TOOLCHAIN/vd_new"
sudo mkdir -p "$TOOLCHAIN/vd_new/lib/modules"
sudo cp -af "$TOOLCHAIN/final_vd_modules/"* "$TOOLCHAIN/vd_new/lib/modules/"
sudo cp -af "$TOOLCHAIN/vd_stock/etc" "$TOOLCHAIN/vd_new/"
sudo cp -n "$TOOLCHAIN/vd_stock/lib/modules/cs35l41_dlkm.ko" "$TOOLCHAIN/vd_new/lib/modules/" 2>/dev/null || true
sudo umount "$TOOLCHAIN/vd_new"
img2simg vendor_dlkm_new.img "$DIST/vendor_dlkm_docker.img"
echo ">>> Building new vendor_boot..."
cd "$VB_UNPACK/ramdisk_contents/lib/modules/"
rm -rf *
cp -af "$TOOLCHAIN/final_vb_modules/"* .
[ -f modules.load ] && mv modules.load modules.load.recovery || true
cd "$VB_UNPACK/ramdisk_contents/"
find . -mindepth 1 | sort | cpio -H newc -o --owner root:root | gzip -n -9 > "$VB_UNPACK/new_ramdisk.cpio.gz"
python3 "$TOOLCHAIN/mkbootimg/mkbootimg.py" \
    --header_version 3 \
    --vendor_boot "$DIST/vendor_boot_docker.img" \
    --vendor_ramdisk "$VB_UNPACK/new_ramdisk.cpio.gz" \
    --dtb "$VB_UNPACK/dtb" \
    --vendor_cmdline "androidboot.console=ttyMSM0 androidboot.hardware=qcom androidboot.memcg=1 androidboot.usbcontroller=a600000.dwc3 cgroup.memory=nokmem,nosocket console=ttyMSM0,115200n8 loop.max_part=7 msm_rtb.filter=0x237 service_locator.enable=1 swiotlb=0 pcie_ports=compat iptable_raw.raw_before_defrag=1 ip6table_raw.raw_before_defrag=1" \
    --base 0x00000000 --kernel_offset 0x00008000 --ramdisk_offset 0x01000000 \
    --tags_offset 0x00000100 --dtb_offset 0x01f00000 --pagesize 0x00001000
truncate -s 96M "$DIST/vendor_boot_docker.img"
echo ">>> Packaging AnyKernel3..."
cp "$OUT_DIR/arch/arm64/boot/Image" "$ANYKERNEL/"
cd "$ANYKERNEL"
zip -r9 "$DIST/Venus_Kernel_Docker.zip" ./* -x  "README.md" "LICENSE"
sudo umount "$TOOLCHAIN/vd_stock" || true
echo ">>> All Done! Files are in $DIST"
