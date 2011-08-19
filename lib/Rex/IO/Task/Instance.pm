#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::IO::Task::Instance;
   
use strict;
use warnings;

use Rex::Commands;
use Rex::Commands::Cloud;

use Rex::IO::Provider::Jiffybox;

use Data::Dumper;

task "create", sub {

   my $param = shift;

   # spawn a new server instance
   my $data = cloud_instance create => Rex::IO::Provider::Jiffybox->get_create_options(%{$param});

   return $data;

};
   
1;
