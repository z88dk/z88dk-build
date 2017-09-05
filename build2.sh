#!/bin/bash
#
# Script to produce an autobuild


stage=""
echo "#########################################################################"
echo
echo "Build starting"
echo
echo "#########################################################################"

function check_result
{
	ret=$?
	if [ $ret != 0 ]; then
		echo "*************************************************************************"
		echo
echo
		echo "Build failed, stage= " $stage
		echo
		echo "*************************************************************************"
		exit 1
	fi
}

function onexit
{
     result=$?
     cd $cwd/kits
	
     if [ $result == 0 ]; then
         if [ -f z88dk-$date-$revision.tgz ]; then
             ln -s z88dk-$date-$revision.tgz z88dk-latest.tgz
         fi 
         if [ -f z88dk-win32-$date-$revision.zip ]; then
             ln -s z88dk-win32-$date-$revision.zip z88dk-win32-latest.zip
         fi
         if [ -f z88dk-osx-$date-$revision.zip ]; then
             ln -s z88dk-osx-$date-$revision.zip z88dk-osx-latest.zip
         fi
     fi
echo "#########################################################################"
echo
echo "Deploying kits to nightly area"
echo
echo "#########################################################################"
     ls -l
    
     rsync -rl z88dk* $PUBLIC_DIRECTORY/
}


cwd=`pwd`
date=`date +%Y%m%d`

trap "onexit" EXIT

mkdir -p kits
rm -fr kits/*


# Create a cvs tarball
echo "#########################################################################"
echo
echo "Updating from guest git"
echo
echo "#########################################################################"
stage="Git update"
cd z88dk
git fetch
check_result
git pull
check_result

stage="Encoding version"
make setup
check_result

hash=`git rev-parse --short HEAD`
check_result
count=`git rev-list --count HEAD`
check_result
revision="$hash-$count"


echo "#########################################################################"
echo
echo "Creating src tarball"
echo
echo "#########################################################################"
stage="Tarball creation"
cd $cwd
tar czf kits/z88dk-src-$date-$revision.tgz --exclude-vcs z88dk 
check_result

echo "#########################################################################"
echo
echo "Starting native build"
echo
echo "#########################################################################"

stage="Native build"
# Create a build of libraries
rm -fr build
mkdir -p build
tar xzf kits/z88dk-src-$date-$revision.tgz -C build
check_result
cd build/z88dk
check_result
export CFLAGS="-g -O2"
export LDFLAGS=$CFLAGS
export CC=gcc
export ZCCCFG=`pwd`/lib/config/
export Z80_OZFILES=`pwd`/lib/
make
export PATH=`pwd`/bin:$PATH
make && make -C libsrc clean && make -C libsrc && make -C libsrc install && make -C libsrc/_DEVELOPMENT && make -C examples
check_result


# Back to where we where
cd $cwd


echo "#########################################################################"
echo
echo "Creating tarball with libraries"
echo
echo "#########################################################################"
stage="Tarball with libraries"
rm -fr build_with_libs
mkdir -p build_with_libs
tar xzf kits/z88dk-src-$date-$revision.tgz -C build_with_libs


stage="Copying libraries into tarball with libraries"
cd build_with_libs/z88dk
cp ../../build/z88dk/lib/clibs/*.lib lib/clibs
check_result
cp ../../build/z88dk/src/z80asm/z80asm-*.lib lib/
check_result
cp -r ../../build/z88dk/libsrc/_DEVELOPMENT/lib/sccz80 libsrc/_DEVELOPMENT/lib/
check_result
cp -r ../../build/z88dk/libsrc/_DEVELOPMENT/lib/sdcc* libsrc/_DEVELOPMENT/lib/
check_result
rsync -a ../../build/z88dk/libsrc/_DEVELOPMENT/target/ libsrc/_DEVELOPMENT/target/
check_result
stage="Creating tarball with libraries"
cd $cwd
cd build_with_libs
tar czf ../kits/z88dk-$date-$revision.tgz z88dk
check_result
cd $cwd

# Now create a mingw build

echo "#########################################################################"
echo
echo "Starting win32 build"
echo
echo "#########################################################################"

rm -fr win32
mkdir -p win32
stage="Win32 build"
# Extract the fresh tarball
tar xzf kits/z88dk-src-$date-$revision.tgz -C win32
check_result

# Build some mingw binaries

# Set some required variables
export CFLAGS="-g -O2"
export CC="i686-w64-mingw32-gcc"
export PREFIX="c:/z88dk/"
export CROSS=1
export EXESUFFIX=".exe"
export PKG_CONFIG_PATH=/usr/i686-w64-mingw32/lib/pkgconfig/
export XML2CONFIG=/usr/i686-w64-mingw32/bin/xml2-config

cp build/z88dk/src/z80asm/z80asm-*.lib win32/z88dk/src/z80asm/dev/z80asm_lib
check_result


# And build
cd win32/z88dk
check_result
make 
check_result
sed -i "s/COPYCMD.*/COPYCMD\t\tcopy/g" lib/config/*.cfg
sed -i s,/,\\\\,g lib/config/*.cfg
check_result
# Remove intermediates
stage="Cleaning intermediate files"
make clean-bins
check_result

# Copy dependencies
stage="Copying dependencies into win32 kit"
cp /usr/i686-w64-mingw32/bin/intl.dll bin/
check_result
#cp /usr/i686-w64-mingw32/bin/libglib-2.0-0.dll bin/
cp /usr/i686-w64-mingw32/bin/libxml2-2.dll bin/
check_result
cp /usr/i686-w64-mingw32/bin/zlib1.dll bin
check_result
cp /usr/i686-w64-mingw32/bin/libiconv-2.dll bin
check_result
cp /usr/i686-w64-mingw32/bin/liblzma-5.dll bin
check_result

# Copying sdcc
stage="Copying sdcc into win32 kit"
cp ../../bin/win32/* bin/
check_result

# Copy libs
stage="Copying libraries into win32 kit"
cp ../../build/z88dk/lib/clibs/*.lib lib/clibs
check_result
cp ../../build/z88dk/src/z80asm/z80asm-*.lib lib/
check_result
cp -r ../../build/z88dk/libsrc/_DEVELOPMENT/lib/sccz80 libsrc/_DEVELOPMENT/lib/
check_result
cp -r ../../build/z88dk/libsrc/_DEVELOPMENT/lib/sdcc* libsrc/_DEVELOPMENT/lib/
check_result
rsync -a ../../build/z88dk/libsrc/_DEVELOPMENT/target/ libsrc/_DEVELOPMENT/target/
check_result

cd ..
check_result
echo "#########################################################################"
echo
echo "Building win32 kit"
echo
echo "#########################################################################"
stage="win32 zip"
zip -qr ../kits/z88dk-win32-$date-$revision.zip z88dk
check_result



# Back to where we where
cd $cwd


# Now create a OS-X build

echo "#########################################################################"
echo
echo "Starting OS-X build"
echo
echo "#########################################################################"

rm -fr osx
mkdir -p osx
stage="OSX build"
# Extract the fresh tarball
tar xzf kits/z88dk-src-$date-$revision.tgz -C osx
check_result


# Build some mac binaries

# Set some required variables
export CFLAGS="-g -O2"
export CC="i386-apple-darwin15-cc"
export PREFIX="/usr/local/"
export EXESUFFIX=""
export CROSS=1
export PATH=/opt/osxcross/target/bin:$PATH
export XML2CONFIG=/opt/osxcross/target/bin/xml2-config

cp build/z88dk/lib/z80asm-*.lib osx/z88dk/src/z80asm/dev/z80asm_lib/
check_result

# And build
cd osx/z88dk
check_result
make 
check_result
# Remove intermediates
stage="Cleaning intermediate files"
make clean-bins
check_result

# Copy dependencies
stage="Copying dependencies into osx kit"
#cp /opt/gtk-macosx/lib/libglib-2.0.dylib bin/libglib-2.0.0.dylib
#check_result
#cp /opt/gtk-macosx/lib/libintl.8.dylib bin/
#check_result

stage="Copying sdcc into osx kit"
cp ../../bin/osx/* bin/
check_result

# Copy libs
stage="Copying libraries into osx kit"
cp ../../build/z88dk/lib/clibs/*.lib lib/clibs
check_result
cp ../../build/z88dk/src/z80asm/z80asm-*.lib lib/
check_result
cp -r  ../../build/z88dk/libsrc/_DEVELOPMENT/lib/sccz80 libsrc/_DEVELOPMENT/lib/
check_result
cp -r  ../../build/z88dk/libsrc/_DEVELOPMENT/lib/sdcc* libsrc/_DEVELOPMENT/lib/
check_result
rsync -a ../../build/z88dk/libsrc/_DEVELOPMENT/target/ libsrc/_DEVELOPMENT/target/
check_result

cd ..
check_result
echo "#########################################################################"
echo
echo "Building osx kit"
echo
echo "#########################################################################"
stage="osx zip"
zip -qr ../kits/z88dk-osx-$date-$revision.zip z88dk


cd $cwd/kits
rm z88dk-src-$date-$revision.tgz

echo "#########################################################################"
echo
echo "Everything built OK"
echo
echo "#########################################################################"
exit 0





