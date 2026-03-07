#!/bin/bash

cd /var/www/app/publish

export ASPNETCORE_URLS=http://0.0.0.0:80

nohup dotnet dotnet-bluegreen-demo.dll > app.log 2>&1 &
