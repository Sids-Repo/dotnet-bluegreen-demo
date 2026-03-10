#!/bin/bash

echo "Starting dependency installation..."

# Create app directory FIRST
sudo mkdir -p /var/www/app

sudo apt-get update -y

sudo apt-get install -y wget

# Install .NET runtime if not installed
if ! command -v dotnet &> /dev/null
then
    echo "Installing .NET..."

    wget https://dot.net/v1/dotnet-install.sh
    chmod +x dotnet-install.sh

    sudo ./dotnet-install.sh --channel 6.0 --install-dir /usr/share/dotnet

    sudo ln -sf /usr/share/dotnet/dotnet /usr/bin/dotnet
fi

echo "Dotnet version:"
dotnet --info

echo "Dependency installation completed"
