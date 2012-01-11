#!/bin/bash
###########################################################################
# Setup environment                                                       #
###########################################################################
set -e

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
./build.sh
popd

###########################################################################
# Setup PlayBook Environment Variables                                    #
# (Must be set here so that bootstrap builds work)                        # 
###########################################################################

# ensure required BBNDK env variables are set
: ${QNX_HOST:?"Error: QNX_HOST environment variable is not set."}
: ${QNX_TARGET:?"Error: QNX_TARGET environment variable is not set."}

# Prepend path to curl-config and icu-config scripts (they are hand-edited for now)
export PATH=$BUILD_ROOT/config:$QNX_HOST/usr/bin:$PATH
export CC="$QNX_HOST/usr/bin/qcc -V4.4.2,gcc_ntoarmv7le_cpp "
export CFLAGS="-V4.4.2,gcc_ntoarmv7le_cpp -g "
export CPP="$QNX_HOST/usr/bin/qcc -V4.4.2,gcc_ntoarmv7le_cpp -E"
export LDFLAGS="-L$QNX_TARGET/armle-v7/usr/lib -L$QNX_TARGET/armle-v7/lib"
export CPPFLAGS="-D__QNXNTO__ -I$QNX_TARGET/usr/include"
export LD="$QNX_HOST/usr/bin/ntoarmv7-ld "
export RANLIB="$QNX_HOST/usr/bin/ntoarmv7-ranlib "

###########################################################################
# Build gettext                                                           #
###########################################################################
echo "==> Building gettext"
pushd $SRC_TOP/gettext
if [ ! -f Makefile ] ; then
    ./configure --build=i686-pc-linux-gnu --host=arm-unknown-nto-qnx6.5.0eabi --prefix=$BUILD_ROOT/gettext \
    --with-libiconv-prefix=$QNX_TARGET/armle-v7/usr/lib --with-libintl-prefix=$QNX_TARGET/armle-v7/usr/lib
fi
make
popd

###########################################################################
# Build getopt                                                            #
###########################################################################
echo "==> Building getopt"
pushd $SRC_TOP/GetOpt
CPPFLAGS="$CPPFLAGS -D__QNXNTO__ -I$QNX_TARGET/usr/include -I$SRC_TOP/gettext/gettext-tools/intl" \
make
popd

############################################################################
# Build CouchDB 1.1.0                                                      #   
############################################################################
echo "==> Building CouchDB"

# Make link to SpiderMonkey header files
mkdir -p $BUILD_ROOT/include/SpiderMonkey
if [ -L $BUILD_ROOT/include/SpiderMonkey/js ] ; then
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
if [ ! -f ./configure ] ; then
    ./bootstrap

    # Patch the configure script
    patch -p0 < $BUILD_ROOT/configure.patch
fi

if [ ! -f ./Makefile ] ; then
    ./configure --build=i686-pc-linux-gnu --host=arm-unknown-nto-qnx6.5.0eabi --prefix=$BUILD_ROOT/CouchDB \
    --with-erlang=$ERL_DIR/PlayBook-build/Erlang/usr/include \
    --with-erlc-flags= $ERL_DIR/PlayBook-build/Erlang/usr/include \
    --with-js-lib=$SRC_TOP/SpiderMonkey/PlayBook-build/lib \
    --with-js-include=$BUILD_ROOT/include/SpiderMonkey/js
fi

make
make install
popd

############################################################################
# Build installer                                                          #   
############################################################################
echo "==> Building installer"
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
ZIP_FILENAME=couchdb-installer.zip
ZIP_FILE=$BUILD_ROOT/$ZIP_FILENAME
if [ -f $ZIP_FILE ] ; then
    rm $ZIP_FILE
fi
pushd CouchDB/PlayBook-build
zip -q $ZIP_FILE install-vars.sh install.sh couchdb-env.sh
popd
pushd Erlang-OTP/PlayBook-build
zip -qry $ZIP_FILE Erlang
popd
pushd CouchDB/PlayBook-build
zip -qry $ZIP_FILE CouchDB
popd

pushd $BUILD_ROOT
if [ ! -d lib ] ; then
    mkdir lib
fi
if [ ! -d bin ] ; then
    mkdir bin
fi
cp $SRC_TOP/SpiderMonkey/PlayBook-build/lib/* lib/
cp $SRC_TOP/GetOpt/getopt bin/
zip -qry $ZIP_FILE lib bin
popd

echo "############################################################################"
echo "CouchDB installer ${ZIP_FILE} created."
echo ""
echo "Authenticate with your PlayBook using blackberry-connect."
echo "Then scp the installer file to the PlayBook."
echo "SSH to the PlayBook as devuser, unzip the installer and run install.sh."
echo ""
echo "For example:"
echo "  blackberry-connect 169.254.0.1 -password <password> -sshPublicKey ~/.ssh/id_rsa.pub"
echo "  scp ${ZIP_FILENAME} devuser@169.254.0.1:"
echo "  ssh devuser@169.254.0.1"
echo "  mkdir couchdb-install"
echo "  unzip ${ZIP_FILENAME} -d couchdb-install"
echo "  cd couchdb-install"
echo "  ./install.sh"
echo "############################################################################"

popd
