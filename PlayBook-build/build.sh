#!/bin/bash
###########################################################################
# Setup environment                                                       #
###########################################################################
set -e

source bbndk.env

BUILD_ROOT=`pwd`
pushd ../..
SRC_TOP=`pwd`
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

LINUX_BUILD=$BUILD_ROOT/build/linux
PLAYBOOK_PREFIX=$BUILD_ROOT/build/PlayBook


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

# Make link to SpiderMonkey header files
mkdir -p $BUILD_ROOT/include/SpiderMonkey
if [ -e $BUILD_ROOT/include/SpiderMonkey/js ] ; then
    rm -f $BUILD_ROOT/include/SpiderMonkey/js
fi
ln -s $SRC_TOP/SpiderMonkey/js/src $BUILD_ROOT/include/SpiderMonkey/js

#Paths to Linux binaries
ERL_DIR=$SRC_TOP/Erlang-OTP
ERL_BIN_DIR=$ERL_DIR/bootstrap/bin
export ERL=$ERL_BIN_DIR/erl
export ERLC=$ERL_BIN_DIR/erlc
# Disable errors when compiling Erlang test files
export ERLC_FLAGS="-DNOTEST -DEUNIT_NOAUTO -I$ERL_DIR/lib"

fix_paths()
{
    FILE_DIR=`dirname $1`
    FILE_NAME=`basename $1`

    pushd $FILE_DIR
    cat $FILE_NAME | sed -e "s|$PLAYBOOK_PREFIX|/root|g" -e "s|$ERL_DIR/bootstrap|/root/Erlang|g" > $FILE_NAME.tmp
    mv $FILE_NAME.tmp $FILE_NAME
    popd
}

pushd $SRC_TOP/CouchDB

./bootstrap

# Use script modified for PlayBook 
cp configure.PlayBook configure

./configure --build=i686-pc-linux-gnu --host=arm-unknown-nto-qnx6.5.0eabi --prefix=$PLAYBOOK_PREFIX/CouchDB \
--with-erlang=$ERL_DIR/PlayBook-build/build/PlayBook/Erlang/usr/include \
--with-erlc-flags= $ERL_DIR/PlayBook-build/build/PlayBook/Erlang/usr/include \
--with-js-lib=$SRC_TOP/SpiderMonkey/PlayBook-build/build/PlayBook/lib \
--with-js-include=$BUILD_ROOT/include/SpiderMonkey/js
make
make install
popd

# Fix paths in couchdb script
pushd build/PlayBook/CouchDB/bin
cat couchdb | sed -e "s|$PLAYBOOK_PREFIX|\$INSTALL_PREFIX|g" -e "s|$ERL_DIR/bootstrap|\$ERLANG_DIR|g" > couchdb.tmp

# Insert defaults for install prefix and Erlang dirs
echo "INSTALL_PREFIX=/root" > couchdb
echo "ERLANG_DIR=/root/Erlang" >> couchdb

cat couchdb.tmp >> couchdb
rm couchdb.tmp
popd

pushd build/PlayBook/CouchDB
fix_paths ./bin/couchjs
fix_paths ./etc/couchdb/default.ini
fix_paths ./etc/logrotate.d/couchdb
fix_paths ./etc/init.d/couchdb
fix_paths ./lib/couchdb/bin/couchjs
fix_paths ./lib/couchdb/erlang/lib/couch-1.1.0/ebin/couch.app

chmod +x ./lib/couchdb/bin/couchjs
popd

