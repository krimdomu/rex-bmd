#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::IO::BMD::Module::Bootstrap;
   
use strict;
use warnings;

require Rex::IO::BMD::Args;
require LWP::Simple;

use Data::Dumper;
use Rex::Commands;
use Rex::Commands::Run;
use Rex::Commands::Fs;
use Rex::Commands::File;
use Rex::Commands::Partition;
use Rex::IO::BMD::Commands::System;
use Rex::Commands::Network;
use Rex::Commands::User;
use Rex::Commands::Pkg;
use Rex::Commands::Gather;
use Rex::Commands::LVM;

use Rex::IO::BMD;

use YAML;

my $root_mount = "/mnt-os";

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   $self->{"__mount_point"} = {};

   return $self;
}

sub call {
   my ($self) = @_;

   my $cmdline = cat "/proc/cmdline";

   if($cmdline =~ m/REXIO_BOOTSTRAP_FILE=([^\s]+)/) {
      my $bootstrap_file = $1;
      my $yaml = LWP::Simple::get($bootstrap_file);
      my $install_info = Load($yaml);

      $self->_install($install_info);
   }
   else {
      my $args = Rex::IO::Args->get;

      if(! exists $args->{dist}
            || ! exists $args->{version}
            || ! exists $args->{arch}) {
            
            die("No dist/version/arch specified.");

      }

      my $dist    = $args->{dist};
      my $version = $args->{version};
      my $arch    = $args->{arch};

      my $dist_mod = "Rex::IO::Bootstrap::$dist";
      eval "use $dist_mod";

      if($@) {
         die("Can't load $dist_mod. Not supported.");
      }

      my $dist_mod_o = $dist_mod->new;

      $dist_mod_o->call;
   }
}

# this function will install the system on disk
sub _install {
   my ($self, $conf) = @_;

   Rex::IO::BMD->d_print("Partitioning Harddisk", 1);
   $self->_partition($conf->{partitions});

   Rex::IO::BMD->d_print("Mounting Filesystems", 1);
   mkdir "${root_mount}" unless(is_dir("${root_mount}"));
   $self->_mount;

   my $url = $conf->{Url} || $conf->{url};
   Rex::IO::BMD->d_print("Downloading Image from $url", 1);
   $self->_download_image($url);

   $self->_chroot($conf);

}

sub _partition {
   my ($self, $partitions) = @_;

   if(exists $partitions->{clear}) {
      clearpart $partitions->{clear}->{device},
         initialize => $partitions->{clear}->{initialize};

      delete $partitions->{clear};
   }

   # first create the lvm volumes
   for my $partition ( keys %{$partitions} ) {
      if(exists $partitions->{$partition}->{vg}) {
         partition($partition, %{ $partitions->{$partition} });
         delete $partitions->{$partition};
      }
   }
   
   for my $mount_point (keys %{$partitions}) {
      $self->{"__mount_point"}->{$mount_point} = $partitions->{$mount_point};
      my $device;
      if(exists $partitions->{$mount_point}->{onvg}) {
         my $lv_name = $mount_point;
         $lv_name = "root" if($lv_name eq "/");
         $lv_name =~ s/\//-/g;
         lvcreate($lv_name, %{ $partitions->{$mount_point} });
         $device = $partitions->{$mount_point}->{onvg} . "/$lv_name";
      }
      else {
         $device = partition($mount_point, %{ $partitions->{$mount_point} });
      }
      $self->{"__mount_point"}->{$mount_point}->{"device"} = $device;
   }
}

sub _mount {
   my ($self) = @_;
   my $root_device = $self->{"__mount_point"}->{"/"};

   mount "/dev/".$root_device->{"device"}, "${root_mount}",
      fs => $root_device->{"fstype"};

   for my $mount_point (keys %{ $self->{"__mount_point"} }) {
      next if($mount_point eq "/");
      next if($mount_point eq "swap");
      next if($mount_point eq "none");

      mkdir "${root_mount}$mount_point" unless(is_dir("${root_mount}$mount_point"));
      mount "/dev/".$self->{"__mount_point"}->{$mount_point}->{device}, "${root_mount}$mount_point",
         fs => $self->{"__mount_point"}->{$mount_point}->{fstype};
   }
}

sub _download_image {
   my ($self, $url) = @_;

   chdir "${root_mount}";
   run "wget $url";
   my ($tar) = ($url =~ m/.*\/(.*?)$/);
   run "tar xzf $tar";
}

sub _chroot {
   my ($self, $conf) = @_;

   Rex::IO::BMD->d_print("Forking to chroot", 1);
   my $pid = fork;
   if($pid == 0) {

      cp "/etc/hosts", "${root_mount}/etc/hosts";
      cp "/etc/resolv.conf", "${root_mount}/etc/resolv.conf";
      run "echo 127.0.2.1 nfs-image >>${root_mount}/etc/hosts";

      run "mount -obind /dev ${root_mount}/dev";
      
      Rex::IO::BMD->d_print("chrooting to ${root_mount}", 1);
      chroot "${root_mount}";
      chdir "/";

      Rex::IO::BMD->d_print("Mounting proc and sys", 1);
      run "mount -t proc proc /proc";
      run "mount -t sysfs sysfs /sys";

      Rex::IO::BMD->d_print("Writing fstab", 1);
      my $fh = file_write "/etc/fstab";
      $fh->write("proc  /proc proc  nodev,noexec,nosuid  0  0\n");

      for my $mount_point (keys %{ $self->{"__mount_point"} }) {
         my $dev = "/dev/".$self->{"__mount_point"}->{$mount_point}->{device};
         my $fs  = $self->{"__mount_point"}->{$mount_point}->{fstype};
         if($mount_point eq "swap") {
            $fh->write("$dev  none  swap  sw 0  0\n");
            next;
         }

         $fh->write("$dev  $mount_point   $fs   errors=remount-ro 0  1\n");
      }
      $fh->close;

      Rex::IO::BMD->d_print("Configuring System", 1);
      Rex::IO::BMD->d_print(" - base");
      $self->_base_configuration($conf->{system});
      Rex::IO::BMD->d_print(" - network");
      $self->_network_configuration($conf->{network});
      Rex::IO::BMD->d_print(" - authentication");
      $self->_authentication($conf->{authentication});

      Rex::IO::BMD->d_print("Installing additional packages", 1);
      $self->_install_packages($conf->{packages});

      Rex::IO::BMD->d_print("Writing MBR", 1);
      $self->_write_mbr($conf->{boot});

      if(is_debian) {
         run "chmod 755 /etc/init.d/networking";
      }

      #run "umount /proc";
      #run "umount /sys";
      Rex::IO::BMD->d_print("Finished jobs in chroot", 1);

      exit; # exit child
   }
   else {
      waitpid($pid, 0);
      Rex::IO::BMD->d_print("Long lost child came home... Unmounting and rebooting...", 1);
      run "sync";
      run "umount ${root_mount}/dev";
      run "umount ${root_mount}";
      if($? != 0) {
         run "mount -oremount,ro ${root_mount}";
      }
      run "/sbin/reboot";
   }
}

sub _base_configuration {
   my ($self, $conf) = @_;

   if(exists $conf->{default_language}) {
      Rex::IO::BMD->d_print("   - default language");
      default_language $conf->{default_language};
   }

   if(exists $conf->{languages}) {
      Rex::IO::BMD->d_print("   - locales");
      languages @{ $conf->{languages} };
   }

   if(exists $conf->{timezone}) {
      Rex::IO::BMD->d_print("   - timezone");
      timezone $conf->{timezone};
   }

   if(exists $conf->{keyboard}) {
      Rex::IO::BMD->d_print("   - keyboard");
      keyboard $conf->{keyboard};
   }

   if(exists $conf->{hostname}) {
      Rex::IO::BMD->d_print("   - hostname");
      Rex::IO::BMD::Commands::System::hostname($conf->{hostname});
   }

   if(exists $conf->{domainname}) {
      Rex::IO::BMD->d_print("   - domainname");
      Rex::IO::BMD::Commands::System::domainname($conf->{domainname});
   }

}

sub _network_configuration {
   my ($self, $conf) = @_;

   Rex::IO::BMD->d_print("   - interfaces");
   file "/etc/network/interfaces",
      content => "auto lo\niface lo inet loopback\n\n";

   for my $device (keys %{ $conf }) {
      Rex::IO::BMD->d_print("      - $device");
      Rex::IO::BMD::Commands::System::network($device, %{ $conf->{$device} });
   }
}

sub _authentication {
   my ($self, $conf) = @_;

   for my $user (keys %{ $conf }) {
      Rex::IO::BMD->d_print("   - $user");
      create_user $user, %{ $conf->{$user} };
   }
}

sub _install_packages {
   my ($self, $conf) = @_;

   if(ref($conf)) {
      for my $pkg (@{$conf}) {
         Rex::IO::BMD->d_print("   - $pkg");
      }
   }
   else {
      Rex::IO::BMD->d_print("   - $conf");
   }

   install package => $conf;
}

sub _write_mbr {
   my ($self, $conf) = @_;

   file "/etc/mtab",
      content => cat "/proc/mounts";

   write_boot_record $conf->{write_to};
}


1;
