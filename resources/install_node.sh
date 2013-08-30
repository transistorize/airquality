#!/bin/bash -x
# node & npm installation into user local directory, from binaries
# if a global directory is needed, then consider using apt-get with
# updated repositories (i.e. one that has node v0.10.15)

version=0.10.15
tarfile=node-v$version-linux-x64.tar.gz

echo 'Installing version ' $version

wget http://nodejs.org/dist/v$version/$tarfile
mkdir -p ~/local/node
tar xzf $tarfile -C ~/local/node --strip-components=1
if [ $? -eq 0 ]; then
    echo '# Node Enviroment Setup' >> ~/.bashrc
    echo 'export PATH=$HOME/local/node/bin:$PATH' >> ~/.bashrc
    echo 'export NODE_PATH=$HOME/local/node/lib/node_modules' >> ~/.bashrc
    source ~/.bashrc
    echo 'Check for versions ... '
    node -v
    npm -v
fi

