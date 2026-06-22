#!/bin/bash

INSTALLED=$(dpkg -l | grep -w ncdu)

if [[ -n "$INSTALLED" ]]; then
    echo ""
else
    sudo apt install -y ncdu
fi

sudo ncdu /
