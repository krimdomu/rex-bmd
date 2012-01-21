#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::IO;
   
use strict;
use warnings;

require Rex::IO::Args;
use Data::Dumper;
use Rex::Commands;

our $VERSION = "0.0.9";

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   logging to_file => "/dev/null";

   return $self;
}

sub call {
   my ($self) = @_;

   my $args = Rex::IO::Args->get;

   unless(exists $args->{module}) {
      die("No module given.");
   }

   my $mod = "Rex::IO::Module::" . $args->{module};
   eval "use $mod";

   if($@) {
      die("Can't load $mod");
   }

   my $mod_o = $mod->new;
   $mod_o->call;
}

1;
