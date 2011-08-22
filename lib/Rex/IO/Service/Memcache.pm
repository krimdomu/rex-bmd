#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::IO::Service::Memcache;
   
use strict;
use warnings;
 
use Rex;
use Rex::Config;
use Rex::Commands;
use Rex::Task;

sub run {

   my ($class, $server, $service, $count) = @_;

   Rex::Task->run("IO:Task:ServerControl:create-memcache", $server, {
      name => "${service}${count}"
   });

}

   
1;
