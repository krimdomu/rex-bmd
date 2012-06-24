#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::IO::BMD;
   
use strict;
use warnings;

require Rex::IO::BMD::Args;
use Data::Dumper;
use Rex::Commands;
use Rex::Logger;

our $VERSION = "0.0.39";

$Rex::Logger::silent = 1;
$Rex::Logger::debug = 0;

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

   my $args = Rex::IO::BMD::Args->get;

   unless(exists $args->{module}) {
      die("No module given.");
   }

   my $mod = "Rex::IO::BMD::Module::" . $args->{module};
   eval "use $mod";

   if($@) {
      die("Can't load $mod");
   }

   my $mod_o = $mod->new;
   $mod_o->call;
}

sub d_print {
   my ($class, $msg, $line) = @_;

   if($line) { print "--------------------------------------------------------------------------------\n"; }
   print " $msg\n";
   if($line) { print "--------------------------------------------------------------------------------\n"; }
}

1;
