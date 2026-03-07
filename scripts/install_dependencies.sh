#!/bin/bash

apt-get update -y
apt-get install -y ruby wget

wget https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
dpkg -i packages-microsoft-prod.deb

apt-get update -y
apt-get install -y dotnet-runtime-6.0
