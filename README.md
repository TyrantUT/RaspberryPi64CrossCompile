# QT 5.15.8 Cross Compile for Raspberry 4 64 bit

## Raspberry Pi Sysroot
```
docker build buildx --platform=linux/arm64/v8-f Dockerfile.rpi -t rpi .
```

## Ubuntu Host
```
docker build -f Dockerfile.host -t host .
```

## Combine Sysroot and Host
```
docker build -f Dockerfile.building -t building .
```

## Create build and built directories on Host
### build contains the tar.gz of the cross compiled Qt 5.15.8
### built contains the compiled Qt binary for execution on the Raspberry Pi
```
mkdir build && mkdir built
```

## Build and Compile Qt 5.15.8
```
docker run \
	--mount src="$(pwd)/build",target=/build,type=bind \
	building
```
## Commit the building container to built image
### Get the building Container ID
```
docker ps -a
```
### Commit the image
```
docker commit {containerID} built
```
### Remove the old container
```
docker rm {containerID}
```

## Compile .pro file from Github
```
docker run \
	--rm \
	--mount type=bind,source="$(pwd)"/built,target=/built \
	running
```

## Raspberry Pi Prep
### Required packages
```
sudo apt install make gcc g++ unzip python3-pip libgles-dev libharfbuzz0b libmd4c0 libdouble-conversion3 libxcb-xinerama0 libmtdev1 libinput10 libts0 libxkbcommon0 mesa-utils weston libegl1 libegl1-mesa libgles2 libgl1-mesa-dri mesa-utils libopengl-dev
```

### Compile pigpio
```
wget https://github.com/joan2937/pigpio/archive/master.zip
unzip master.zip
cd pigpio-master
make -j4
sudo make install
```

### Extract cross compiled Qt 5.15.8 and set up ld
```
tar -xvf qt5-5.15.8-jammy-pi4.tar.gz -C /usr/local
echo /usr/local/qt5pi | sudo tee /etc/ld.so.conf.d/qt5pi.conf
sudo ldconfig
```

### Install libicu package - Note: May not be needed for your specific project, but was needed for mine
```
http://ports.ubuntu.com/pool/main/i/icu/libicu70_70.1-2_arm64.deb
sudo dpkg -i libicu70_70.1-2_arm64.deb
```
