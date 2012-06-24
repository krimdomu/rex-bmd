#!/usr/bin/perl -w

#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   

use strict;
use warnings;

use Cwd qw(getcwd);
use Rex::IO;
use Rex::IO::Args;

if($< == 0 && $> == 0) {
   $::path = getcwd;
   my $rex_io = Rex::IO->new(path => $::path);
   $rex_io->call;
}
else {
   print "Please run rex.io with as root.\n";
   exit 1;
}
