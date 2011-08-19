#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::IO::Task::Repository;
   
use strict;
use warnings;
 
use Rex::Commands;
use Rex::Commands::Run;
use Rex::Commands::Pkg;

task "initialize", sub {

   run "wget -O - http://rex.linux-files.org/DPKG-GPG-KEY-REXIFY-REPO | apt-key add -";

   repository "add" => "servercontrol",
      url => "http://servercontrol.linux-files.org/debian",
      distro => "squeeze",
      repository => "servercontrol";

   update_package_db;

};
   
1;
