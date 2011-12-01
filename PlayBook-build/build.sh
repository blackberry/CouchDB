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

error_exit()
{
    echo "Error: $1"
    exit
}

###########################################################################
# Build Erlang                                                            #
###########################################################################
echo "==> Building Erlang"
pushd $SRC_TOP/Erlang-OTP/PlayBook-build
./build.sh
popd

###########################################################################
# Build SpiderMonkey 1.8.0                                                #   
###########################################################################
echo "==> Building SpiderMonkey"
pushd $SRC_TOP/SpiderMonkey/PlayBook-build
./build.sh debug

popd

###########################################################################
# Setup PlayBook Environment Variables                                    #
# (Must be set here so that bootstrap builds work)                        # 
###########################################################################

# ensure required BBNDK env variables are set
: ${BBNDK_DIR:?"Error: BBNDK_DIR environment variable is not set."}
: ${BBNDK_HOST:?"Error: BBNDK_HOST environment variable is not set."}
: ${BBNDK_TARGET:?"Error: BBNDK_TARGET environment variable is not set."}

# Prepend path to curl-config and icu-config scripts (they are hand-edited for now)
export PATH=$BUILD_ROOT/config:$BBNDK_HOST/usr/bin:$PATH
export CC="$BBNDK_HOST/usr/bin/qcc -V4.4.2,gcc_ntoarmv7le_cpp "
export CFLAGS="-V4.4.2,gcc_ntoarmv7le_cpp -g "
export CPP="$BBNDK_HOST/usr/bin/qcc -V4.4.2,gcc_ntoarmv7le_cpp -E"
export LDFLAGS="-L$BBNDK_TARGET/armle-v7/usr/lib -L$BBNDK_TARGET/armle-v7/lib"
export CPPFLAGS="-D__QNXNTO__ -I$BBNDK_TARGET/usr/include"
export LD="$BBNDK_HOST/usr/bin/ntoarmv7-ld "
export RANLIB="$BBNDK_HOST/usr/bin/ntoarmv7-ranlib "

###########################################################################
# Build gettext                                                           #
###########################################################################
echo "==> Building gettext"
pushd $SRC_TOP/gettext
./configure --build=i686-pc-linux-gnu --host=arm-unknown-nto-qnx6.5.0eabi --prefix=$BUILD_ROOT/gettext \
--with-libiconv-prefix=$QNX_TARGET/armle-v7/usr/lib --with-libintl-prefix=$QNX_TARGET/armle-v7/usr/lib
make
popd

###########################################################################
# Build getopt                                                            #
###########################################################################
echo "==> Building getopt"
pushd $SRC_TOP/getopt
CPPFLAGS="$CPPFLAGS -D__QNXNTO__ -I$BBNDK_TARGET/usr/include -I$SRC_TOP/gettext/gettext-tools/intl" \
make
popd

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

pushd $SRC_TOP/CouchDB
./bootstrap

# Use script modified for PlayBook 
cp configure.PlayBook configure

./configure --build=i686-pc-linux-gnu --host=arm-unknown-nto-qnx6.5.0eabi --prefix=$BUILD_ROOT/CouchDB \
--with-erlang=$ERL_DIR/PlayBook-build/Erlang/usr/include \
--with-erlc-flags= $ERL_DIR/PlayBook-build/Erlang/usr/include \
--with-js-lib=$SRC_TOP/SpiderMonkey/PlayBook-build/lib \
--with-js-include=$BUILD_ROOT/include/SpiderMonkey/js
make
make install
popd

pushd CouchDB
# Remove kernel poll option from startup script 
cat ./bin/couchdb | sed -e 's| +K true||' > ./bin/couchdb.tmp
mv ./bin/couchdb.tmp ./bin/couchdb

# Copy modified kill script
cp $BUILD_ROOT/couchspawnkillable $BUILD_ROOT/CouchDB/lib/couchdb/erlang/lib/couch-1.1.0/priv/couchspawnkillable
popd

pushd $SRC_TOP

# So the installer can do a path replacement later on
pushd CouchDB/PlayBook-build
echo "BUILD_ROOT=$BUILD_ROOT" > install-vars.sh
echo "ERL_DIR=$ERL_DIR" >> install-vars.sh
popd

# Create installer
TAR_FILE=$BUILD_ROOT/couchdb-installer.tar
if [ -f $TAR_FILE ] ; then
    rm $TAR_FILE
fi
pushd CouchDB/PlayBook-build
tar cf $TAR_FILE install-vars.sh install.sh
popd
pushd Erlang-OTP/PlayBook-build
tar rf $TAR_FILE Erlang
popd
pushd CouchDB/PlayBook-build
tar rf $TAR_FILE CouchDB
popd

pushd $BUILD_ROOT
if [ ! -d lib ] ; then
    mkdir lib
fi
if [ ! -d bin ] ; then
    mkdir bin
fi
cp $SRC_TOP/SpiderMonkey/PlayBook-build/lib/* lib/
cp $SRC_TOP/getopt/getopt bin/
tar rf $TAR_FILE lib bin
popd

echo "CouchDB installer $TAR_FILE created. Copy and untar to desired directory on the PlayBook and run install.sh"

popd
