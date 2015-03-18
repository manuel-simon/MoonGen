#!/bin/bash

# install dependencies
apt-get install -y build-essential
apt-get install -y lua5.1
apt-get install -y liblua5.1-dev

# install luarocks 2.2
wget http://keplerproject.github.io/luarocks/releases/luarocks-2.2.0.tar.gz
tar xzf luarocks-2.2.0.tar.gz
cd luarocks-2.2.0
./configure --lua-version=5.1
make build
make install

# install webserver
luarocks install xavante
