# Build Android
export JAVA_TOOL_OPTIONS=-Dfile.encoding=UTF8

export ANDROID_MANIFEST_URL="https://android.googlesource.com/platform/manifest"
#export MANIFEST_BRANCH="android-cts-8.1_r6"
export MANIFEST_BRANCH="android-cts-8.1_r10"
export TOOLCHAIN="clang-4679922"
export PATCHSETS="cts-lkft"
export LUNCH_TARGET="aosp_arm64-userdebug"
export nproc=9


while [ "$1" != "" ]; do
    case $1 in
        -t | --toolchain )      shift
                                export TOOLCHAIN=$1
                                ;;
        -b | --branch)          shift
				export MANIFEST_BRANCH=$1
				;;
        -s | --skipdownloads )  export skipdownloads=1
                                ;;
        -h | --help )           usage
                                exit
                                ;;
        * )                     usage
                                exit 1
    esac
    shift
done

rm -rf out/
if [ "$skipdownloads" = "1" ]; then
#	repo sync -j"$(nproc)" -c
        echo skip
else
	repo init -u ${ANDROID_MANIFEST_URL} -b ${MANIFEST_BRANCH}
	repo sync -j"$(nproc)" -c

	mkdir -p pub
	repo manifest -r -o pub/pinned-manifest.xml

	if [ "$MANIFEST_BRANCH" = "android-cts-8.1_r10" ]; then
		wget https://people.linaro.org/~tom.gall/patches/AddLKFTCTSPlan.patch -O AddLKFTCTSPlan.patch
	elif [ "$MANIFEST_BRANCH" = "android-cts-9.0_r3" ]; then
		wget https://people.linaro.org/~tom.gall/patches/AddLKFTCTSPlanV9.patch -O AddLKFTCTSPlan.patch
	fi
	wget https://people.linaro.org/~tom.gall/patches/fcntl-p-fix.patch -O fcntl-p-fix.patch
	wget https://people.linaro.org/~tom.gall/patches/8a8d4ef.diff -O 8a8d4ef.diff
	wget https://people.linaro.org/~tom.gall/patches/2b957f4.diff -O 2b957f4.diff
        
        cd cts
	patch -p1 < ../AddLKFTCTSPlan.patch
	patch -p1 < ../2b957f4.diff
        cd ..
	cd bionic
	patch -p1 < ../fcntl-p-fix.patch
	cd ..
	cd system/sepolicy
	patch -p1 < ../../8a8d4ef.diff
	cd ../..

fi

#if [ -n "$PATCHSETS" ]; then
#    rm -rf android-patchsets
#    git clone --depth=1 https://android-git.linaro.org/git/android-patchsets.git
#    for i in $PATCHSETS; do
#        sh ./android-patchsets/$i
#    done
#fi


source build/envsetup.sh
lunch ${LUNCH_TARGET}
make -j"$(nproc)" cts
make -j"$(nproc)" adb
make -j"$(nproc)" aapt


