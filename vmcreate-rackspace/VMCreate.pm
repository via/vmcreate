#!/usr/bin/perl -w
#
# Copyright (c) 2007 VMware, Inc.  All rights reserved.
#

package VMCreate;
our @EXPORT = qw(createVM);

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../";

use VMware::VIRuntime;
use AppUtil::HostUtil;
use AppUtil::VMUtil;



# This subroutine parses the input xml file to retrieve all the
# parameters specified in the file and passes these parameters
# to create_vm subroutine to create a single virtual machine
# =============================================================

sub createVM {


  my ($vmname, $memory, $guestos, $datacenter, $datastore,
    $disksize, $numprocs, $netname, $host) = @_;
  my $nic_poweron = 1; 

  create_vm(vmname => $vmname,
    vmhost => $host,
    datacenter => $datacenter,
    guestid => $guestos,
    datastore => $datastore,
    disksize => $disksize,
    memory => $memory,
    num_cpus => $numprocs,
    nic_network => $netname,
    nic_poweron => $nic_poweron);
  my $views = VMUtils::get_vms('VirtualMachine', $vmname,
    $datacenter, undef, undef,
    $host, ());

  my $devices = @$views[0]->config->hardware->device;
  my $mac = "";
  foreach (@$devices) {
    if ($_->isa("VirtualEthernetCard")) {
      $mac = $_->macAddress;
    }
  }

  print "VMNAME=\"" . $vmname . "\"\n";
  print "VMUUID=\"" . @$views[0]->config->uuid . "\"\n";
  print "VMMAC=\"" . $mac . "\"\n";

  return ($vmname, @$views[0]->config->uuid, $mac);

}


# create a virtual machine
# ========================
sub create_vm {
   my %args = @_;
   my @vm_devices;
   my $host_view = Vim::find_entity_view(view_type => 'HostSystem',
                                filter => {'name' => $args{vmhost}});
   if (!$host_view) {
       die "\nError creating VM $args{vmname}: "
                    . "Host '$args{vmhost}' not found\n";
       return;
   }

   my %ds_info = HostUtils::get_datastore(host_view => $host_view,
                               datastore => $args{datastore},
                               disksize => $args{disksize});

   if ($ds_info{mor} eq 0) {
      if ($ds_info{name} eq 'datastore_error') {
         die "\nError creating VM '$args{vmname}': "
                      . "Datastore $args{datastore} not available.\n";
         return;
      }
      if ($ds_info{name} eq 'disksize_error') {
         die "\nError creating VM '$args{vmname}': The free space "
                      . "available is less than the specified disksize.\n";
         return;
      }
   }
   my $ds_path = "[" . $ds_info{name} . "]";

   my $controller_vm_dev_conf_spec = create_conf_spec();
   my $disk_vm_dev_conf_spec =
      create_virtual_disk(ds_path => $ds_path, disksize => $args{disksize});

   my %net_settings = get_network(network_name => $args{nic_network},
                               poweron => $args{nic_poweron},
                               host_view => $host_view);
                               
   if($net_settings{'error'} eq 0) {
      push(@vm_devices, $net_settings{'network_conf'});
   } elsif ($net_settings{'error'} eq 1) {
      die "\nError creating VM '$args{vmname}': "
                    . "Network '$args{nic_network}' not found\n";
      return;
   }

   push(@vm_devices, $controller_vm_dev_conf_spec);
   push(@vm_devices, $disk_vm_dev_conf_spec);

   my $files = VirtualMachineFileInfo->new(logDirectory => undef,
                                           snapshotDirectory => undef,
                                           suspendDirectory => undef,
                                           vmPathName => $ds_path);
   my $vm_config_spec = VirtualMachineConfigSpec->new(
                                             name => $args{vmname},
                                             memoryMB => $args{memory},
                                             files => $files,
                                             numCPUs => $args{num_cpus},
                                             guestId => $args{guestid},
                                             deviceChange => \@vm_devices);
                                             
   my $datacenter_views =
        Vim::find_entity_views (view_type => 'Datacenter',
                                filter => { name => $args{datacenter}});

   unless (@$datacenter_views) {
      die "\nError creating VM '$args{vmname}': "
                   . "Datacenter '$args{datacenter}' not found\n";
      return;
   }

   if ($#{$datacenter_views} != 0) {
      die "\nError creating VM '$args{vmname}': "
                   . "Datacenter '$args{datacenter}' not unique\n";
      return;
   }
   my $datacenter = shift @$datacenter_views;

   my $vm_folder_view = Vim::get_view(mo_ref => $datacenter->vmFolder);

   my $comp_res_view = Vim::get_view(mo_ref => $host_view->parent);

   eval {
      $vm_folder_view->CreateVM(config => $vm_config_spec,
                             pool => $comp_res_view->resourcePool);
    };
    if ($@) {
       die "\nError creating VM '$args{vmname}': ";
       if (ref($@) eq 'SoapFault') {
          if (ref($@->detail) eq 'PlatformConfigFault') {
             die "Invalid VM configuration: "
                            . ${$@->detail}{'text'} . "\n";
          }
          elsif (ref($@->detail) eq 'InvalidDeviceSpec') {
             die "Invalid Device configuration: "
                            . ${$@->detail}{'property'} . "\n";
          }
           elsif (ref($@->detail) eq 'DatacenterMismatch') {
             die "DatacenterMismatch, the input arguments had entities "
                          . "that did not belong to the same datacenter\n";
          }
           elsif (ref($@->detail) eq 'HostNotConnected') {
             die "Unable to communicate with the remote host,"
                         . " since it is disconnected\n";
          }
          elsif (ref($@->detail) eq 'InvalidState') {
             die "The operation is not allowed in the current state\n";
          }
          elsif (ref($@->detail) eq 'DuplicateName') {
             die "Virtual machine already exists.\n";
          }
          else {
             die "\n" . $@ . "\n";
          }
       }
       else {
          die "\n" . $@ . "\n";
       }
   }
}


# create virtual device config spec for controller
# ================================================
sub create_conf_spec {
   my $controller =
      VirtualLsiLogicController->new(key => 0,
                                     device => [0],
                                     busNumber => 0,
                                     sharedBus => VirtualSCSISharing->new('noSharing'));

   my $controller_vm_dev_conf_spec =
      VirtualDeviceConfigSpec->new(device => $controller,
         operation => VirtualDeviceConfigSpecOperation->new('add'));
   return $controller_vm_dev_conf_spec;
}


# create virtual device config spec for disk
# ==========================================
sub create_virtual_disk {
   my %args = @_;
   my $ds_path = $args{ds_path};
   my $disksize = $args{disksize};

   my $disk_backing_info =
      VirtualDiskFlatVer2BackingInfo->new(diskMode => 'persistent',
                                          fileName => $ds_path);

   my $disk = VirtualDisk->new(backing => $disk_backing_info,
                               controllerKey => 0,
                               key => 0,
                               unitNumber => 0,
                               capacityInKB => $disksize);

   my $disk_vm_dev_conf_spec =
      VirtualDeviceConfigSpec->new(device => $disk,
               fileOperation => VirtualDeviceConfigSpecFileOperation->new('create'),
               operation => VirtualDeviceConfigSpecOperation->new('add'));
   return $disk_vm_dev_conf_spec;
}


# get network configuration
# =========================
sub get_network {
   my %args = @_;
   my $network_name = $args{network_name};
   my $poweron = $args{poweron};
   my $host_view = $args{host_view};
   my $network = undef;
   my $unit_num = 1;  # 1 since 0 is used by disk

   if($network_name) {
      my $network_list = Vim::get_views(mo_ref_array => $host_view->network);
      foreach (@$network_list) {
         if($network_name eq $_->name) {
            $network = $_;

            my $dvs = Vim::get_view(mo_ref =>
              $network->config->distributedVirtualSwitch);

            my $vds_connection = 
                DistributedVirtualSwitchPortConnection->new(
                  portgroupKey => $network->config->key,
                  switchUuid => $dvs->uuid);

            my $nic_vds_backing_info = 
               VirtualEthernetCardDistributedVirtualPortBackingInfo->new(
                  port => $vds_connection);

                                              
            my $vd_connect_info =
               VirtualDeviceConnectInfo->new(allowGuestControl => 1,
                                             connected => 0,
                                             startConnected => $poweron);

            my $nic = VirtualPCNet32->new(backing => $nic_vds_backing_info,
                                          key => 0,
                                          unitNumber => $unit_num,
                                          addressType => 'generated',
                                          connectable => $vd_connect_info);

            my $nic_vm_dev_conf_spec =
               VirtualDeviceConfigSpec->new(device => $nic,
                     operation => VirtualDeviceConfigSpecOperation->new('add'));

            return (error => 0, network_conf => $nic_vm_dev_conf_spec);
         }
      }
      if (!defined($network)) {
      # no network found
       return (error => 1);
      }
   }
    # default network will be used
    return (error => 2);
}



__END__

## bug 217605

=head1 NAME

vmcreate.pl - Create virtual machines according to the specifications
              provided in the input XML file.

=head1 SYNOPSIS

 vmcreate.pl [options]

=head1 DESCRIPTION

This VI Perl command-line utility provides an interface for creating one
or more new virtual machines based on the parameters specified in the
input valid XML file. The syntax of the XML file is validated against the
specified schema file.

=head1 OPTIONS

=over

=item B<filename>

Optional. The location of the XML file which contains the specifications of the virtual
machines to be created. If this option is not specified, then the default
file 'vmcreate.xml' will be used from the "../sampledata" directory. The user can use
this file as a referance to create there own input XML files and specify the file's
location using <filename> option.

=item B<schema>

Optional. The location of the schema file against which the input XML file is
validated. If this option is not specified, then the file 'vmcreate.xsd' will
be used from the "../schema" directory. This file need not be modified by the user.

=back

=head2 INPUT PARAMETERS

The parameters for creating the virtual machine are specified in an XML
file. The structure of the input XML file is:

   <virtual-machines>
      <VM>
         <!--Several parameters like machine name, guest OS, memory etc-->
      </VM>
      .
      .
      .
      <VM>
      </VM>
   </virtual-machines>

Following are the input parameters:

=over

=item B<vmname>

Required. Name of the virtual machine to be created.

=item B<vmhost>

Required. Name of the host.

=item B<datacenter>

Required. Name of the datacenter.

=item B<guestid>

Optional. Guest operating system identifier. Default: 'winXPProGuest'.

=item B<datastore>

Optional. Name of the datastore. Default: Any accessible datastore with free
space greater than the disksize specified.

=item B<disksize>

Optional. Capacity of the virtual disk (in KB). Default: 4096

=item B<memory>

Optional. Size of virtual machine's memory (in MB). Default: 256

=item B<num_cpus>

Optional. Number of virtual processors in a virtual machine. Default: 1

=item B<nic_network>

Optional. Network name. Default: Any accessible network.

=item B<nic_poweron>

Optional. Flag to specify whether or not to connect the device
when the virtual machine starts. Default: 1

=back

=head1 EXAMPLE

Create five new virtual machines with the following configuration:

 Machine 1:
      Name             : Virtual_1
      Host             : 192.168.111.2
      Datacenter       : Dracula
      Guest Os         : Windows Server 2003, Enterprise Edition
      Datastore        : storage1
      Disk size        : 4096 KB
      Memory           : 256 MB
      Number of CPUs   : 1
      Network          : VM Network
      nic_poweron flag : 0

 Machine 2:
      Name             : Virtual_2
      Host             : <Any Invalid Name, say Host123>
      Datacenter       : Dracula
      Guest Os         : Red Hat Enterprise Linux 4
      Datastore        : storage1
      Disk size        : 4096 KB
      Memory           : 256 MB
      Number of CPUs   : 1
      Network          : VM Network
      nic_poweron flag : 0

 Machine 3:
      Name             : Virtual_3
      Host             : 192.168.111.2
      Datacenter       : Dracula
      Guest Os         : Windows XP Professional
      Datastore        : <Invalid datastore name, say DataABC>
      Disk size        : 4096 KB
      Memory           : 256 MB
      Number of CPUs   : 1
      Network          : VM Network
      nic_poweron flag : 0

 Machine 4:
      Name             : Virtual_4
      Host             : 192.168.111.2
      Datacenter       : Dracula
      Guest Os         : Solaris 9
      Datastore        : storage1
      Disk size        : <No disk size; default value will be used>
      Memory           : 128 MB
      Number of CPUs   : 1
      Network          : VM Network
      nic_poweron flag : 0

 Machine 5:
      Name             : Virtual_5
      Host             : 192.168.111.2
      Datacenter       : Dracula
      Guest Os         : <No guest OS, default will be used>
      Datastore        : storage1
      Disk size        : 2048 KB
      Memory           : 128 MB
      Number of CPUs   : 1
      Network          : <No network name, default will be used>
      nic_poweron flag : 1

To create five virtual machines as specified, use the following input XML file:

 <?xml version="1.0"?>
 <virtual-machines>
   <VM>
      <vmname>Virtual_1</vmname>
      <vmhost>192.168.111.2</vmhost>
      <datacenter>Dracula</datacenter>
      <guestid>winNetEnterpriseGuest</guestid>
      <datastore>storage1</datastore>
      <disksize>4096</disksize>
      <memory>256</memory>
      <num_cpus>1</num_cpus>
      <nic_network>VM Network</nic_network>
      <nic_poweron>0</nic_poweron>
   </VM>
   <VM>
      <vmname>Virtual_2</vmname>
      <vmhost>Host123</vmhost>
      <datacenter>Dracula</datacenter>
      <guestid>rhel4Guest</guestid>
      <datastore>storage1</datastore>
      <disksize>4096</disksize>
      <memory>256</memory>
      <num_cpus>1</num_cpus>
      <nic_network>VM Network</nic_network>
      <nic_poweron>0</nic_poweron>
   </VM>
   <VM>
      <vmname>Virtual_3</vmname>
      <vmhost>192.168.111.2</vmhost>
      <datacenter>Dracula</datacenter>
      <guestid>winXPProGuest</guestid>
      <datastore>DataABC</datastore>
      <disksize>4096</disksize>
      <memory>256</memory>
      <num_cpus>1</num_cpus>
      <nic_network>VM Network</nic_network>
      <nic_poweron>0</nic_poweron>
   </VM>
   <VM>
      <vmname>Virtual_4</vmname>
      <vmhost>192.168.111.2</vmhost>
      <datacenter>Dracula</datacenter>
      <guestid>solaris9Guest</guestid>
      <datastore>storage1</datastore>
      <disksize></disksize>
      <memory>128</memory>
      <num_cpus>1</num_cpus>
      <nic_network>VM Network</nic_network>
      <nic_poweron>0</nic_poweron>
   </VM>
   <VM>
      <vmname>Virtual_5</vmname>
      <vmhost>192.168.111.2</vmhost>
      <datacenter>Dracula</datacenter>
      <guestid></guestid>
      <datastore>storage1</datastore>
      <disksize>2048</disksize>
      <memory>128</memory>
      <num_cpus>1</num_cpus>
      <nic_network></nic_network>
      <nic_poweron>1</nic_poweron>
   </VM>
 </virtual-machines>

The command to run the vmcreate script is:

 vmcreate.pl --url https://192.168.111.52:443/sdk/webService
             --username administrator --password mypassword
             --filename create_vm.xml --schema schema.xsd

The script continues to create the next virtual machine even if
a previous machine creation process failed.  Sample output of the command:

 --------------------------------------------------------------
 Successfully created virtual machine: 'Virtual_1'

 Error creating VM 'Virtual_2': Host 'Host123' not found

 Error creating VM 'Virtual_3': Datastore DataABC not available.

 Successfully created virtual machine: 'Virtual_4'

 Successfully created virtual machine: 'Virtual_5'
 --------------------------------------------------------------

=head1 SUPPORTED PLATFORMS

Create operation work with VMware VirtualCenter 2.0 or later.

