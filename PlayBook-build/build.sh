#!/bin/bash
###########################################################################
# Setup environment                                                       #
###########################################################################
set -e

source bbndk.env

export BUILD_ROOT=`pwd`
pushd ../..
export SRC_TOP=`pwd`
popd

if [ ! -d "build" ]; then
  mkdir build
fi
pushd build

if [ ! -d "PlayBook" ]; then
  mkdir PlayBook
fi

if [ ! -d "linux" ]; then
  mkdir linux
fi

popd

export LINUX_BUILD=$BUILD_ROOT/build/linux
export PLAYBOOK_PREFIX=$BUILD_ROOT/build/PlayBook


###########################################################################
# Build Erlang                                                            #
###########################################################################
#echo "==> Building Erlang"
#pushd $SRC_TOP/Erlang-OTP/PlayBook-build
#./build.sh
#popd

###########################################################################
# Build Netscape Portable Runtime                                         #
###########################################################################
#pushd $LINUX_BUILD
#if [ ! -d "nspr" ]; then
#  mkdir nspr
#fi
#cd nspr
#if [ ! -d "release" ]; then
#  mkdir release
#fi
#cd release
#$SRC_TOP/nspr/mozilla/nsprpub/configure --build=i686-pc-linux-gnu --prefix=$LINUX_BUILD/nspr/release
#make -j8
#popd

###########################################################################
# Build ICU for Linux                                                     #
###########################################################################
#echo "==> Building ICU"
#pushd $SRC_TOP
#cp -Rf icu icu-linux
#if [ -d icu-linux ] ; then
#    rm -rf icu-linux
#fi
#cd icu-linux/dist/source
#if [ ! -d $LINUX_BUILD/icu ] ; then
#    mkdir -p $LINUX_BUILD/icu
#fi
#./configure --build=i686-pc-linux-gnu --prefix=$LINUX_BUILD/icu 
#make -j8
#make install
#popd

###########################################################################
# Build CURL for Linux                                                    #
###########################################################################
#echo "==> Building CURL"
#pushd $SRC_TOP
#if [ -d curl-linux ] ; then
#    rm -rf curl-linux
#fi
#cp -Rf curl curl-linux
#cd curl-linux
#if [ ! -d $LINUX_BUILD/curl ] ; then
#    mkdir -p $LINUX_BUILD/curl
#fi
#make all
#popd
#exit

###########################################################################
# Build SpiderMonkey 1.8.0                                                #   
###########################################################################
#echo "==> Building SpiderMonkey"
#pushd $SRC_TOP/SpiderMonkey/PlayBook-build
#./build.sh
#
## Make link to header files needed for compiling CouchDB
#mkdir -p $BUILD_ROOT/include/SpiderMonkey
#ln -s $SRC_TOP/SpiderMonkey/js/src $BUILD_ROOT/include/SpiderMonkey/js
#
#popd
###########################################################################
# Setup PlayBook Environment Variables                                    #
###########################################################################

# ensure required BBNDK env variables are set
: ${BBNDK_DIR:?"Error: BBNDK_DIR environment variable is not set."}
: ${BBNDK_HOST:?"Error: BBNDK_HOST environment variable is not set."}
: ${BBNDK_TARGET:?"Error: BBNDK_TARGET environment variable is not set."}

#set up env for cross-compiling for PlayBook
# Prepend path to curl-config and icu-config scripts (they are hand-edited for now)
export PATH=$BUILD_ROOT/config:$BBNDK_HOST/usr/bin:$PATH
export CC="$BBNDK_HOST/usr/bin/qcc -V4.4.2,gcc_ntoarmv7le_cpp "
export CFLAGS="-V4.4.2,gcc_ntoarmv7le_cpp -g "
export CPP="$BBNDK_HOST/usr/bin/qcc -V4.4.2,gcc_ntoarmv7le_cpp -E"
export LDFLAGS="-L$BBNDK_TARGET/armle-v7/usr/lib -L$BBNDK_TARGET/armle-v7/lib"
export CPPFLAGS="-D__QNXNTO__ -I$BBNDK_TARGET/usr/local/include"
export LD="$BBNDK_HOST/usr/bin/ntoarmv7-ld "
export RANLIB="$BBNDK_HOST/usr/bin/ntoarmv7-ranlib "

###########################################################################
# Build CouchDB 1.1.0                                                     #   
###########################################################################
echo "==> Building CouchDB"
#Paths to Linux binaries
export ERL_DIR=$SRC_TOP/Erlang-OTP/bootstrap/bin
export ERL=$ERL_DIR/erl
export ERLC=$ERL_DIR/erlc

#Paths to ARM binaries
#export ERL=$PLAYBOOK_PREFIX/Erlang-OTP/bin
#export ERLC=$ERL

pushd $SRC_TOP/CouchDB
./configure --build=i686-pc-linux-gnu --host=arm-unknown-nto-qnx6.5.0eabi --prefix=$PLAYBOOK_PREFIX/CouchDB \
--with-erlang=$SRC_TOP/Erlang-OTP/PlayBook-build/build/PlayBook/Erlang/usr/include --with-js-lib=$SRC_TOP/SpiderMonkey/PlayBook-build/build/PlayBook/lib \
--with-js-include=$BUILD_ROOT/include/SpiderMonkey/js
make
popd
