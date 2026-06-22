#!/bin/bash

ss -tulpn | awk '{print $5}' | cut -d':' -f2 | sort -n | uniq
