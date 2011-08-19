#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::IO::Provider::Jiffybox;
   
use strict;
use warnings;

sub get_create_options {
   my ($class, %pre_defined) = @_;

   my $options = {
      name => $pre_defined{"name"},
      image_id => "debian_squeeze_64bit",
      plan_id => 10,
      password => $pre_defined{"password"},
   };

   return $options;
}
   
1;
