#!/bin/bash

# Firebase Test Lab 用にアプリをビルドし、zipに固めるスクリプト

PROJECT_NAME="Fetchy"
SCHEME_NAME="Fetchy"
DESTINATION="platform=iOS Simulator,name=iPhone 17"
DERIVED_DATA_PATH="./DerivedData"

# 以前のビルドを削除
rm -rf "$DERIVED_DATA_PATH"

echo "Building for testing..."

# xcodebuild を実行して .xctestrun とビルド済みのアプリ/テストを生成
xcodebuild build-for-testing \
    -project "${PROJECT_NAME}.xcodeproj" \
    -scheme "${SCHEME_NAME}" \
    -destination "${DESTINATION}" \
    -derivedDataPath "${DERIVED_DATA_PATH}" \
    CODE_SIGNING_ALLOWED=NO

if [ $? -eq 0 ]; then
    echo "Build success!"
    
    # Test Lab は .xctestrun とアプリ本体を含む zip を受け取る
    # 通常、Debug-iphoneos 配下に生成される
    cd "${DERIVED_DATA_PATH}/Build/Products"
    zip -r ../../../FetchyTests.zip .
    cd -
    
    echo "Tests zipped to FetchyTests.zip"
    echo "Next: gcloud firebase test ios run --test FetchyTests.zip --device model=iphone13pro,version=15.7"
else
    echo "Build failed."
    exit 1
fi
