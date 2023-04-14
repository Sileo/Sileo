#!/bin/sh

rm -rf packages/

make clean package SILEO_PLATFORM=iphoneos-arm
make clean package SILEO_PLATFORM=iphoneos-arm64

make clean package SILEO_PLATFORM=iphoneos-arm NIGHTLY=1
make clean package SILEO_PLATFORM=iphoneos-arm64 NIGHTLY=1