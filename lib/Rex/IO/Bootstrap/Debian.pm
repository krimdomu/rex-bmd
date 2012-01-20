#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::IO::Bootstrap::Debian;
   
use strict;
use warnings;

require Rex::IO::Args;

use Cwd qw(getcwd);

use Rex::Commands;
use Rex::Commands::Fs;
use Rex::Commands::File;
use Rex::Commands::Run;
use Rex::Commands::Gather;
use Rex::Commands::Pkg;
use Rex::Commands::User;
use Rex::Commands::Network;

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   return $self;
}

sub call {
   my ($self) = @_;

   my $args    = Rex::IO::Args->get;

   my $dist    = $args->{dist};
   my $version = $args->{version};
   my $arch    = $args->{arch};

   my $codename = $self->get_codename_for($version);

   mkdir "nfs-image/filesystem.d";
   mkdir "base-image/filesystem.d";
   mkdir "tftpd-root/pxelinux.cfg";
   mkdir "log";

   if(is_debian) {
      say "Creating nfs-image...";
      run "debootstrap $codename nfs-image/filesystem.d 2>&1 >log/bootstrap.log";
   }
   else {
      die("Currently only support for Debian like systems.");
   }

   file "$::path/nfs-image/filesystem.d/etc/resolv.conf",
      content => cat "/etc/resolv.conf";

   file "$::path/nfs-image/filesystem.d/etc/hosts",
      source => "/etc/hosts";

   # forking the chrooted task
   my $pid = fork;
   if($pid == 0) {
      chroot "$::path/nfs-image/filesystem.d/";
      chdir "/";
      run "mount /proc";
      run "mount /sys";
      run "mount /dev";
      run "mount /dev/pts";

      if(is_debian) {
         say "Running apt-get update";
         run "apt-get update";

         say "Installing wget and libdigest-perl";
         run "apt-get -y install wget libdigest-perl";

         $self->prepare_repo_data($codename);

         say "Installing rex";
         run "apt-get -y install rex";

         mkdir "/boot/grub";
         file "/boot/grub/menu.lst",
            content => "";

         install package => [qw/wget grub linux-image-server parted perl syslinux-common/];

         file "/etc/hostname",
            content => "nfs-image\n";

         file "/etc/fstab",
            content => "# automated generated fstab for nfs boot
proc            /proc           proc    defaults        0       0
/dev/nfs        /               nfs     defaults        1       1
none            /tmp            tmpfs   defaults        0       0
none            /var/run        tmpfs   defaults        0       0
none            /var/lock       tmpfs   defaults        0       0
none            /var/tmp        tmpfs   defaults        0       0
            ";

         file "/etc/network/interfaces",
            content => "# automated generated file
auto lo eth0
iface lo inet loopback
iface eth0 inet dhcp
            ";

         cp "/etc/initramfs-tools/initramfs.conf", "/etc/initramfs-tools/initramfs.conf.bak";

         run "sed -ie 's/BOOT=local/BOOT=nfs/' /etc/initramfs-tools/initramfs.conf";
         run "sed -ie 's/MODULES=most/MODULES=netboot/' /etc/initramfs-tools/initramfs.conf";

         my $kversion = run "ls /boot/vmlinuz-* | perl -lne 'print \$1 if /vmlinuz-([0-9\.\-]+)-server/'";

         say "Generating new initramfs for linux-image-server-$kversion";
         say join("\n", run "update-initramfs -c -k $kversion-server -b /boot");

      }

      create_user "root",
         uid => 0,
         password => "f00b4r";

      run "umount /dev/pts";
      run "umount /proc";
      run "umount /sys";
      run "umount /dev";

      exit; # exit fork
   }
   else {
      waitpid($pid, 0);
      say "Long lost child came home... continuing work...";
   }

   say "Creating baseimgage";
   cp "nfs-image/filesystem.d/etc/initramfs-tools/initramfs.conf.bak", "nfs-image/filesystem.d/etc/initramfs-tools/initramfs.conf";
   run "cd nfs-image/filesystem.d; tar czf $::path/base-image/\L$dist-$version.tar.gz *";

   say "Populating tftpd-root";
   run "cp nfs-image/filesystem.d/boot/initrd* nfs-image/filesystem.d/boot/vmlinuz* tftpd-root";
   run "cp nfs-image/filesystem.d/usr/lib/syslinux/pxelinux.0 tftpd-root";

   my $kernel = run "ls tftpd-root/vmlinuz*";
   my $initrd = run "ls tftpd-root/initrd*";

   my $ip = "IP-OF-YOUR-DNS-SERVER";

   $kernel =~ s/^tftpd-root\///;
   $initrd =~ s/^tftpd-root\///;

   file "$::path/tftpd-root/pxelinux.cfg/default",
      content => "
DEFAULT RexOsDeployment
  
LABEL RexOsDeployment
KERNEL $kernel
APPEND root=/dev/nfs initrd=$initrd nfsroot=$ip:$::path/nfs-image/filesystem.d ip=dhcp rw

";

   say "================================================================================";
   say "* You're installation image is now ready. Please follow the next steps";
   say "* ";
   say "* Now you've to setup your dhcp, tftpd, nfs and webserver.";
   say "* = DHCP: =";
   say "* ";
   say "* This is an example snippet for isc-dhcp-server";
   say "* 
subnet 192.168.0.0 netmask 255.255.255.0 {
        range 192.168.0.10 192.168.0.100;
        option broadcast-address 192.168.0.255;
        option routers 192.168.0.1;
        option domain-name-servers 192.168.0.1;

        filename \"/pxelinux.0\";
}";

   say "*\n*\n";
   say "* = TFTPD: =";
   say "* Point the TFTPd root directory to " . getcwd() . "/tftpd-root";
   say "* Examine the file tftpd-root/pxelinux.cfg/default and change it to suite your needs.";
   say "*\n*\n";
   say "* = HTTPd: =";
   say "* Copy the file base-image/*.tar.gz to your webserver root.";
   say "*\n*\n";
   say "* = NFS: =";
   say "* Configure your nfs server to export the nfs-image directory:";
   say "* \n";
   say "* $::path/nfs-image/filesystem.d     192.168.0.0/255.255.255.0(rw,no_root_squash,no_subtree_check,async,insecure)";
   say "*\n*\n";

}

1;
