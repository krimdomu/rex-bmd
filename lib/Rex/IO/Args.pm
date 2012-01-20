#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::IO::Args;

use strict;
use warnings;

use Data::Dumper;

use vars qw($ARGS);

sub get {
   return $ARGS || {};
}

sub set {
   $ARGS = pop;
}

sub import {
   foreach my $o (@ARGV) {
      my($key, $val) = ($o =~ m/^--(.*?)=(.*)$/);
      if(!$key && !$val) {
         $o =~ m/^--(.*?)$/;
         $key = $1;
         $val = 1;
      }

      if(exists $ARGS->{$key}) {
         my @tmp;
         if(ref($ARGS->{$key})) {
            @tmp = @{$ARGS->{$key}};
         }
         else {
            @tmp = ($ARGS->{$key});
         }

         $ARGS->{$key} = [];
         push @tmp, $val;

         push(@{$ARGS->{$key}}, @tmp);
      }
      else {
         $ARGS->{$key} = $val;
      }
   }
}

1;
