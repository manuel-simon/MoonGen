#!/bin/bash

# install dependencies
apt-get install -y lua5.2
apt-get install -y liblua5.2-dev

# install luarocks 2.2
wget http://keplerproject.github.io/luarocks/releases/luarocks-2.2.0.tar.gz
tar xzf luarocks-2.2.0.tar.gz
cd luarocks-2.2.0
./configure --lua-version=5.2

# install webserver
luarocks pegasus
