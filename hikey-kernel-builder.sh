#!/bin/bash


usage()
{
	echo "usage: -i [-s] -v=[4.4|4.9|4.14]"
	echo "-i = interactive mode"
	echo "-s = skip download"
	echo "-v = kernel version"
}


set -ex

export TOOLCHAIN="clang-4679922"
# export TOOLCHAIN="clang-r339409b"
export nproc=9
export ANDROID_VERSION="O-MR1"
export REFERENCE_BUILD="http://testdata.linaro.org/lkft/aosp-stable/android-8.1.0_r29/"
export KERNEL_DIR="hikey-linaro"
# android-hikey-linaro-4.9
# android-hikey-linaro-4.14
# checkout -b android-hikey-linaro-4.9 origin/android-hikey-linaro-4.9
export KERNEL_BRANCH=android-hikey-linaro-4.9

while [ "$1" != "" ]; do
    case $1 in
        -v | --version )        shift
                                VERSION=$1
                                ;;
        -i | --interactive )    interactive=1
                                ;;
        -t | --toolchain )      shift
                                toolchain=$1
                                ;;
        -s | --skipdownloads )  skipdownloads=1
                                ;;
        -h | --help )           usage
                                exit
                                ;;
        * )                     usage
                                exit 1
    esac
    shift
done

if [ "$VERSION" = "4.9" ]; then
	export KERNEL_BRANCH=android-hikey-linaro-4.9
        export ANDROID_KERNEL_CONFIG_DIR="android-4.9"
fi
if [ "$VERSION" = "4.14" ]; then
	export KERNEL_BRANCH=android-hikey-linaro-4.14
        export ANDROID_KERNEL_CONFIG_DIR="android-4.14"
fi
if [ "$VERSION" = "4.19" ]; then
	export KERNEL_BRANCH=android-hikey-linaro-4.19
        export ANDROID_KERNEL_CONFIG_DIR="android-4.19"
fi
if [ "$VERSION" = "4.4" ]; then
	export KERNEL_BRANCH=android-hikey-linaro-4.4
        export ANDROID_KERNEL_CONFIG_DIR="android-4.4"
fi

# android-4.14  android-4.4  android-4.9  o  o-mr1 p 

if [ "$ANDROID_VERSION" = "O-MR1" ]; then
	export CONFIG_FRAGMENTS_PATH="o-mr1"
fi
if [ "$ANDROID_VERSION" = "P" ]; then
	export CONFIG_FRAGMENTS_PATH="p"
fi


if [ "$skipdownloads" != "1" ]; then
	git clone --depth=1 https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9
	git clone --depth=1 https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86
fi

export PATH=${PWD}/aarch64-linux-android-4.9/bin/:${PWD}/linux-x86/${TOOLCHAIN}/bin/:${PATH}

if [ "$skipdownloads" = "1" ]; then 
        mkdir patches 
        wget -r -np -nH http://people.linaro.org/~tom.gall/patches/
        cd ..   
fi

if echo "${JOB_NAME}" | grep premerge; then
   git merge --no-edit remotes/origin/${UPSTREAM_KERNEL_BRANCH}
fi

if [ "$skipdownloads" = "1" ]; then
	cd configs
	git pull
	cd ..
else
	git clone --depth=1 https://android.googlesource.com/kernel/configs

        if [ "$ANDROID_VERSION" = "O-MR1" ]; then 
                cd configs 
                patch < ../configs/patches/ConfigsTurnOnQTA.patch
                cd ..   
        fi      
fi

if [ "$interactive" = "1" ]; then
	echo "interactive mode"
else
	export ANDROID_VERSION=$(echo $REFERENCE_BUILD_URL | awk -F"/" '{print$(NF-1)}')
fi

if echo "$ANDROID_VERSION" | grep -i aosp ; then
    CMD="androidboot.console=ttyFIQ0 androidboot.hardware=hikey firmware_class.path=/vendor/firmware efi=noruntime printk.devkmsg=on buildvariant=userdebug  overlay_mgr.overlay_dt_entry=hardware_cfg_enable_android_fstab video=HDMI-A-1:1280x720@60"
else
    CMD="androidboot.console=ttyFIQ0 androidboot.hardware=hikey firmware_class.path=/system/etc/firmware efi=noruntime printk.devkmsg=on buildvariant=userdebug video=HDMI-A-1:1280x720@60"
fi


if [ "$skipdownloads" = "1" ]; then
	cd "$KERNEL_DIR"
	make mrproper
	git checkout master
	git clean -fd
	git pull
	git checkout "$KERNEL_BRANCH"
	git pull
	
else
	git clone https://android.googlesource.com/kernel/hikey-linaro
	cd "$KERNEL_DIR"
	git checkout -b "$KERNEL_BRANCH" origin/"$KERNEL_BRANCH"
	if [ "$VERSION" = "4.9" ]; then
		git revert --no-edit bbab5cb8a5bd598af247d9eaf5a3033e7d12104e
	fi
	if [ "$VERSION" = "4.14" ]; then
		git revert --no-edit 20ebc74d51a1542e4290abf5ac9e32b524f891d1
		git revert --no-edit d0455063e17c07841eb40b8e755f4c9241506de5
	fi
fi
cd ..


export CLANG_TRIPLE=aarch64-linux-gnu-
export CROSS_COMPILE=aarch64-linux-android-

cd "$KERNEL_DIR"
if [ "$ANDROID_VERSION" = "O-MR1" ]; then
	if [ "$VERSION" == "4.14" ]; then
		ARCH=arm64 scripts/kconfig/merge_config.sh arch/arm64/configs/hikey_defconfig ../configs/${ANDROID_KERNEL_CONFIG_DIR}/android-base.config ../configs/${ANDROID_KERNEL_CONFIG_DIR}/android-base-arm64.config
	else
		ARCH=arm64 scripts/kconfig/merge_config.sh arch/arm64/configs/hikey_defconfig ../configs/${CONFIG_FRAGMENTS_PATH}/${ANDROID_KERNEL_CONFIG_DIR}/android-base.config ../configs/${CONFIG_FRAGMENTS_PATH}/${ANDROID_KERNEL_CONFIG_DIR}/android-base-arm64.config
	fi
else
	ARCH=arm64 scripts/kconfig/merge_config.sh arch/arm64/configs/hikey_defconfig ../configs/${CONFIG_FRAGMENTS_PATH}/${ANDROID_KERNEL_CONFIG_DIR}/android-base.config ../configs/${CONFIG_FRAGMENTS_PATH}/${ANDROID_KERNEL_CONFIG_DIR}/android-base-arm64.config
fi 

cp .config ../defconfig
make ARCH=arm64 CC=clang HOSTCC=clang -j$(nproc) Image-dtb

cd ..
wget -q https://android-git.linaro.org/platform/system/core.git/plain/mkbootimg/mkbootimg.py -O mkbootimg
wget -q ${REFERENCE_BUILD_URL}/ramdisk.img -O ramdisk.img

python mkbootimg \
  --kernel ${PWD}/"$KERNEL_DIR"/arch/arm64/boot/Image-dtb \
  --cmdline console="${CMD}" \
  --os_version O \
  --os_patch_level 2016-11-05 \
  --ramdisk ./ramdisk.img \
  --output boot.img
