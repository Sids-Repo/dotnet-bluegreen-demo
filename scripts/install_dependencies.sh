#!/bin/bash

apt-get update -y
apt-get install -y wget apt-transport-https

wget https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb
dpkg -i packages-microsoft-prod.deb

apt-get update -y
apt-get install -y dotnet-runtime-6.0 dotnet-host dotnet-hostfxr-6.0
