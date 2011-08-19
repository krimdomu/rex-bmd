#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::IO::Task::Deploy::Sync;
   
use strict;
use warnings;

use Rex::Commands;
use Rex::Commands::Rsync;

use Expect;

task "up", sub {

   my $param = shift;
   $Expect::Log_Stdout = 0;
   sync $param->{"source"}, $param->{"destination"};

};
   
1;
