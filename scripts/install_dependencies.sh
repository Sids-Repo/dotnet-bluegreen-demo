#!/bin/bash

apt-get update -y
apt-get install -y wget

wget https://dot.net/v1/dotnet-install.sh
chmod +x dotnet-install.sh

./dotnet-install.sh --channel 6.0

ln -s /root/.dotnet/dotnet /usr/bin/dotnet || true
