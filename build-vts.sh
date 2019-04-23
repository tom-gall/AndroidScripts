# Build Android
export JAVA_TOOL_OPTIONS=-Dfile.encoding=UTF8

export ANDROID_MANIFEST_URL="https://android.googlesource.com/platform/manifest"
#export MANIFEST_BRANCH="android-vts-9.0_r5"
export MANIFEST_BRANCH="android-vts-9.0_r8"
#export TOOLCHAIN="clang-r346389c"
export TOOLCHAIN="clang-r353983b"
export LUNCH_TARGET="aosp_arm64-userdebug"
export nproc=9
export latest=0

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
        -l | --latest )         export latest=1
                                ;;
        -h | --help )           usage
                                exit
                                ;;
        * )                     usage
                                exit 1
    esac
    shift
done

echo "Default Branch for vts build is $MANIFEST_BRANCH"

rm -rf out/
if [ "$skipdownloads" = "1" ]; then
#	repo sync -j"$(nproc)" -c
        echo skip
else
	repo init -u ${ANDROID_MANIFEST_URL} -b ${MANIFEST_BRANCH}
	repo sync -j"$(nproc)" -c

	mkdir -p pub
	repo manifest -r -o pub/pinned-manifest.xml

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

if [ "$latest" = "1" ]; then

   cd external/ltp
   git checkout master
   cd ../..
   cd system/core
   git cherry-pick c3d4e7226a74c3c4092480606ef07e0d30a2d42d
   cd ../..
fi

make -j"$(nproc)" vts
make -j"$(nproc)" adb


