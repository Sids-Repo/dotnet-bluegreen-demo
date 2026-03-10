#!/bin/bash

cd /opt/codedeploy-agent/deployment-root/*/deployment-archive

export ASPNETCORE_URLS=http://0.0.0.0:80

nohup dotnet dotnet-bluegreen-demo.dll > app.log 2>&1 &
