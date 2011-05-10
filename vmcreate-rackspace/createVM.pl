#!/usr/bin/perl -w

use VMCreate;

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../";

use VMware::VIRuntime;
use AppUtil::HostUtil;
use AppUtil::VMUtil;

$Util::script_version = "1.0";

my %opts = (
  vmname => {
    type => "=s",
    help => "Name of the new VM",
    required => 1
  },
  guestos => {
    type => "=s",
    help => "Guest OS type",
    required => 0,
    default => "rhel5_64Guest"
  },
  datacenter => {
    type => "=s",
    required => 1,
    help => "Datacenter to use"
  },
  host => {
    type => "=s",
    required => 1,
    help => "ESX host to use"
  },
  datastore => {
    type => "=s",
    required => 1,
    help => "Datastore to use, without []"
  },
  disksize => {
    type => "=i",
    required => 0,
    default => 33554432,
    help => "Disk size in KB"
  },
  memory => {
    type => "=i",
    required => 0,
    default => 384,
    help => "Memory in MB"
  },
  numprocs => {
    type => "=i",
    required => 0,
    default => 1,
    help => "Number of processors"
  },
  network => {
    type => "=s",
    required => 1,
    help => "Network name"
  }
);


Opts::add_options(%opts);
Opts::parse();
Opts::validate();

Util::connect();
create_vm_from_opts();
Util::disconnect();

sub create_vm_from_opts() {
  
  my $memory = Opts::get_option('memory');
  my $vmname = Opts::get_option('vmname');
  my $guestos = Opts::get_option('guestos');
  my $datacenter = Opts::get_option('datacenter');
  my $datastore = Opts::get_option('datastore');
  my $disksize = Opts::get_option('disksize');
  my $numprocs = Opts::get_option('numprocs');
  my $netname = Opts::get_option('network');
  my $host = Opts::get_option('host');

  VMCreate::createVM($vmname, $memory, $guestos, $datacenter, $datastore,
    $disksize, $numprocs, $netname, $host);

}
