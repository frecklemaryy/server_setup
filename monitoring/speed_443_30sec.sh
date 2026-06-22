#!/bin/bash

INSTALLED=$(dpkg -l | grep -w iftop)

if [[ -n "$INSTALLED" ]]; then
    echo ""
else
    sudo apt install -y iftop
fi

sudo iftop -P -f "port 443" -t -s 30
