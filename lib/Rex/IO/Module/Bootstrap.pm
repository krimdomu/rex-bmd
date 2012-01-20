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
use Rex::Commands::Fs;
use Rex::Commands::File;
use Rex::Commands::Partition;
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

      $self->install($install_info);
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
sub install {
   my ($self, $conf) = @_;

   $self->_partition($conf->{partitions});
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

1;
