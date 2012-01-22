#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::IO::Module::Bootstrap;
   
use strict;
use warnings;

require Rex::IO::Args;
require LWP::Simple;

use Data::Dumper;
use Rex::Commands;
use Rex::Commands::Run;
use Rex::Commands::Fs;
use Rex::Commands::File;
use Rex::Commands::Partition;
use Rex::Commands::System;
use Rex::Commands::Network;
use Rex::Commands::User;
use Rex::Commands::Pkg;

use YAML;

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

   $self->_partition($conf->{partitions});

   mkdir "/mnt" unless(is_dir("/mnt"));
   $self->_mount;

   my $url = $conf->{Url} || $conf->{url};
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
   
   for my $mount_point (keys %{$partitions}) {
      $self->{"__mount_point"}->{$mount_point} = $partitions->{$mount_point};
      my $device = partition($mount_point, %{ $partitions->{$mount_point} });
      $self->{"__mount_point"}->{$mount_point}->{"device"} = $device;
   }
}

sub _mount {
   my ($self) = @_;
   my $root_device = $self->{"__mount_point"}->{"/"};

   mount "/dev/".$root_device->{"device"}, "/mnt",
      fs => $root_device->{"fstype"};

   for my $mount_point (keys %{ $self->{"__mount_point"} }) {
      next if($mount_point eq "/");
      next if($mount_point eq "swap");
      next if($mount_point eq "none");

      mkdir "/mnt$mount_point" unless(is_dir("/mnt$mount_point"));
      mount "/dev/".$self->{"__mount_point"}->{$mount_point}->{device}, "/mnt$mount_point",
         fs => $self->{"__mount_point"}->{$mount_point}->{fstype};
   }
}

sub _download_image {
   my ($self, $url) = @_;

   chdir "/mnt";
   run "wget $url";
   my ($tar) = ($url =~ m/.*\/(.*?)$/);
   run "tar xzf $tar";
}

sub _chroot {
   my ($self, $conf) = @_;

   my $pid = fork;
   if($pid == 0) {
      cp "/etc/hosts", "/mnt/etc/hosts";
      cp "/etc/resolv.conf", "/mnt/etc/resolv.conf";
      run "echo 127.0.2.1 nfs-image >>/mnt/etc/hosts";

      run "mount -obind /dev /mnt/dev";
      
      chroot "/mnt";
      chdir "/";

      run "mount -t proc proc /proc";
      run "mount -t sysfs sysfs /sys";

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

      $self->_base_configuration($conf->{system});
      $self->_network_configuration($conf->{network});
      $self->_authentication($conf->{authentication});
      $self->_install_packages($conf->{packages});

      rm "/boot/grub/menu.lst";
      run "update-grub -y";
      run "rm -f /boot/initrd*";
      run "update-initramfs -k all -c";

      $self->_write_mbr($conf->{boot});

      run "umount /proc";
      run "umount /sys";

      exit; # exit child
   }
   else {
      waitpid($pid, 0);
      say "Long lost child came home... continuing work...";
      run "umount /mnt/dev";
      run "umount /mnt";
      run "sync";
      run "/sbin/reboot";
   }
}

sub _base_configuration {
   my ($self, $conf) = @_;

   if(exists $conf->{default_language}) {
      default_language $conf->{default_language};
   }

   if(exists $conf->{languages}) {
      languages @{ $conf->{languages} };
   }

   if(exists $conf->{timezone}) {
      timezone $conf->{timezone};
   }

   if(exists $conf->{keyboard}) {
      keyboard $conf->{keyboard};
   }

   if(exists $conf->{hostname}) {
      hostname $conf->{hostname};
   }

   if(exists $conf->{domainname}) {
      domainname $conf->{domainname};
   }

}

sub _network_configuration {
   my ($self, $conf) = @_;

   file "/etc/network/interfaces",
      content => "auto lo\niface lo inet loopback\n\n";

   for my $device (keys %{ $conf }) {
      network $device, %{ $conf->{$device} };
   }
}

sub _authentication {
   my ($self, $conf) = @_;

   for my $user (keys %{ $conf }) {
      create_user $user, %{ $conf->{$user} };
   }
}

sub _install_packages {
   my ($self, $conf) = @_;

   install package => $conf;
}

sub _write_mbr {
   my ($self, $conf) = @_;

   file "/etc/mtab",
      content => cat "/proc/mounts";

   write_boot_record $conf->{write_to};
}

1;
