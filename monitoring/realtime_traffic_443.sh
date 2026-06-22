#!/bin/bash

INSTALLED=$(dpkg -l | grep -w iftop)

if [[ -n "$INSTALLED" ]]; then
    echo ""
else
    sudo apt install -y iftop
fi

sudo iftop -o 10s -B -f "port 443"
