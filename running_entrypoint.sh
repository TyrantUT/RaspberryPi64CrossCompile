#!/bin/bash

# vim: tabstop=4 shiftwidth=4 softtabstop=4
# -*- sh-basic-offset: 4 -*-

set -exuo pipefail

MAKE_CORES="$(expr $(nproc) + 2)"

function setupGit() {
	/usr/games/cowsay -f tux "Configuring github repo."

	ssh-keyscan github.com >> ~/.ssh/known_hosts
	ssh-agent bash -c 'ssh-add /root/.ssh/{Your Github RSA Key}; git clone {Your Github SSH Github Repo} /usr/local/build/{Qt Project Name}'
}

function fixReleaseBuild() {
	/usr/games/cowsay -f tux "Setting build to Release"

	pushd /usr/local/build/{Qt Project Name}
	sed -i '1s/^/@CONFIG += release@\n/' {Your Project File}.pro
	sed -i '36 i INCLUDE += /sysroot' {Your Project File}.pro
	rm pigpio.h
	rm pigpio.cpp
	popd
}

# Build pigpio. This is needed for the project linker since it's not available in 64 bit
function buildPigpio() {
	pushd /src

	wget https://github.com/joan2937/pigpio/archive/master.zip
	unzip master.zip
	rm master.zip

	pushd pigpio-master

		sed -i 's/^CROSS_PREFIX =/CROSS_PREFIX = aarch64-linux-gnu-/g' Makefile
		sed -i 's#prefix.*=.*/usr/local#prefix = /sysroot/usr#g' Makefile
		make -j"$MAKE_CORES"
		make install
		popd
	popd
}

function buildRelease() {
	/usr/games/cowsay -f tux "Qmake..."
	
	pushd /usr/local/build/{Qt Project Name}

	/src/pi4/qt5pi/bin/qmake
	make -j"$MAKE_CORES"

	cp {Qt Project Name} /built
	tar -zcvf {Qt Project Name}.tar.gz  {Qt Project Name}

	popd
}

export PATH=$PATH:/src/pi4/qt5pi
setupGit
fixReleaseBuild
buildPigpio
buildRelease

/usr/games/cowsay -f tux "{Qt Project Name} ready!"
