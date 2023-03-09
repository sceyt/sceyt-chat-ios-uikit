#!/bin/sh

#  build_sceyt.sh
#  SceytDemoApp
#
#  Created by Hovsep on 8/9/21.
#  Copyright © 2021 VarmTech LLC. All rights reserved.

set -e

DIR=`PWD`
ROOT=`PWD`
cd ${DIR}
## Check if a SceytChatUIKit/SceytChatUIKit.xcworkspace does not exist
if [ ! -d "${DIR}/SceytChatUIKit/SceytChatUIKit.xcodeproj" ]
then
    echo "❌ Workspace ${DIR}/SceytChatUIKit/SceytChatUIKit.xcodeproj DOES NOT exists."
    exit -1
fi

BUILD_CONF=$1
echo "ℹ️ Additional build conf: ${BUILD_CONF}"
## Package directory
PDIR=${ROOT}/xcframework

## Clean directory
rm -rf ${PDIR}
mkdir ${PDIR}
echo "ℹ️ Project dir: ${PDIR}"


FDIR=${PDIR}/frm
mkdir -p ${FDIR}

cd ${ROOT}/SceytChatUIKit
DIR=`PWD`

echo "ℹ️ START CREATING  SceytChatUIKit.framework FOR IOS simulator"
xcodebuild archive -project ${DIR}/SceytChatUIKit.xcodeproj -scheme SceytChatUIKit -archivePath ${FDIR}/SceytChatUIKit-iphonesimulator.xcarchive -sdk iphonesimulator ${BUILD_CONF} SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES -framework=/Users/hovsep/Documents/Projects/sceyt-ios/xcframework/SceytChat.xcframework/ios-x86_64-simulator/SceytChat.framework

echo "ℹ️ START CREATING  SceytChatUIKit.framework FOR IOS device"

xcodebuild archive -project ${DIR}/SceytChatUIKit.xcodeproj -scheme SceytChatUIKit -archivePath ${FDIR}/SceytChatUIKit-iphoneos.xcarchive -sdk iphoneos ${BUILD_CONF} SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES -framework=/Users/hovsep/Documents/Projects/sceyt-ios/xcframework/SceytChat.xcframework/ios-arm64/SceytChat.framework

echo "ℹ️ START CREATING  SceytChatUIKit.xcframework"
xcodebuild -create-xcframework -framework ${FDIR}/SceytChatUIKit-iphonesimulator.xcarchive/Products/Library/Frameworks/SceytChatUIKit.framework -framework ${FDIR}/SceytChatUIKit-iphoneos.xcarchive/Products/Library/Frameworks/SceytChatUIKit.framework -output ${PDIR}/SceytChatUIKit.xcframework

echo "ℹ️ Copy dSYMs"
cp -rf ${FDIR}/SceytChatUIKit-iphonesimulator.xcarchive/dSYMs ${PDIR}/SceytChatUIKit.xcframework/ios-x86_64-simulator/dSYMs
cp -rf ${FDIR}/SceytChatUIKit-iphoneos.xcarchive/dSYMs ${PDIR}/SceytChatUIKit.xcframework/ios-arm64/dSYMs

#echo "ℹ️ Copy Files"
#cp ${ROOT}/SceytChat-iOS/SceytChat-SDK/SDK_Files/SceytChat.podspec ${PDIR}/SceytChat.podspec
#cp ${ROOT}/SceytChat-iOS/SceytChat-SDK/SDK_Files/LICENSE ${PDIR}/LICENSE
#cp ${ROOT}/SceytChat-iOS/SceytChat-SDK/SDK_Files/README.md ${PDIR}/README.md

rm -rf ${LDIR}
rm -rf ${FDIR}

open -a finder ${PDIR}
