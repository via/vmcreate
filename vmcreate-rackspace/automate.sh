#!/usr/bin/env bash

VSHOST=ord1vc01s.wm.mlsrvr.com
ESXHOST=ord1esx01s.wm.mlsrvr.com
DATASTORE=ORD1ESX01S_VM1_R5
NETWORK="dvPG_Testing_Misc_123"
DATACENTER=ORD1-Linux-Testing
DHCPD_CONF=/etc/dhcpd.conf
PXEBASE=/srv/pxelinux.cfg
ZONE=/blah
HOSTNAME=$1
IP4=$2
KSFILE=$3


#USAGE automate.sh hostname ip kickstartfile

#Get password
read -p "VSphere Username: " uname
stty -echo
read -p "VSphere Password: " passw; echo
stty echo


eval $(./createVM.pl --host $ESXHOST --server $VSHOST --datastore $DATASTORE \
  --network $NETWORK --vmname $HOSTNAME --datacenter $DATACENTER \
  --username $uname --password $passw )

./updateConfig.pl $DHCPD_CONF $PXEBASE $ZONE $HOSTNAME $VMMAC $VMUUID \
  $IP4 $KSFILE
