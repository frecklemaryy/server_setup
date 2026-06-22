#!/bin/bash

free -h
echo ""
ps -eo comm:15,cmd:55,%mem,%cpu,pid:8,ppid --sort=-%mem | head -n 10
