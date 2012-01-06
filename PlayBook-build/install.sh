#!/bin/sh

. ./install-vars.sh
: ${BUILD_ROOT:?"Error: BUILD_ROOT variable is not set."}
: ${ERL_DIR:?"Error: ERL_DIR variable is not set."}

PREFIX=`pwd`
DEVUSER_DIR=/accounts/devuser

fix_paths()
{
    CURDIR=`pwd`
    FILE_DIR=`dirname $1`
    FILE_NAME=`basename $1`

    cd $FILE_DIR
    cat $FILE_NAME | sed -e "s|$BUILD_ROOT|$PREFIX|g" -e "s|$ERL_DIR/bootstrap|$PREFIX/Erlang|g" > $FILE_NAME.tmp
    mv $FILE_NAME.tmp $FILE_NAME
    cd $CURDIR
}

# Create directories if needed
if [ ! -d $DEVUSER_DIR/lib ] ; then
    mkdir $DEVUSER_DIR/lib
fi

if [ ! -d $DEVUSER_DIR/bin ] ; then
    mkdir $DEVUSER_DIR/bin
fi

# Set ownership
chown -R devuser:devuser bin lib CouchDB Erlang install.sh install-vars.sh

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

cd $PREFIX/lib
cp libjs.so libmozjs.so $DEVUSER_DIR/lib

cd $PREFIX/bin
cp getopt $DEVUSER_DIR/bin

# Ready to start CouchDB
echo "Source couchdb-env.sh into your environment (e.g. . ./couchdb-env.sh)."
echo "In CouchDB/etc/couchdb/default.ini, change bind_address to 169.254.0.1 so that you can connect to CouchDB with your desktop browser."
echo "Start CouchDB in $PREFIX/CouchDB/bin by running \"./couchdb\"."
