#!/bin/bash

usage()
{
	echo "usage: [-s] -v=[4.4|4.9|4.14|v4.19] -a={AOSP|Q|P|O-MR1} -t=clang-r349610"
	echo "-s = skip download"
	echo "-v = kernel version"
	echo "-a = android version"
	echo "-t = toolchain to use from prebuilts"
	echo "-m = mirror build, use premerge mirror"
	echo "-c = continue build, no download, no reconfig, just build"
}


# export TOOLCHAIN="clang-4679922"
# export TOOLCHAIN="clang-r349610b"
# March clang
export TOOLCHAIN="clang-r353983d"
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
        -m | --mirror-build )   mirrorbuild=1
                                ;;
        -g | --gcc )            usegcc=1
                                ;;
        -c | --continue )       cont=1
				skipdownloads=1
                                ;;
        -i | --side )           side=1
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
	if [ "$ANDROID_VERSION" = "AOSP" ]; then
		export KERNEL_BRANCH=android-hikey-linaro-4.9
	else
		export KERNEL_BRANCH=android-4.9
	fi
        export ANDROID_KERNEL_CONFIG_DIR="android-4.9"
	if [ "$mirrorbuild" == "1" ]; then
		export UPSTREAM_KERNEL_BRANCH=mirror-android-4.9
	fi
elif [ "$VERSION" = "4.14" ]; then
	if [ "$ANDROID_VERSION" = "AOSP" ]; then
		export KERNEL_BRANCH=android-hikey-linaro-4.14
	else
		export KERNEL_BRANCH=android-4.14
	fi
        export ANDROID_KERNEL_CONFIG_DIR="android-4.14"
	if [ "$mirrorbuild" == "1" ]; then
		export UPSTREAM_KERNEL_BRANCH=mirror-android-4.14
	fi
elif [ "$VERSION" = "4.19" ]; then
	if [ "$ANDROID_VERSION" = "AOSP" ]; then
		export KERNEL_BRANCH=android-hikey-linaro-4.19
	else
		export KERNEL_BRANCH=android-4.19
	fi
#        export ANDROID_KERNEL_CONFIG_DIR="android-4.19"
#	export KERNEL_BRANCH=android-hikey-linaro-4.19
#        export ANDROID_KERNEL_CONFIG_DIR="android-4.19"
#	export PASTRY_BUILD=0
	if [ "$mirrorbuild" == "1" ]; then
		export UPSTREAM_KERNEL_BRANCH=mirror-android-4.19
	fi
elif [ "$VERSION" = "4.4" ]; then
	if [ "$ANDROID_VERSION" = "AOSP" ]; then
		export KERNEL_BRANCH=android-hikey-linaro-4.4
	else
		export KERNEL_BRANCH=android-4.4
	fi
        export ANDROID_KERNEL_CONFIG_DIR="android-4.4"
	if [ "$mirrorbuild" == "1" ]; then
		export UPSTREAM_KERNEL_BRANCH=mirror-android-4.4
	fi
elif [ "$VERSION" = "mainline" ]; then
	export KERNEL_BRANCH=android-mainline
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
	export REFERENCE_BUILD_URL="https://snapshots.linaro.org/android/android-lcr-reference-hikey-p/latest/"
#	export REFERENCE_BUILD_URL="http://people.linaro.org/~yongqin.liu/images/hikey/pie/"
elif [ "$ANDROID_VERSION" = "Q" ]; then
	export REFERENCE_BUILD_URL="https://snapshots.linaro.org/android/android-lcr-reference-hikey-p/latest/"
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


set -x

if [ "$skipdownloads" != "1" ]; then
#	wget -q https://android-git.linaro.org/platform/system/core.git/plain/mkbootimg/mkbootimg.py -O mkbootimg
#	chmod +x mkbootimg
	wget -q http://releases.linaro.org/android/reference-lcr/hikey/9.0-19.01/ramdisk.img
fi


if [ "$usegcc" = "1" ]; then 
	export PATH=/opt/gcc-linaro-7.3.1-2018.05-x86_64_aarch64-linux-gnu/bin:${PATH}
fi

if [ "$skipdownloads" != "1" ]; then 
        mkdir patches 
	cd patches
	wget -r -np -nH -R index.html --cut-dirs=2 http://people.linaro.org/~tom.gall/patches/
        cd ..   
fi

#if [ "$skipdownloads" != "1" ]; then 
#	git clone https://github.com/tom-gall/LinaroAndroidKernelConfigs.git   
#fi

if echo "$ANDROID_VERSION" | grep -i aosp ; then
    CMD="androidboot.console=ttyFIQ0 androidboot.hardware=hikey firmware_class.path=/vendor/firmware efi=noruntime printk.devkmsg=on buildvariant=userdebug  overlay_mgr.overlay_dt_entry=hardware_cfg_enable_android_fstab video=HDMI-A-1:1280x720@60"
elif [ "$ANDROID_VERSION" = "Q" ]; then
    CMD="console=ttyAMA3,115200 androidboot.console=ttyAMA3 androidboot.hardware=hikey firmware_class.path=/vendor/firmware efi=noruntime overlay_mgr.overlay_dt_entry=hardware_cfg_enable_android_fstab_v2 rootwait ro init=/init root=/dev/dm-0 dm=\"system none ro,0 1 android-verity 179:9\" androidboot.verifiedbootstate=orange printk.devkmsg=on buildvariant=userdebug veritykeyid=id:7e4333f9bba00adfe0ede979e28ed1920492b40f"
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
	echo "What Andoid Version are you planning to run?"
fi

if [ "$skipdownloads" = "1" ]; then
	cd "$KERNEL_DIR"
	if [ "$cont" = "1" ]; then
		# nothing to do
		echo "nothing to do"
	else
		if [ "$mirrorbuild" == "1" ]; then
   			git merge --no-edit remotes/origin/${UPSTREAM_KERNEL_BRANCH}
		fi
		make mrproper
	fi
#	git checkout master
#	git clean -fd
#	git pull
#	git checkout "$KERNEL_BRANCH"
#	git pull
	
else
	if [ "$side" = "1" ]; then
		cp -r ~/git/hikey-linaro .
		cd "$KERNEL_DIR"
	else

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

	### side
	fi

	if [ "$mirrorbuild" == "1" ]; then
		cp arch/arm64/configs/hikey_defconfig ../.
	fi

	if [ "$mirrorbuild" == "1" ]; then
   		git merge --no-edit remotes/origin/${UPSTREAM_KERNEL_BRANCH}
		cp ../hikey_defconfig arch/arm64/configs/.
		#patch -p1 < ~/ee7ead2.diff
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

if [ "$cont" != "1" ]; then
	# copy kernel config for any version besides AOSP
	if [ "$ANDROID_VERSION" = "O-MR1" ]; then
		cp ../LinaroAndroidKernelConfigs/${ANDROID_VERSION}/${VERSION}/hikey_defconfig .config
	elif [ "$ANDROID_VERSION" = "Q" ]; then
		make ARCH=arm64 CC="${C_COMPILER}" HOSTCC="${C_COMPILER}" hikey_defconfig
	elif [ "$VERSION" = "4.19" ]; then
		ARCH=arm64 scripts/kconfig/merge_config.sh arch/arm64/configs/hikey_defconfig ../configs/${ANDROID_KERNEL_CONFIG_DIR}/android-base.config ../configs/${ANDROID_KERNEL_CONFIG_DIR}/android-recommended-arm64.config
	elif [ "$ANDROID_VERSION" = "P" ]; then
		make ARCH=arm64 CC="${C_COMPILER}" HOSTCC="${C_COMPILER}" hikey_defconfig
#		cp arch/arm64/configs/hikey_defconfig .config
#		cp ../LinaroAndroidKernelConfigs/${ANDROID_VERSION}/${VERSION}/hikey_defconfig .config
	else # AOSP BUILD
		ARCH=arm64 scripts/kconfig/merge_config.sh arch/arm64/configs/hikey_defconfig ../configs/${CONFIG_FRAGMENTS_PATH}/${ANDROID_KERNEL_CONFIG_DIR}/android-base.config ../configs/${CONFIG_FRAGMENTS_PATH}/${ANDROID_KERNEL_CONFIG_DIR}/android-recommended-arm64.config
	fi
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

elif [ "$VERSION" = "mainline" ]; then
	make ARCH=arm64 CC="${C_COMPILER}" HOSTCC="${C_COMPILER}" -j$(nproc) Image
	make ARCH=arm64 CC="${C_COMPILER}" HOSTCC="${C_COMPILER}" -j$(nproc) dtbs
	cat arch/arm64/boot/Image arch/arm64/boot/dts/hisilicon/hi6220-hikey.dtb > arch/arm64/boot/Image-dtb
else
	make ARCH=arm64 CC=clang HOSTCC=clang -j$(nproc) Image-dtb
#	make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc) Image.gz-dtb
fi

cd ..

if [ "$ANDROID_VERSION" = "O-MR1" ]; then
	mkbootimg --kernel ${PWD}/"$KERNEL_DIR"/arch/arm64/boot/Image-dtb --cmdline "${CMD}" --os_version O --os_patch_level 2016-11-05 --ramdisk ./ramdisk.img --output boot.img
elif [ "$ANDROID_VERSION" = "Q" ]; then
	mkbootimg --kernel ${PWD}/"$KERNEL_DIR"/arch/arm64/boot/Image-dtb --cmdline "${CMD}" --os_version Q --os_patch_level 2019-03-05 --ramdisk ./ramdisk.img --output boot.img
else
#	mkbootimg --kernel ${PWD}/"$KERNEL_DIR"/arch/arm64/boot/Image.gz-dtb --cmdline "${CMD}" --os_version P --os_patch_level 2018-09-01 --ramdisk ./ramdisk.img --output boot.img
	mkbootimg --kernel ${PWD}/"$KERNEL_DIR"/arch/arm64/boot/Image-dtb --cmdline "${CMD}" --os_version P --os_patch_level 2018-09-01 --ramdisk ./ramdisk.img --output boot.img
fi
#
