#!/bin/bash

# vim: tabstop=4 shiftwidth=4 softtabstop=4
# -*- sh-basic-offset: 4 -*-

set -exuo pipefail

BUILD_TARGET=/build
SRC=/src

# Note: If changing the QT_BRANCH to a lower version, modify line 43 for the correct path
QT_BRANCH="5.15.8"
DEBIAN_VERSION=$(lsb_release -cs)
MAKE_CORES="$(expr $(nproc) + 2)"

mkdir -p "$BUILD_TARGET"
mkdir -p "$SRC"

/usr/games/cowsay -f tux 'Building QT version $QT_BRANCH.'

function patch_qt () {
    local QMAKE_FILE='/src/qt5/qtbase/mkspecs/devices/linux-rasp-pi4-v3d-g++/qmake.conf'
	
	echo "" > "$QMAKE_FILE"
	echo 'include(../common/linux_device_pre.conf)' >> "$QMAKE_FILE"
	echo 'QMAKE_INCDIR_OPENGL_ES2 = $${QMAKE_INCDIR_EGL}' >> "$QMAKE_FILE"
	echo 'QMAKE_LIBS_OPENGL_ES2   = $${VC_LINK_LINE} -lGLESv2' >> "$QMAKE_FILE"
	echo 'QMAKE_LIBS_EGL          = $${VC_LINK_LINE} -lEGL -lGLESv2' >> "$QMAKE_FILE"
	echo 'QMAKE_LIBDIR_BCM_HOST   = $$VC_LIBRARY_PATH' >> "$QMAKE_FILE"
	echo 'QMAKE_INCDIR_BCM_HOST   = $$VC_INCLUDE_PATH' >> "$QMAKE_FILE"
	echo 'QMAKE_LIBS_BCM_HOST     = -lbcm_host' >> "$QMAKE_FILE"
	echo 'QMAKE_CFLAGS            = -march=armv8-a' >> "$QMAKE_FILE"
	echo 'QMAKE_CXXFLAGS          = $$QMAKE_CFLAGS' >> "$QMAKE_FILE"
	echo 'EGLFS_DEVICE_INTEGRATION= eglfs_kms' >> "$QMAKE_FILE"
	echo 'load(qt_config)' >> "$QMAKE_FILE"
}

function fetch_qt5 () {
    pushd /src

    if [ ! -d "qt5" ]; then
		mkdir qt5
		wget -q --progress=bar:force:noscroll --show-progress https://download.qt.io/archive/qt/5.15/"$QT_BRANCH"/single/qt-everywhere-opensource-src-"$QT_BRANCH".tar.xz
		tar xf qt-everywhere-opensource-src-"$QT_BRANCH".tar.xz -C ./qt5 --strip-components=1
		wget -q --progress=bar:force:noscroll --show-progress https://download.qt.io/archive/qt/5.15/"$QT_BRANCH"/single/md5sums.txt
		md5sum --ignore-missing -c md5sums.txt
        rm qt-everywhere-opensource-src-"$QT_BRANCH".tar.xz
	fi
	
    popd	
}

function build_qt () {
    local SRC_DIR="/src/$1"

    if [ ! -f "$BUILD_TARGET/qt5-$QT_BRANCH-$DEBIAN_VERSION-$1.tar.gz" ]; then
        /usr/games/cowsay -f tux "Building QT for $1"

        fetch_qt5

        mkdir -p "$SRC_DIR"
        pushd "$SRC_DIR"

        patch_qt

        /src/qt5/configure \
            -device linux-rasp-pi4-v3d-g++ \
            -opengl es2 \
            -qpa eglfs \
            -confirm-license \
            -device-option CROSS_COMPILE=aarch64-linux-gnu- \
            -eglfs \
            -extprefix "$SRC_DIR/qt5pi" \
            -pkg-config \
            -qt-pcre \
            -no-pch \
            -evdev \
            -system-freetype \
            -fontconfig \
            -glib \
            -make libs \
            -no-compile-examples \
            -no-cups \
            -no-gtk \
            -no-use-gold-linker \
            -nomake examples \
            -nomake tests \
            -opensource \
            -prefix /usr/local/qt5pi \
            -release \
            -skip qtwebengine \
            -skip qtandroidextras \
            -skip qtgamepad \
            -skip qtlocation \
            -skip qtlottie \
            -skip qtmacextras \
            -skip qtpurchasing \
            -skip qtscxml \
            -skip qtsensors \
            -skip qtserialbus \
            -skip qtserialport \
            -skip qtspeech \
            -skip qttools \
            -skip qttranslations \
            -skip qtvirtualkeyboard \
            -skip qtwayland \
            -skip qtwebview \
            -skip qtwinextras \
            -skip wayland \
            -sysroot /sysroot \
            -no-feature-eglfs_brcm \
            -recheck \
            -platform linux-g++-64 \
            -L/sysroot/lib/aarch64-linux-gnu \
            -L/sysroot/usr/lib/aarch64-linux-gnu \
            -I/sysroot/usr/include/ \
            -L/sysroot/lib/mesa-diverted/aarch64-linux-gnu \
            -I/sysroot/usr/include/GLES2 \
            -I/sysroot/usr/include/GLES


        /usr/games/cowsay -f tux "Making Qt..."
        make -j"$MAKE_CORES"

        /usr/games/cowsay -f tux "Installing Qt..."
        make install

        pushd "$SRC_DIR"
        tar cfz "$BUILD_TARGET/qt5-$QT_BRANCH-$DEBIAN_VERSION-$1.tar.gz" qt5pi
        popd

        pushd "$BUILD_TARGET"
        sha256sum "qt5-$QT_BRANCH-$DEBIAN_VERSION-$1.tar.gz" > "qt5-$QT_BRANCH-$DEBIAN_VERSION-$1.tar.gz.sha256"
        popd
    else
        echo "QT Build already exist."q
    fi
}

# Fix relative paths for Raspberry Pi Sysroot
wget -q https://raw.githubusercontent.com/riscv/riscv-poky/master/scripts/sysroot-relativelinks.py -O /usr/local/bin/sysroot-relativelinks.py
chmod +x /usr/local/bin/sysroot-relativelinks.py
/usr/bin/python3 /usr/local/bin/sysroot-relativelinks.py /sysroot

build_qt "pi4"
