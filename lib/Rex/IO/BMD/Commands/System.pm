#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
   
=head1 NAME

Rex::IO::BMD::Commands::System - System specific functions

=head1 DESCRIPTION

With this Module you can manage some system specific configurations.

=head1 SYNOPSIS

 use Rex::IO::BMD::Commands::System;
     

=head1 EXPORTED FUNCTIONS

=over 4

=cut

package Rex::IO::BMD::Commands::System;
   
use strict;
use warnings;

require Exporter;
use base qw(Exporter);
use vars qw(@EXPORT);

use Rex::IO::BMD::System;

@EXPORT = qw(default_language languages keyboard timezone write_boot_record);

=item default_language($lang)

Set the default language.

 default_language "en_US.UTF-8";

=cut
sub default_language {
   my $system = Rex::IO::BMD::System->get;
   $system->default_language(@_);
}

=item language($lang1, $lang2, ...);

Set all available languages on a system.

 languages qw/en_US en_US.UTF-8/;

=cut
sub languages {
   my $system = Rex::IO::BMD::System->get;
   $system->languages(@_);
}

=item keyboard($keymap)

Set the keymap of a system.

 keyboard "de-latin1-nodeadkeys";

=cut
sub keyboard {
   my $system = Rex::IO::BMD::System->get;
   $system->keyboard(@_);
}

=item timezone($timezone)

Set the timezone of a system.

 timezone "UTC";

=cut
sub timezone {
   my $system = Rex::IO::BMD::System->get;
   $system->timezone(@_)
}

=item write_boot_record($device)

This function tries to write the boot record. Currently it supports only grub (version 1).

=cut
sub write_boot_record {
   my $system = Rex::IO::BMD::System->get;
   $system->write_boot_record(@_);
}

sub hostname {
   my $system = Rex::IO::BMD::System->get;
   $system->hostname(@_);
}

sub domainname {
   my $system = Rex::IO::BMD::System->get;
   $system->domainname(@_);
}

sub network {
   my $system = Rex::IO::BMD::System->get;
   $system->network(@_);
}


1;
