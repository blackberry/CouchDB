#!/bin/sh

. ./install-vars.sh
: ${BUILD_ROOT:?"Error: BUILD_ROOT variable is not set."}
: ${ERL_DIR:?"Error: ERL_DIR variable is not set."}

PREFIX=`pwd`
INSTALL_PREFIX=$PREFIX
ERLANG_DIR=$PREFIX/Erlang

fix_paths()
{
    CURDIR=`pwd`
    FILE_DIR=`dirname $1`
    FILE_NAME=`basename $1`

    cd $FILE_DIR
    cat $FILE_NAME | sed -e "s|$BUILD_ROOT|$INSTALL_PREFIX|g" -e "s|$ERL_DIR/bootstrap|$ERLANG_DIR|g" > $FILE_NAME.tmp
    mv $FILE_NAME.tmp $FILE_NAME
    cd $CURDIR
}

# Fix scripts
cd $PREFIX/CouchDB
fix_paths ./bin/couchdb
fix_paths ./bin/couchjs
fix_paths ./etc/couchdb/default.ini
fix_paths ./etc/logrotate.d/couchdb
fix_paths ./etc/init.d/couchdb
fix_paths ./lib/couchdb/bin/couchjs
fix_paths ./lib/couchdb/erlang/lib/couch-1.1.0/ebin/couch.app

chmod +x ./lib/couchdb/bin/couchjs
chmod +x ./bin/couchjs
chmod +x ./bin/couchdb

# Setup Erlang
cd $PREFIX/Erlang
if [ -f bin/run_test ] ; then
	rm -f bin/run_test
fi
./Install -minimal $PREFIX/Erlang

mount -uw /base

cd $PREFIX/lib
cp libjs.so libmozjs.so /usr/lib

cd $PREFIX/bin
cp getopt /usr/bin

# Start CouchDB
cd $PREFIX/CouchDB/bin
echo "Start CouchDB in $PREFIX/CouchDB/bin by running \"./couchdb\"."
#PATH=$PATH:$PREFIX/Erlang/erts-5.8.4/bin ./couchdb # Set path to inet_gethost
