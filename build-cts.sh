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
        -i | --interactive )    interactive=1
                                ;;
        -t | --toolchain )      shift
                                export TOOLCHAIN=$1
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

	wget https://people.linaro.org/~tom.gall/patches/AddLKFTCTSPlan.patch -O AddLKFTCTSPlan.patch
	wget https://people.linaro.org/~tom.gall/patches/FixFcntlBuffer.patch -O FixFcntlBuffer.patch
        
        cd cts
	patch -p1 < AddLKFTCTSPlan.patch
        cd ..
	cd bionic
	patch -p1 < ../FixFcntlBuffer.patch
	cd ..

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
make adb

