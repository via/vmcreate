#!/usr/bin/env bash

VSHOST=ord1vc01s.wm.mlsrvr.com
ESXHOST=ord1esx01s.wm.mlsrvr.com
DATASTORE=ORD1ESX01S_VM1_R5
NETWORK=dvPG_Testing_Misc_123
DATACENTER=ORD1-Linux-Testing
DHCPD_CONF=/etc/dhcpd.conf
PXEBASE=/srv/pxelinux.cfg
ZONE=/blah
VSUSER=$1
VSPASS=$2
HOSTNAME=$3
IP4=$4
KSFILE=$5


#USAGE automate.sh VSUSER VSPASS hostname ip kickstartfile



eval $(./createVM.pl --host $ESXHOST --server $VSHOST --datastore $DATASTORE \
  --network $NETWORK --vmname $HOSTNAME --datacenter $DATACENTER \
  --username $VSUSER --password $VSPASS )

./updateConfig.pl $DHCPD_CONF $PXEBASE $ZONE $HOSTNAME $VMMAC $VMUUID \
  $IP4 $KSFILE
