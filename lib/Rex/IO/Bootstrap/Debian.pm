#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::IO::Bootstrap::Debian;
   
use strict;
use warnings;

require Rex::IO::Args;

use Rex::Commands::Gather;

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   return $self;
}

sub run {
   my ($self) = @_;

   my $args    = Rex::IO::Args->get;

   my $dist    = $args->{dist};
   my $version = $args->{version};
   my $arch    = $args->{arch};

}

1;
