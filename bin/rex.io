#!/opt/local/bin/perl -w

#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   

use strict;
use warnings;

use Rex::IO;
use Rex::IO::Args;

my $rex_io = Rex::IO->new;
$rex_io->run;

