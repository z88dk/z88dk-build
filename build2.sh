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

PERL5LIB=/home/build/perl5/lib/perl5
export PERL5LIB

PATH=/home/build/perl5/bin:$PATH
export PATH


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
git submodule update --init --recursive
check_result

stage="Encoding version"
rm -f src/config.h
make src/config.h
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
export PATH=`pwd`/bin:$PATH
./build.sh 
check_result
make -C libsrc/_DEVELOPMENT install-clean
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
rsync -a ../../build/z88dk/lib/clibs/ lib/clibs
check_result
cp ../../build/z88dk/src/z80asm/z88dk-z80asm.lib lib/
check_result
cp -r ../../build/z88dk/libsrc/_DEVELOPMENT/lib/sccz80 libsrc/_DEVELOPMENT/lib/
check_result
cp -r ../../build/z88dk/libsrc/_DEVELOPMENT/lib/sdcc* libsrc/_DEVELOPMENT/lib/
check_result
rsync -a ../../build/z88dk/include/ include/
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

# Copying sdcc
stage="Copying sdcc + libs into win32 kit"
cp bin/win32/* win32/z88dk/bin/
check_result

# Build some mingw binaries

stage="Build windows binaries"
# Set some required variables
export CFLAGS="-g -O2"
export CC="x86_64-w64-mingw32-gcc"
export CXX="x86_64-w64-mingw32-g++"
export PREFIX="c:/z88dk/"
export CROSS=1
export EXESUFFIX=".exe"
export PKG_CONFIG_PATH=/usr/x86_64-w64-mingw32/lib/pkgconfig/
export XML2CONFIG=/usr/x86_64-w64-mingw32/bin/xml2-config
echo "#undef PREFIX" >> win32/z88dk/src/config.h
echo "#define PREFIX \"$PREFIX\"" >> win32/z88dk/src/config.h

cp build/z88dk/src/z80asm/z88dk-z80asm.lib win32/z88dk/src/z80asm/dev/z80asm_lib
check_result


# And build
cd win32/z88dk
check_result
touch bin/zsdcc.exe
make 
check_result
sed -i "s/COPYCMD.*/COPYCMD\t\tcopy/g" lib/config/*.cfg
sed -i s,/,\\\\,g lib/config/*.cfg
check_result
# Remove intermediates
stage="Cleaning intermediate files"
make bins-clean
check_result

stage="Build i686 windows binaries"
cp ../../build/z88dk/src/z80asm/z88dk-z80asm.lib src/z80asm/dev/z80asm_lib
check_result
# Now, build the i686 versions
mv bin bin.x86-64
mkdir bin
export CFLAGS="-g -O2"
export CC="i686-w64-mingw32-gcc"
export CXX="i686-w64-mingw32-g++"
export PREFIX="c:/z88dk/"
export CROSS=1
export EXESUFFIX=".exe"
export PKG_CONFIG_PATH=/usr/i686-w64-mingw32/lib/pkgconfig/
export XML2CONFIG=/usr/i686-w64-mingw32/bin/xml2-config
make 
check_result

stage="Cleaning intermediate files"
make bins-clean
check_result

stage="Copying i686 sdcc + libs into win32 kit"
cp ../../bin/win32.i686/* bin/
check_result

# And now rearrange the binary folds
mv bin bin.x86
mv bin.x86-64 bin




# Copy libs
stage="Copying libraries into win32 kit"
rsync -a ../../build/z88dk/lib/clibs/ lib/clibs
check_result
cp ../../build/z88dk/src/z80asm/z88dk-z80asm.lib lib/
check_result
cp -r ../../build/z88dk/libsrc/_DEVELOPMENT/lib/sccz80 libsrc/_DEVELOPMENT/lib/
check_result
cp -r ../../build/z88dk/libsrc/_DEVELOPMENT/lib/sdcc* libsrc/_DEVELOPMENT/lib/
check_result
rsync -a ../../build/z88dk/include/ include/
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
zip -qr9 ../kits/z88dk-win32-$date-$revision.zip z88dk
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

stage="Copying sdcc into osx kit"
cp bin/osx/* osx/z88dk/bin/
check_result

# Build some mac binaries

stage="Build MacOS binaries"
# Set some required variables
export CFLAGS="-g -O2 -arch x86_64 -arch arm64 -mmacosx-version-min=10.10"
export CXX_FLAGS="-g -O2 -arch x86_64 -arch arm64 -mmacosx-version-min=10.10 -I/opt/osxcross/macports/pkgs/opt/local/libexec/boost/1.76/include"
export CXXFLAGS=$CXX_FLAGS
export LDFLAGS="-g -O2 -arch x86_64 -arch arm64 -L/opt/osxcross/macports/pkgs/opt/local/libexec/boost/1.76/lib"
export CC="x86_64-apple-darwin20.2-cc"
export CXX="x86_64-apple-darwin20.2-c++"
export PREFIX="/usr/local/"
export EXESUFFIX=""
export CROSS=1
export PATH=/opt/osxcross/bin:$PATH
export XML2CONFIG=/opt/osxcross/SDK/MacOSX11.1.sdk/usr/bin/xml2-config
export USE_BOOST_FILESYSTEM=1

cp build/z88dk/lib/z88dk-z80asm.lib osx/z88dk/src/z80asm/dev/z80asm_lib/
check_result

# And build
cd osx/z88dk
check_result
make 
check_result
# Remove intermediates
stage="Cleaning intermediate files"
make bins-clean
check_result

stage="Copying dependencies into osx kit"
#cp /opt/gtk-macosx/lib/libglib-2.0.dylib bin/libglib-2.0.0.dylib
#check_result
#cp /opt/gtk-macosx/lib/libintl.8.dylib bin/
#check_result

stage="Copying sdcc into osx kit"
cp ../../bin/osx/* bin/
check_result

# Remove z80asm or codesigning is a bit weird
rm -f bin/z80asm

stage="Code signing for MacOS"
for file in `file bin/* | grep Mach-O | awk '{print $1}' | sed s,:,,`; do
 echo "Code signing $file"
 rcodesign sign --p12-file $HOME/certs/domdev.p12 --p12-password-file $HOME/certs/password --code-signature-flags runtime $file
 check_result
done

# Copy dependencies

# Copy libs
stage="Copying libraries into osx kit"
cp ../../build/z88dk/lib/clibs/*.lib lib/clibs
check_result
cp ../../build/z88dk/src/z80asm/z88dk-z80asm.lib lib/
check_result
cp -r  ../../build/z88dk/libsrc/_DEVELOPMENT/lib/sccz80 libsrc/_DEVELOPMENT/lib/
check_result
cp -r  ../../build/z88dk/libsrc/_DEVELOPMENT/lib/sdcc* libsrc/_DEVELOPMENT/lib/
check_result
rsync -a ../../build/z88dk/include/ include/
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
zip -qr9 ../kits/z88dk-osx-$date-$revision.zip z88dk

echo "#########################################################################"
echo
echo "Notarising osx kit"
echo
echo "#########################################################################"
stage="notarise"
rcodesign notary-submit --api-key-path ~/certs/appstore.json --wait ../kits/z88dk-osx-$date-$revision.zip


cd $cwd/kits
rm z88dk-src-$date-$revision.tgz

echo "#########################################################################"
echo
echo "Everything built OK"
echo
echo "#########################################################################"
exit 0





