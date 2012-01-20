#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::IO::Module::Bootstrap;
   
use strict;
use warnings;

require Rex::IO::Args;
use Data::Dumper;

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   return $self;
}

sub call {
   my ($self) = @_;

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

1;
