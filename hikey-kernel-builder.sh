#!/bin/bash


usage()
{
	echo "usage: [-s] -v=[4.4|4.9|4.14] -a={AOSP|P|O-MR1} -t=clang-4679922"
	echo "-s = skip download"
	echo "-v = kernel version"
	echo "-a = android version"
	echo "-t = toolchain to use from prebuilts"
	echo "-m = mirror build, use premerge mirror"
}


set -ex

# export TOOLCHAIN="clang-4679922"
# export TOOLCHAIN="clang-r346389b"
export TOOLCHAIN="clang-r346389c"
export nproc=9
export ANDROID_VERSION="O-MR1"
export REFERENCE_BUILD_URL="http://testdata.linaro.org/lkft/aosp-stable/android-8.1.0_r29/"
export KERNEL_DIR="hikey-linaro"
export C_COMPILER="clang"
export usegcc="0"
# android-hikey-linaro-4.9
# android-hikey-linaro-4.14
# checkout -b android-hikey-linaro-4.9 origin/android-hikey-linaro-4.9
export KERNEL_BRANCH=android-hikey-linaro-4.9

while [ "$1" != "" ]; do
    case $1 in
        -v | --version )        shift
                                export VERSION=$1
                                ;;
        -a | --android )        shift
                                export ANDROID_VERSION=$1
                                ;;
        -t | --toolchain )      shift
                                toolchain=$1
                                ;;
        -s | --skipdownloads )  skipdownloads=1
                                ;;
        -m | --mirror-build )   mirrorbuild=1
                                ;;
        -g | --gcc )            usegcc=1
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
	if [ "$mirrorbuild" == "1" ]; then
		export UPSTREAM_KERNEL_BRANCH=mirror-android-4.9
	fi
elif [ "$VERSION" = "4.14" ]; then
	export KERNEL_BRANCH=android-hikey-linaro-4.14
        export ANDROID_KERNEL_CONFIG_DIR="android-4.14"
	if [ "$mirrorbuild" == "1" ]; then
		export UPSTREAM_KERNEL_BRANCH=mirror-android-4.14
	fi
elif [ "$VERSION" = "4.19" ]; then
	export KERNEL_BRANCH=android-hikey-linaro-4.19
        export ANDROID_KERNEL_CONFIG_DIR="android-4.19"
	export TOOLCHAIN="clang-r346389b"
	if [ "$mirrorbuild" == "1" ]; then
		export UPSTREAM_KERNEL_BRANCH=mirror-android-4.19
	fi
elif [ "$VERSION" = "4.4" ]; then
	export KERNEL_BRANCH=android-hikey-linaro-4.4
        export ANDROID_KERNEL_CONFIG_DIR="android-4.4"
	if [ "$mirrorbuild" == "1" ]; then
		export UPSTREAM_KERNEL_BRANCH=mirror-android-4.4
	fi
fi

# android-4.14  android-4.4  android-4.9  o  o-mr1 p 

if [ "$ANDROID_VERSION" = "O-MR1" ]; then
	export CONFIG_FRAGMENTS_PATH="o-mr1"
elif [ "$ANDROID_VERSION" = "P" ]; then
	export CONFIG_FRAGMENTS_PATH="p"
fi

if [ "$ANDROID_VERSION" = "O-MR1" ]; then
	export REFERENCE_BUILD_URL="http://testdata.linaro.org/lkft/aosp-stable/android-8.1.0_r29/"
elif [ "$ANDROID_VERSION" = "P" ]; then
#	export REFERENCE_BUILD_URL="https://snapshots.linaro.org/android/android-lcr-reference-hikey-p/latest?dl=/android/android-lcr-reference-hikey-p/latest/"
	export REFERENCE_BUILD_URL="http://people.linaro.org/~yongqin.liu/images/hikey/pie/"
else
	echo "need AOSP master ref"
fi

if [ "$skipdownloads" != "1" ]; then
	git clone --depth=1 https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9
	git clone --depth=1 https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86
fi

export PATH=${PWD}/aarch64-linux-android-4.9/bin/:${PWD}/linux-x86/${TOOLCHAIN}/bin/:${PATH}

if [ "$skipdownloads" != "1" ]; then 
        mkdir patches 
	cd patches
	wget -r -np -nH -R index.html --cut-dirs=2 http://people.linaro.org/~tom.gall/patches/
        cd ..   
fi

if [ "$skipdownloads" = "1" ]; then
	cd configs
	git pull
	cd ..
else
	git clone --depth=1 https://android.googlesource.com/kernel/configs

        if [ "$ANDROID_VERSION" = "O-MR1" ]; then 
                cd configs 
                patch -p1 < ../patches/ConfigsTurnOnQTA.patch
                cd ..   
        fi      
fi

if echo "$ANDROID_VERSION" | grep -i aosp ; then
    CMD="androidboot.console=ttyFIQ0 androidboot.hardware=hikey firmware_class.path=/vendor/firmware efi=noruntime printk.devkmsg=on buildvariant=userdebug  overlay_mgr.overlay_dt_entry=hardware_cfg_enable_android_fstab video=HDMI-A-1:1280x720@60"
elif [ "$VERSION" = "4.19" ]; then
    CMD="console=ttyAMA3,115200 androidboot.console=ttyAMA3 androidboot.hardware=hikey firmware_class.path=/vendor/firmware efi=noruntime printk.devkmsg=on buildvariant=userdebug overlay_mgr.overlay_dt_entry=hardware_cfg_enable_android_fstab initrd=0x11000000,0x17E28A"
    # this one works  CMD="console=ttyAMA3 androidboot.console=ttyAMA3 androidboot.hardware=hikey firmware_class.path=/vendor/firmware efi=noruntime printk.devkmsg=on buildvariant=userdebug"
    # CMD="console=ttyAMA3,115200 androidboot.console=ttyAMA3 androidboot.hardware=hikey firmware_class.path=/vendor/firmware efi=noruntime printk.devkmsg=on buildvariant=userdebug overlay_mgr.overlay_dt_entry=hardware_cfg_enable_android_fstab initrd=0x11000000,0x17E28A"

    # console=ttyAMA3,115200 androidboot.console=ttyAMA3 androidboot.hardware=hikey firmware_class.path=/vendor/firmware efi=noruntime  printk.devkmsg=on buildvariant=userdebug


elif [ "$ANDROID_VERSION" = "O-MR1" ]; then
    CMD="androidboot.console=ttyFIQ0 androidboot.hardware=hikey firmware_class.path=/system/etc/firmware efi=noruntime printk.devkmsg=on buildvariant=userdebug"
#    CMD="androidboot.console=ttyFIQ0 androidboot.hardware=hikey firmware_class.path=/system/etc/firmware efi=noruntime printk.devkmsg=on buildvariant=userdebug video=HDMI-A-1:1280x720@60"

elif [ "$ANDROID_VERSION" = "P" ]; then
    CMD="console=ttyAMA3,115200 androidboot.console=ttyAMA3 androidboot.hardware=hikey firmware_class.path=/vendor/firmware efi=noruntime printk.devkmsg=on buildvariant=userdebug overlay_mgr.overlay_dt_entry=hardware_cfg_enable_android_fstab initrd=0x11000000,0x17E28A"

else
	echo "What Andoid Version are you running?"
fi

if [ "$skipdownloads" = "1" ]; then
	cd "$KERNEL_DIR"
	if [ "$mirrorbuild" == "1" ]; then
   		git merge --no-edit remotes/origin/${UPSTREAM_KERNEL_BRANCH}
	fi
	make mrproper
#	git checkout master
#	git clean -fd
#	git pull
#	git checkout "$KERNEL_BRANCH"
#	git pull
	
else

	git clone https://android.googlesource.com/kernel/hikey-linaro
	cd "$KERNEL_DIR"
	git checkout -b "$KERNEL_BRANCH" origin/"$KERNEL_BRANCH"
	if [ "$mirrorbuild" == "1" ]; then
		cp arch/arm64/configs/hikey_defconfig ../.
	fi

	if [ "$mirrorbuild" == "1" ]; then
   		git merge --no-edit remotes/origin/${UPSTREAM_KERNEL_BRANCH}
		cp ../hikey_defconfig arch/arm64/configs/.
	fi

	if [ "$VERSION" = "4.9" ]; then
		if [ "$ANDROID_VERSION" = "O-MR1" ]; then
			git revert --no-edit bbab5cb8a5bd598af247d9eaf5a3033e7d12104e
		fi
 	fi
	if [ "$VERSION" = "4.14" ]; then
		if [ "$ANDROID_VERSION" = "O-MR1" ]; then
			git revert --no-edit 20ebc74d51a1542e4290abf5ac9e32b524f891d1
			git revert --no-edit d0455063e17c07841eb40b8e755f4c9241506de5
		fi
	fi

fi
cd ..

 
export CLANG_TRIPLE=aarch64-linux-gnu-
export CROSS_COMPILE=aarch64-linux-android-

cd "$KERNEL_DIR"
if [ "$ANDROID_VERSION" = "O-MR1" ]; then
	if [ "$VERSION" = "4.14" ]; then
		ARCH=arm64 scripts/kconfig/merge_config.sh arch/arm64/configs/hikey_defconfig ../configs/${ANDROID_KERNEL_CONFIG_DIR}/android-base.config ../configs/${ANDROID_KERNEL_CONFIG_DIR}/android-recommended-arm64.config
	else
		ARCH=arm64 scripts/kconfig/merge_config.sh arch/arm64/configs/hikey_defconfig ../configs/${CONFIG_FRAGMENTS_PATH}/${ANDROID_KERNEL_CONFIG_DIR}/android-base.config ../configs/${CONFIG_FRAGMENTS_PATH}/${ANDROID_KERNEL_CONFIG_DIR}/android-base-arm64.config
	fi
elif [ "$ANDROID_VERSION" = "P" ]; then
	if [ "$VERSION" = "4.19" ]; then
		ARCH=arm64 scripts/kconfig/merge_config.sh arch/arm64/configs/hikey_defconfig ../configs/${ANDROID_KERNEL_CONFIG_DIR}/android-base.config ../configs/${ANDROID_KERNEL_CONFIG_DIR}/android-recommended-arm64.config
	else
		ARCH=arm64 scripts/kconfig/merge_config.sh arch/arm64/configs/hikey_defconfig ../configs/${CONFIG_FRAGMENTS_PATH}/${ANDROID_KERNEL_CONFIG_DIR}/android-base.config ../configs/${CONFIG_FRAGMENTS_PATH}/${ANDROID_KERNEL_CONFIG_DIR}/android-base-arm64.config
	fi
else
	ARCH=arm64 scripts/kconfig/merge_config.sh arch/arm64/configs/hikey_defconfig ../configs/${CONFIG_FRAGMENTS_PATH}/${ANDROID_KERNEL_CONFIG_DIR}/android-base.config ../configs/${CONFIG_FRAGMENTS_PATH}/${ANDROID_KERNEL_CONFIG_DIR}/android-recommended-arm64.config
fi 

cp .config ../defconfig


if [ "$usegcc" = "1" ]; then
        export C_COMPILER=gcc
fi

if [ "$VERSION" = "4.19" ]; then
	make ARCH=arm64 CC="${C_COMPILER}" HOSTCC="${C_COMPILER}" -j$(nproc) Image
	make ARCH=arm64 CC="${C_COMPILER}" HOSTCC="${C_COMPILER}" -j$(nproc) dtbs
	# make ARCH=arm64 CC=clang HOSTCC=clang -j$(nproc) Image
	# make ARCH=arm64 CC=clang HOSTCC=clang -j$(nproc) dtbs
	cat arch/arm64/boot/Image arch/arm64/boot/dts/hisilicon/hi6220-hikey.dtb > arch/arm64/boot/Image-dtb
else
	make ARCH=arm64 CC=clang HOSTCC=clang -j$(nproc) Image-dtb
fi

cd ..
if [ "$skipdownloads" != "1" ]; then
	wget -q https://android-git.linaro.org/platform/system/core.git/plain/mkbootimg/mkbootimg.py -O mkbootimg
	wget -q ${REFERENCE_BUILD_URL}/ramdisk.img -O ramdisk.img
fi



if [ "$ANDROID_VERSION" = "O-MR1" ]; then
	python mkbootimg --kernel ${PWD}/"$KERNEL_DIR"/arch/arm64/boot/Image-dtb --cmdline "${CMD}" --os_version O --os_patch_level 2016-11-05 --ramdisk ./ramdisk.img --output boot.img
else
	python mkbootimg --kernel ${PWD}/"$KERNEL_DIR"/arch/arm64/boot/Image-dtb --cmdline "${CMD}" --os_version P --os_patch_level 2018-09-01 --ramdisk ./ramdisk.img --output boot.img
fi
#
