#!/bin/bash

echo "*** Adding linux host for Nagios ***"

echo "Hostname: "
read hostname
echo "Alias: "
read alias
echo "IP Address: "
read address

if [ -z $hostname ]; then
  echo "Hostname needed"
  exit 1
elif [ -z $address ]; then
  echo "Address needed"
  exit 1
fi
if [ -z $alias ]; then
  alias=$hostname
fi

echo "cfg_file=/usr/local/nagios/etc/objects/$hostname.cfg" >> /usr/local/nagios/etc/nagios.cfg

cfg=/usr/local/nagios/etc/objects/$hostname.cfg

echo "define host {
  use                     linux-server
  host_name               $hostname
  alias                   $alias
  address                 127.0.0.1
}" > $cfg

echo "Enable ping service ? [y/n]"
read input
if [[ "$input" == "y" ]]; then
  echo "define service {
    use                     local-service
    host_name               $hostname
    service_description     PING
    check_command           check_ping!100.0,20%!500.0,60%
  }" >> $cfg
fi

echo "Enable disk usage service ? [y/n]"
read input
if [[ "$input" == "y" ]]; then
  echo "define service {
    use                     local-service
    host_name               $hostname
    service_description     Root Partition
    check_command           check_local_disk!20%!10%!/
  }" >> $cfg
fi

echo "Enable connected users service ? [y/n]"
read input
if [[ "$input" == "y" ]]; then
  echo "define service {
    use                     local-service
    host_name               $hostname
    service_description     Current Users
    check_command           check_local_users!20!50
  }" >> $cfg
fi

echo "Enable running procs service ? [y/n]"
read input
if [[ "$input" == "y" ]]; then
  echo "define service {
    use                     local-service
    host_name               $hostname
    service_description     Total Processes
    check_command           check_local_procs!250!400!RSZDT
  }" >> $cfg
fi

echo "Enable load usage service ? [y/n]"
read input
if [[ "$input" == "y" ]]; then
  echo "define service {
    use                     local-service
    host_name               $hostname
    service_description     Current Load
    check_command           check_local_load!5.0,4.0,3.0!10.0,6.0,4.0
  }
" >> $cfg
fi

echo "Enable swap usage service ? [y/n]"
read input
if [[ "$input" == "y" ]]; then
  echo "define service {
    use                     local-service
    host_name               $hostname
    service_description     Swap Usage
    check_command           check_local_swap!20%!10%
  }
" >> $cfg
fi

echo "Enable SSH service ? [y/n]"
read input
if [[ "$input" == "y" ]]; then
  echo "define service {
    use                     local-service
    host_name               $hostname
    service_description     SSH
    check_command           check_ssh
    notifications_enabled   0
  }" >> $cfg
fi

echo "Enable HTTP service ? [y/n]"
read input
if [[ "$input" == "y" ]]; then
  echo "define service {
    use                     local-service
    host_name               $hostname
    service_description     HTTP
    check_command           check_http
    notifications_enabled   0
  }" >> $cfg
fi

systemctl reload nagios
echo "Done"
