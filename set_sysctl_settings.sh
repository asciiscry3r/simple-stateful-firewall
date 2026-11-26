#!/usr/bin/env bash

total_mem=$(free -m | awk '/^Mem:/{print $2}')
result=$((((total_mem / 1000) * (1024 ** 3)) / 2))

sed -E -i 's/kernel.shmall=[0-9a-z]*$/kernel.shmall='"$result"'/g' /etc/sysctl.d/99-sysctl.conf
sed -E -i 's/kernel.shmmax=[0-9a-z]*$/kernel.shmmax='"$result"'/g' /etc/sysctl.d/99-sysctl.conf
