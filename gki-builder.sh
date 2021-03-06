#!/bin/bash


usage()
{
	echo "usage: [-s] -v=[4.4|4.9|4.14|v4.19] -a={AOSP|P} -t=clang-r349610"
	echo "-s = skip download"
	echo "-v = kernel version"
	echo "-a = android version"
	echo "-t = toolchain to use from prebuilts"
	echo "-c = continue build, no download, no reconfig, just build"
}


set -ex

# export TOOLCHAIN="clang-4679922"
export TOOLCHAIN="clang-r349610"
export nproc=9
export ANDROID_VERSION="P"
export PASTRY_BUILD=1
export REFERENCE_BUILD_URL="http://testdata.linaro.org/lkft/aosp-stable/android-8.1.0_r29/"
export KERNEL_DIR="hikey-linaro"
export C_COMPILER="clang"
export usegcc="0"
# Some works about trees
# android-hikey-linaro-4.4 android-hikey-linaro-4.9 android-hikey-linaro-4.14 android-hikey-linaro-4.19
# These are the blend of Common (aosp-mainline) + LTS for booting mainline + hikey support
# android-4.4-p, android-4.9-p, android-4.14-p represent the blend of Common for P and LTS but no hikey support
# android-4.4-p-hikey, android-4.9-p-hikey, android-4.14-p-hikey represent the blend of Common for P, LTS and hikey support
# checkout -b android-hikey-linaro-4.9 origin/android-hikey-linaro-4.9

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
        -g | --gcc )            usegcc=1
                                ;;
        -c | --continue )       cont=1
				skipdownloads=1
                                ;;
        -h | --help )           usage
                                exit
                                ;;
        * )                     usage
                                exit 1
    esac
    shift
done

export ROOTPATH=${PWD}

if [ "$VERSION" = "4.9" ]; then
	if [ "$ANDROID_VERSION" = "AOSP" ]; then
		export KERNEL_BRANCH=android-hikey-linaro-4.9
	else
		export KERNEL_BRANCH=android-4.9
	fi
        export ANDROID_KERNEL_CONFIG_DIR="android-4.9"
elif [ "$VERSION" = "4.14" ]; then
	if [ "$ANDROID_VERSION" = "AOSP" ]; then
		export KERNEL_BRANCH=android-hikey-linaro-4.14
	else
		export KERNEL_BRANCH=android-4.14
	fi
        export ANDROID_KERNEL_CONFIG_DIR="android-4.14"
elif [ "$VERSION" = "4.19" ]; then
	# 4.19 for now is not associated with any pastry
	export KERNEL_BRANCH=android-hikey-linaro-4.19
        export ANDROID_KERNEL_CONFIG_DIR="android-4.19"
	export PASTRY_BUILD=0
elif [ "$VERSION" = "4.4" ]; then
	if [ "$ANDROID_VERSION" = "AOSP" ]; then
		export KERNEL_BRANCH=android-hikey-linaro-4.4
	else
		export KERNEL_BRANCH=android-4.4
	fi
        export ANDROID_KERNEL_CONFIG_DIR="android-4.4"
fi

# android-4.14  android-4.4  android-4.9  p 

if [ "$ANDROID_VERSION" = "P" ]; then
	export CONFIG_FRAGMENTS_PATH="p"
fi

if [ "$ANDROID_VERSION" = "P" ]; then
#	export REFERENCE_BUILD_URL="https://snapshots.linaro.org/android/android-lcr-reference-hikey-p/latest?dl=/android/android-lcr-reference-hikey-p/latest/"
	export REFERENCE_BUILD_URL="http://people.linaro.org/~yongqin.liu/images/hikey/pie/"
else
	echo "need AOSP master ref"
	export PASTRY_BUILD=0
fi


echo "git checkout -b "$KERNEL_BRANCH"-"${ANDROID_VERSION,,}"-hikey origin/"$KERNEL_BRANCH"-"${ANDROID_VERSION,,}"-hikey "

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

if [ "$skipdownloads" != "1" ]; then 
	git clone https://github.com/tom-gall/LinaroAndroidKernelConfigs.git   
fi

if echo "$ANDROID_VERSION" | grep -i aosp ; then
    CMD="androidboot.console=ttyFIQ0 androidboot.hardware=hikey firmware_class.path=/vendor/firmware efi=noruntime printk.devkmsg=on buildvariant=userdebug  overlay_mgr.overlay_dt_entry=hardware_cfg_enable_android_fstab video=HDMI-A-1:1280x720@60"
elif [ "$VERSION" = "4.19" ]; then
    CMD="console=ttyAMA3,115200 androidboot.console=ttyAMA3 androidboot.hardware=hikey firmware_class.path=/vendor/firmware efi=noruntime printk.devkmsg=on buildvariant=userdebug overlay_mgr.overlay_dt_entry=hardware_cfg_enable_android_fstab initrd=0x11000000,0x17E28A"
    # this one works  CMD="console=ttyAMA3 androidboot.console=ttyAMA3 androidboot.hardware=hikey firmware_class.path=/vendor/firmware efi=noruntime printk.devkmsg=on buildvariant=userdebug"
    # CMD="console=ttyAMA3,115200 androidboot.console=ttyAMA3 androidboot.hardware=hikey firmware_class.path=/vendor/firmware efi=noruntime printk.devkmsg=on buildvariant=userdebug overlay_mgr.overlay_dt_entry=hardware_cfg_enable_android_fstab initrd=0x11000000,0x17E28A"

    # console=ttyAMA3,115200 androidboot.console=ttyAMA3 androidboot.hardware=hikey firmware_class.path=/vendor/firmware efi=noruntime  printk.devkmsg=on buildvariant=userdebug



elif [ "$ANDROID_VERSION" = "P" ]; then
    CMD="console=ttyAMA3,115200 androidboot.console=ttyAMA3 androidboot.hardware=hikey firmware_class.path=/vendor/firmware efi=noruntime printk.devkmsg=on buildvariant=userdebug overlay_mgr.overlay_dt_entry=hardware_cfg_enable_android_fstab initrd=0x11000000,0x17E28A"

else
	echo "What Andoid Version are you planning to run?"
fi

if [ "$skipdownloads" = "1" ]; then
	cd "$KERNEL_DIR"
	if [ "$cont" = "1" ]; then
		# nothing to do
		echo "nothing to do"
	else
		make mrproper
	fi
  	cd ..

#	git checkout master
#	git clean -fd
#	git pull
#	git checkout "$KERNEL_BRANCH"
#	git pull
	
else
	if [ "$cont" != "1" ]; then
		mkdir -p images
	fi
	# populate those here 
	#


	if [ "$PASTRY_BUILD" = "1" ]; then
		if [ "$VERSION" = "4.19" ]; then
			git clone https://android.googlesource.com/kernel/hikey-linaro
		else
			git clone https://github.com/tom-gall/hikey-linaro.git
		fi
	else
		git clone https://android.googlesource.com/kernel/hikey-linaro
	fi

	cd "$KERNEL_DIR"
	if [ "$PASTRY_BUILD" = "1" ]; then
		if [ "$VERSION" = "4.19" ]; then
			git checkout -b "$KERNEL_BRANCH" origin/"$KERNEL_BRANCH"
		else
			git checkout -b "$KERNEL_BRANCH"-"${ANDROID_VERSION,,}"-hikey origin/"$KERNEL_BRANCH"-"${ANDROID_VERSION,,}"-hikey
		fi
	else
		git checkout -b "$KERNEL_BRANCH" origin/"$KERNEL_BRANCH"
	fi
	cd ..
fi

 
export CLANG_TRIPLE=aarch64-linux-gnu-
export CROSS_COMPILE=aarch64-linux-android-

# setup vendor.img and ramdisk.img
cd images
	if [ "$cont" != "1" ]; then
		mkdir -p v
	fi
#	mkdir -p r
	simg2img vendor.img vendor.raw
	sudo mount -t ext4 -o loop vendor.raw v
	cd ..	


cd "$KERNEL_DIR"

if [ "$cont" != "1" ]; then
	# copy kernel config for any version besides AOSP
	if [ "$VERSION" = "4.19" ]; then
		# ARCH=arm64 scripts/kconfig/merge_config.sh arch/arm64/configs/hikey_defconfig ../configs/${CONFIG_FRAGMENTS_PATH}/${ANDROID_KERNEL_CONFIG_DIR}/android-base.config ../configs/${CONFIG_FRAGMENTS_PATH}/${ANDROID_KERNEL_CONFIG_DIR}/android-recommended-arm64.config
		cp arch/arm64/configs/hikey_defconfig .config
	elif [ "$ANDROID_VERSION" = "P" ]; then
		cp ../LinaroAndroidKernelConfigs/${ANDROID_VERSION}/${VERSION}/hikey_defconfig .config
	else # AOSP BUILD
		ARCH=arm64 scripts/kconfig/merge_config.sh arch/arm64/configs/hikey_defconfig ../configs/${CONFIG_FRAGMENTS_PATH}/${ANDROID_KERNEL_CONFIG_DIR}/android-base.config ../configs/${CONFIG_FRAGMENTS_PATH}/${ANDROID_KERNEL_CONFIG_DIR}/android-recommended-arm64.config
	fi
fi

cp .config ../defconfig


if [ "$usegcc" = "1" ]; then
        export C_COMPILER=gcc
fi

if [ "$VERSION" = "4.19" ]; then
	make ARCH=arm64 CC="${C_COMPILER}" HOSTCC="${C_COMPILER}" oldconfig  
	make ARCH=arm64 CC="${C_COMPILER}" HOSTCC="${C_COMPILER}" -j$(nproc) prepare
	make ARCH=arm64 CC="${C_COMPILER}" HOSTCC="${C_COMPILER}" -j$(nproc) Image
	make ARCH=arm64 CC="${C_COMPILER}" HOSTCC="${C_COMPILER}" -j$(nproc) dtbs
	# make ARCH=arm64 CC=clang HOSTCC=clang -j$(nproc) Image
	# make ARCH=arm64 CC=clang HOSTCC=clang -j$(nproc) dtbs
	cat arch/arm64/boot/Image arch/arm64/boot/dts/hisilicon/hi6220-hikey.dtb > arch/arm64/boot/Image-dtb
	make ARCH=arm64 CC=clang HOSTCC=clang -j$(nproc) modules
	sudo make ARCH=arm64 CC=clang HOSTCC=clang -j$(nproc) modules_install INSTALL_MOD_PATH=${ROOTPATH}/images/v/ V=1
else
	make ARCH=arm64 CC=clang HOSTCC=clang -j$(nproc) Image-dtb
	make ARCH=arm64 CC=clang HOSTCC=clang -j$(nproc) modules
	sudo make ARCH=arm64 CC=clang HOSTCC=clang -j$(nproc) modules_install INSTALL_MOD_PATH=${ROOTPATH}/images/v/ V=1
fi

cd ..
if [ "$skipdownloads" != "1" ]; then
	wget -q https://android-git.linaro.org/platform/system/core.git/plain/mkbootimg/mkbootimg.py -O mkbootimg
	wget -q ${REFERENCE_BUILD_URL}/ramdisk.img -O ramdisk.img
fi

# now package
	cd images
	# sudo ./make_ext4fs -s -l 1024M -a vendor new.vendor.img v/
	# sudo /lkft/tgall/960/out/soong/host/linux-x86/bin/make_f2fs -S 822083584  -l vendor vendor.new
	sudo umount ./v
	img2simg vendor.raw vendor.new.img

##	umount ./r
	cd ..

	python mkbootimg --kernel ${PWD}/"$KERNEL_DIR"/arch/arm64/boot/Image-dtb --cmdline "${CMD}" --os_version P --os_patch_level 2018-09-01 --ramdisk ./ramdisk.img --output boot.img
#

