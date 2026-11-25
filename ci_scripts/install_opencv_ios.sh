#!/usr/bin/env bash
# Downloads the prebuilt iOS OpenCV that dartcv4 pins and points the iOS build at it.
# Without this, dartcv4 compiles OpenCV from source through the Xcode generator,
# which takes over 30 minutes on CI. Local builds keep compiling from source,
# because the prebuilt OpenCV has no simulator slice.
# Must be run from the root of the repository.
set -euxo pipefail

OPENCV_VERSION="4.12.0.0"
OPENCV_CHECKSUM="e249b2cc21b967c14cad0a08de5dfe989fc382aec40acde5a04f6d0cff537df2"
OPENCV_DIR="$HOME/opencv/$OPENCV_VERSION/ios-arm64"
PUBSPEC="idem/pubspec.yaml"

if [[ "$OSTYPE" != "darwin"* ]]; then
  echo "Unsupported operating system $OSTYPE"
  exit 1
fi

if [[ ! -f "$OPENCV_DIR/lib/cmake/opencv4/OpenCVConfig.cmake" ]]; then
  mkdir -p "$OPENCV_DIR"
  curl -sSfL -o opencv-ios.tar.gz "https://github.com/rainyl/opencv.full/releases/download/${OPENCV_VERSION}/libopencv-ios-arm64.tar.gz"
  shasum -a 256 -c - <<< "${OPENCV_CHECKSUM}  opencv-ios.tar.gz"
  tar xzf opencv-ios.tar.gz -C "$OPENCV_DIR"
  rm opencv-ios.tar.gz
fi

# opencv_dir must be absolute: dartcv4 hands it to CMake as is.
if grep -q "opencv_dir: $OPENCV_DIR" "$PUBSPEC"; then
  exit 0
fi
grep -q "^        prefer_android_cmake: true$" "$PUBSPEC"
sed -i '' "s#^        prefer_android_cmake: true\$#&\\
        opencv_dir: $OPENCV_DIR/lib/cmake/opencv4#" "$PUBSPEC"
grep -q "opencv_dir: $OPENCV_DIR" "$PUBSPEC"
