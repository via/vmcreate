#!/usr/bin/perl -w



($dhcpdconf, $pxebase, $zone, $hostname, $mac, $uuid, $ip4, $ksfile) = @ARGV;

print "Configuring $hostname ($mac) with $ip4\n";
print "First boot will use kickstart file $ksfile\n";

dhcpAddEntry($dhcpdconf, $hostname, $mac, $ip4);
addPXEConfig($pxebase, $uuid, $ksfile);
#updateDNS($zone, $hostname, $ip4, "");


sub updateDNS() {

  my ($zonefile, $hostname, $ip4, $ip6) = @_;

  if ($ip4 ne "") {
    print "$hostname  A $ip4\n";
  }

  if ($ip6 ne "") {
    print "$hostname  AAAA $ip6\n";
  }
}

sub dhcpIpExists() {
  my ($configfile, $hostname, $ip4) = @_;
  my @configlines;

  open HANDLE, "<$configfile" or die "Unable to open dhcp configuration!\n";
  @configlines = <HANDLE>;
  close HANDLE;
# TODO finish  
  return 0;
}

sub dhcpAddEntry() {
  my ($configfile, $hostname, $mac, $ip4) = @_;

  open HANDLE, ">>$configfile" or die "Unable to open dhcp configuration!\n";

  print HANDLE "host $hostname {\n";
  print HANDLE "  hardware ethernet ${mac};\n";
  print HANDLE "  fixed-address ${ip4};\n";
  print HANDLE "  option host-name \"${hostname}\";\n";
  print HANDLE "}\n";

  close HANDLE;
}

sub addPXEConfig() {
  my ($pxepath, $uuid, $ksfile) = @_;

  open BASEHANDLE, "<${pxepath}/base" or die "Couldn't open base pxe config!\n";
  open NEWHANDLE, ">${pxepath}/${uuid}" or 
    die "Couldn't open new pxe config!\n";

  while ($line = <BASEHANDLE>) {
    $line =~ s/kickstartfileoption/ks=${ksfile}/;
    print NEWHANDLE $line;
  }

  close BASEHANDLE;
  close NEWHANDLE;
}






