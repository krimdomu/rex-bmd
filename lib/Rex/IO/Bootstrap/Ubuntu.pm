#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::IO::Bootstrap::Ubuntu;
   
use strict;
use warnings;

use Rex::IO::Bootstrap::Debian;
use base qw(Rex::IO::Bootstrap::Debian);

use Rex::Commands;
use Rex::Commands::Run;
use Rex::Commands::File;

sub get_dist_name {
   return "Ubuntu";
}

sub prepare_repo_data {
   my ($self, $codename) = @_;

   say join ("\n", run "wget -O - http://stage.rex.linux-files.org/DPKG-GPG-KEY-REXIFY-REPO | apt-key add -");

   file "/etc/apt/sources.list",
      content => "# See http://help.ubuntu.com/community/UpgradeNotes for how to upgrade to
# newer versions of the distribution.
deb http://us.archive.ubuntu.com/ubuntu/ $codename main restricted
deb-src http://us.archive.ubuntu.com/ubuntu/ $codename main restricted

## Major bug fix updates produced after the final release of the
## distribution.
deb http://us.archive.ubuntu.com/ubuntu/ $codename-updates main restricted
deb-src http://us.archive.ubuntu.com/ubuntu/ $codename-updates main restricted

## N.B. software from this repository is ENTIRELY UNSUPPORTED by the Ubuntu
## team. Also, please note that software in universe WILL NOT receive any
## review or updates from the Ubuntu security team.
deb http://us.archive.ubuntu.com/ubuntu/ $codename universe
deb-src http://us.archive.ubuntu.com/ubuntu/ $codename universe
deb http://us.archive.ubuntu.com/ubuntu/ $codename-updates universe
deb-src http://us.archive.ubuntu.com/ubuntu/ $codename-updates universe

## N.B. software from this repository is ENTIRELY UNSUPPORTED by the Ubuntu 
## team, and may not be under a free licence. Please satisfy yourself as to 
## your rights to use the software. Also, please note that software in 
## multiverse WILL NOT receive any review or updates from the Ubuntu
## security team.
deb http://us.archive.ubuntu.com/ubuntu/ $codename multiverse
deb-src http://us.archive.ubuntu.com/ubuntu/ $codename multiverse
deb http://us.archive.ubuntu.com/ubuntu/ $codename-updates multiverse
deb-src http://us.archive.ubuntu.com/ubuntu/ $codename-updates multiverse

## Uncomment the following two lines to add software from the 'backports'
## repository.
## N.B. software from this repository may not have been tested as
## extensively as that contained in the main release, although it includes
## newer versions of some applications which may provide useful features.
## Also, please note that software in backports WILL NOT receive any review
## or updates from the Ubuntu security team.
# deb http://us.archive.ubuntu.com/ubuntu/ natty-backports main restricted universe multiverse
# deb-src http://us.archive.ubuntu.com/ubuntu/ natty-backports main restricted universe multiverse

deb http://security.ubuntu.com/ubuntu $codename-security main restricted
deb-src http://security.ubuntu.com/ubuntu $codename-security main restricted
deb http://security.ubuntu.com/ubuntu $codename-security universe
deb-src http://security.ubuntu.com/ubuntu $codename-security universe
deb http://security.ubuntu.com/ubuntu $codename-security multiverse
deb-src http://security.ubuntu.com/ubuntu $codename-security multiverse

## This software is not part of Ubuntu, but is offered by third-party
## developers who want to ship their latest software.
deb http://extras.ubuntu.com/ubuntu $codename main
deb-src http://extras.ubuntu.com/ubuntu $codename main

deb http://stage.rex.linux-files.org/ubuntu/ $codename rex
";

   say join("\n", run "apt-get update");

}

sub get_codename_for {
   my ($self, $version) = @_;

   my %codename_for = (
      "10.04" => "lucid",
      "10.10" => "maverick",
      "11.04" => "natty",
      "11.10" => "oneiric",
      "12.04" => "precise",
   );

   return $codename_for{$version};
}

sub get_mirror {
   my ($self) = @_;
   return "http://us.archive.ubuntu.com/ubuntu";
}

sub get_kernel {
   my ($self, $arch) = @_;
   return "linux-image-server";
}



1;
