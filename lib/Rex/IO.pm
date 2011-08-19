#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::IO;
   
use strict;
use warnings;

use Rex;
use Rex::Config;
use Rex::Commands;
use Rex::Task;

use Rex::Commands::Cloud;

use Rex::File::Parser::Ini;

use Rex::IO::Task::Instance;
use Rex::IO::Task::Repository;
use Rex::IO::Task::ServerControl;
use Rex::IO::Task::Deploy::Sync;

use Data::Dumper;

   
sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   $self->{"fp"} = Rex::File::Parser::Ini->new(file => "cloud.ini");
   $self->{"fp"}->read;

   return $self;
}

sub _auth {

   my ($self) = @_;

   $self->{"__cloud_service"} = $self->config->get("cloud", "service");
   cloud_service($self->{"__cloud_service"});

   user($self->config->get("systemauth", "user"));
   password($self->config->get("systemauth", "password"));
   pass_auth;

   if($self->{"__cloud_service"} eq "Amazon") {
      die("Not supported yet");
   }
   elsif($self->{"__cloud_service"} eq "Jiffybox") {
      cloud_auth($self->config->get("cloud", "access_key"));
   }



}

sub create {
   my ($self) = @_;

   $self->_auth;

   for my $service ($self->config->get_sections) {
      next if ($service eq "cloud");
      next if ($service eq "systemauth");

      d_print("Creating $service");

      my $data = Rex::IO::Task::Instance::create({
         name     => $service . "01",
         password => $self->config->get("systemauth", "password"),
      });

      # cloud service = jiffybox
      # @todo - unabhaengig

      my $server = $data->{"result"}->{"ips"}->{"public"}->[0];
      Rex::Task->run("IO:Task:Repository:initialize", $server);
      Rex::Task->run("IO:Task:ServerControl:prepare", $server);

      if($self->config->get($service, "type") eq "static") {
         Rex::Task->run("IO:Task:ServerControl:create-apache", $server, {
            name => "${service}01"
         });
      }
      elsif($self->config->get($service, "type") eq "php") {
         Rex::Task->run("IO:Task:ServerControl:create-apache-php", $server, {
            name => "${service}01"
         });
      }
   }
   
}

sub deploy {
   my ($self) = @_;

   $self->_auth;
   # if static -> Rsync

   for my $service ($self->config->get_sections) {
      next if ($service eq "cloud");
      next if ($service eq "systemauth");

      d_print("Deploying $service");

      my @i_list = cloud_instance_list();
      my $s_name = $service . "01";
      my ($instance) = grep { $_->{"name"} eq $s_name } @i_list;

      my $server = $instance->{"ip"};

      Rex::Task->run("IO:Task:Deploy:Sync:up", $server, {
         source => $self->config->get($service, "root") . "/",
         destination => "/services/${service}01/var/htdocs",
      });


      Rex::Task->run("IO:Task:ServerControl:restart-apache", $server, {
         name => "${service}01"
      });

      d_print("");
      d_print("Your website is now available under http://" . $server);
      d_print("");

   }

}

sub config {
   my ($self) = @_;
   return $self->{"fp"};
}

sub d_print {
   my ($msg) = @_;
   print STDERR ">> $msg\n";
}

   
1;
