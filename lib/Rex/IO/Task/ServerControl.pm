#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::IO::Task::ServerControl;
   
use strict;
use warnings;

use Rex::Commands;
use Rex::Commands::Run;
use Rex::Commands::Pkg;
use Rex::Commands::File;
use Rex::Commands::Fs;
use Rex::Commands::Service;

use Rex::File::Parser::Data;


my @data = <DATA>;

task "prepare", sub {

   install package => [qw/servercontrol servercontrol-mod-apache rsync/];

   if(!is_dir("/services")) {
      mkdir("/services");
      mkdir("/services/templates");
      mkdir("/services/templates/apache2");
      mkdir("/services/layouts");
   }

};

task "create-apache", sub {

   my $param = shift;

   my $fp = Rex::File::Parser::Data->new(data => \@data);

   my $layout = $fp->read("layouts/apache.yml");
   my $httpd_conf = $fp->read("etc/httpd.conf");

   install package => qw/apache2/;

   service "apache2" => "ensure", "stopped";

   file "/services/layouts/apache.yml",
      content => $layout;

   file "/services/templates/apache2/httpd.conf",
      content => $httpd_conf;

   run "servercontrol --schema=Debian --module=Apache --path=/services/" . $param->{name} . " --name=" . $param->{name} . " --user=www-data --group=www-data --fs-layout=/services/layouts/apache.yml --template=/services/templates/apache2/httpd.conf --create --ip='*' --port=80 --internal_net=127.0.0.0/8 --serveradmin=webmaster\@localhost";

};

task "create-apache-php", sub {

   my $param = shift;

   my $fp = Rex::File::Parser::Data->new(data => \@data);

   my $layout = $fp->read("layouts/apache.yml");
   my $httpd_conf = $fp->read("etc/httpd.conf");

   install package => [qw/apache2 libapache2-mod-php5/];

   service "apache2" => "ensure", "stopped";

   file "/services/layouts/apache.yml",
      content => $layout;

   file "/services/templates/apache2/httpd.conf",
      content => $httpd_conf;

   run "servercontrol --schema=Debian --module=Apache --path=/services/" . $param->{name} . " --name=" . $param->{name} . " --user=www-data --group=www-data --fs-layout=/services/layouts/apache.yml --template=/services/templates/apache2/httpd.conf --create --ip='*' --port=80 --internal_net=127.0.0.0/8 --serveradmin=webmaster\@localhost --with-php";

};



task "restart-apache", sub {

   my $param = shift;
   run "/services/" . $param->{name} . "/stop";
   run "/services/" . $param->{name} . "/start";

};

1;

__DATA__


@layouts/apache.yml

Directories:
   Base:
      bin:
         name: bin
         chmod: 755
         user: root
         group: root
      htdocs:
         name: var/htdocs
         chmod: 755
         user: <%= ServerControl::Args->get->{'user'} %>
         group: <%= ServerControl::Args->get->{'group'} %>
      cgi:
         name: var/cgi-bin
         chmod: 755
         user: <%= ServerControl::Args->get->{'user'} %>
         group: <%= ServerControl::Args->get->{'group'} %>
      error:
         name: var/error
         chmod: 755
         user: <%= ServerControl::Args->get->{'user'} %>
         group: <%= ServerControl::Args->get->{'group'} %>

   Configuration:
      conf:
         name: etc
         chmod: 755
         user: root
         group: root
      httpdconf:
         name: etc/httpd-conf.d
         chmod: 755
         user: root
         group: root
      vhostconf:
         name: etc/vhost-conf.d
         chmod: 755
         user: root
         group: root
   Runtime:
      pid:
         name: var/run
         chmod: 755
         user: <%= ServerControl::Args->get->{'user'} %>
         group: <%= ServerControl::Args->get->{'group'} %>
      log:
         name: var/log
         chmod: 755
         user: <%= ServerControl::Args->get->{'user'} %>
         group: <%= ServerControl::Args->get->{'group'} %>

Files:
   Exec:
      httpd:
         name: bin/httpd-<%= __PACKAGE__->get_name %>
         link: <%= ServerControl::Schema->get('httpd') %>
   Base:
      modules:
         name: modules
         link: <%= ServerControl::Schema->get('modules') %>
   Configuration:
      magic:
         name: etc/magic
         link: <%= ServerControl::Schema->get('magic') %>
      mime:
         name: etc/mime.types
         link: <%= ServerControl::Schema->get('mime.types') %>
      httpdconf:
         name: etc/httpd.conf
         call: <% sub { ServerControl::Template->parse(@_); } %>

@end

@etc/httpd.conf

######## BASIC CONFIGURATION ###########

ServerTokens Off

# ServerRoot: The top of the directory tree under which the server's
# configuration, error, and log files are kept.
ServerRoot "@instance_path@"

# PidFile: The file in which the server should record its process
# identification number when it starts.
PidFile var/run/httpd.pid

# Timeout: The number of seconds before receives and sends time out.
Timeout 120

# KeepAlive: Whether or not to allow persistent connections (more than
# one request per connection). Set to "Off" to deactivate.
KeepAlive On

# MaxKeepAliveRequests: The maximum number of requests to allow
# during a persistent connection. Set to 0 to allow an unlimited amount.
MaxKeepAliveRequests 100

# KeepAliveTimeout: Number of seconds to wait for the next request from the
# same client on the same connection.
KeepAliveTimeout 15

# User and Group
User @user@
Group @group@

##
## Server-Pool Size Regulation (MPM specific)
## 

# prefork MPM
# StartServers: number of server processes to start
# MinSpareServers: minimum number of server processes which are kept spare
# MaxSpareServers: maximum number of server processes which are kept spare
# ServerLimit: maximum value for MaxClients for the lifetime of the server
# MaxClients: maximum number of server processes allowed to start
# MaxRequestsPerChild: maximum number of requests a server process serves
<IfModule prefork.c>
   StartServers       8
   MinSpareServers    5
   MaxSpareServers   20
   ServerLimit      256
   MaxClients       256
   MaxRequestsPerChild  4000
</IfModule>

# worker MPM
# StartServers: initial number of server processes to start
# MaxClients: maximum number of simultaneous client connections
# MinSpareThreads: minimum number of worker threads which are kept spare
# MaxSpareThreads: maximum number of worker threads which are kept spare
# ThreadsPerChild: constant number of worker threads in each server process
# MaxRequestsPerChild: maximum number of requests a server process serves
<IfModule worker.c>
   StartServers         2
   MaxClients         150
   MinSpareThreads     25
   MaxSpareThreads     75 
   ThreadsPerChild     25
   MaxRequestsPerChild  0
</IfModule>

#
# Listen: Allows you to bind Apache to specific IP addresses and/or
# ports, in addition to the default. See also the <VirtualHost>
# directive.
#
# Change this to Listen on specific IP addresses as shown below to 
# prevent Apache from glomming onto all bound IP addresses (0.0.0.0)
#
Listen @ip@:@port@

############## MODULE SECTION ################
LoadModule auth_basic_module modules/mod_auth_basic.so
LoadModule authn_file_module modules/mod_authn_file.so
LoadModule authn_default_module modules/mod_authn_default.so
LoadModule authz_host_module modules/mod_authz_host.so
LoadModule authz_user_module modules/mod_authz_user.so
LoadModule authz_owner_module modules/mod_authz_owner.so
LoadModule authz_groupfile_module modules/mod_authz_groupfile.so
LoadModule authz_default_module modules/mod_authz_default.so
<IfDefine LDAP>
   LoadModule ldap_module modules/mod_ldap.so
   <IfDefine LDAPAUTH>
      LoadModule authnz_ldap_module modules/mod_authnz_ldap.so
   </IfDefine>
</IfDefine>

LoadModule include_module modules/mod_include.so

<IfModule !log_config_module>
	LoadModule log_config_module modules/mod_log_config.so
</IfModule>

<IfModule !logio_module>
	LoadModule logio_module modules/mod_logio.so
</IfModule>

LoadModule env_module modules/mod_env.so
LoadModule mime_magic_module modules/mod_mime_magic.so
LoadModule expires_module modules/mod_expires.so
LoadModule deflate_module modules/mod_deflate.so
LoadModule headers_module modules/mod_headers.so
LoadModule setenvif_module modules/mod_setenvif.so
LoadModule mime_module modules/mod_mime.so
LoadModule status_module modules/mod_status.so
LoadModule info_module modules/mod_info.so
LoadModule vhost_alias_module modules/mod_vhost_alias.so
LoadModule negotiation_module modules/mod_negotiation.so
LoadModule dir_module modules/mod_dir.so
LoadModule actions_module modules/mod_actions.so
LoadModule alias_module modules/mod_alias.so
LoadModule autoindex_module modules/mod_autoindex.so

# LoadModule speling_module modules/mod_speling.so
<IfDefine SUEXEC>
   LoadModule suexec_module modules/mod_suexec.so
</IfDefine>

# LoadModule version_module modules/mod_version.so
# LoadModule usertrack_module modules/mod_usertrack.so
# LoadModule ext_filter_module modules/mod_ext_filter.so

<IfDefine AUTHALIAS>
   LoadModule authn_alias_module modules/mod_authn_alias.so
</IfDefine>
<IfDefine AUTHDBM>
	LoadModule authn_dbm_module modules/mod_authn_dbm.so
	LoadModule authz_dbm_module modules/mod_authz_dbm.so
</IfDefine>
<IfDefine AUTHANON>
	LoadModule authn_anon_module modules/mod_authn_anon.so
</IfDefine>
<IfDefine AUTHDIGEST>
	LoadModule auth_digest_module modules/mod_auth_digest.so
</IfDefine>
<IfDefine DAV>
	LoadModule dav_module modules/mod_dav.so
	LoadModule dav_fs_module modules/mod_dav_fs.so
</IfDefine>
<IfDefine USERDIR>
	LoadModule userdir_module modules/mod_userdir.so
</IfDefine>
<IfDefine REWRITE>
	LoadModule rewrite_module modules/mod_rewrite.so
</IfDefine>
<IfDefine PROXY>
	LoadModule proxy_module modules/mod_proxy.so
	LoadModule proxy_balancer_module modules/mod_proxy_balancer.so
	LoadModule proxy_ftp_module modules/mod_proxy_ftp.so
	LoadModule proxy_http_module modules/mod_proxy_http.so
	LoadModule proxy_connect_module modules/mod_proxy_connect.so
</IfDefine>
<IfDefine CACHE>
	LoadModule cache_module modules/mod_cache.so
	LoadModule disk_cache_module modules/mod_disk_cache.so
	LoadModule file_cache_module modules/mod_file_cache.so
	LoadModule mem_cache_module modules/mod_mem_cache.so
</IfDefine>
<IfDefine CGI>
	LoadModule cgi_module modules/mod_cgi.so
</IfDefine>
<IfDefine SVN>
	LoadModule dav_svn_module     modules/mod_dav_svn.so
	LoadModule authz_svn_module   modules/mod_authz_svn.so
</IfDefine>
<IfDefine PHP>
	LoadModule php5_module modules/libphp5.so

	AddHandler php5-script .php .php3 .php4 .php5
	AddType text/html .php
	AddType text/html .php3
	AddType text/html .php4
	AddType text/html .php5

	#AddType application/x-httpd-php-source .phps
	php_value session.save_path "@instance_path@/tmp"
   PHPINIDir "@instance_path@/etc"
</IfDefine>
<IfDefine PERL>
	LoadModule perl_module modules/mod_perl.so
</IfDefine>


############### ADDITIONAL CONFIG FILES ##############
#
# Load config files from the config directory "/etc/httpd/conf.d".
#
Include etc/httpd-conf.d/*.conf
Include etc/vhost-conf.d/*.conf

# ExtendedStatus controls whether Apache will generate "full" status
# information (ExtendedStatus On) or just basic information (ExtendedStatus
# Off) when the "server-status" handler is called. The default is Off.
ExtendedStatus On

# ServerAdmin: Your address, where problems with the server should be
# e-mailed.  This address appears on some server-generated pages, such
# as error documents.  e.g. admin@your-domain.com
ServerAdmin @serveradmin@

# You will have to access it by its address anyway, and this will make 
# redirections work in a sensible way.
#
#ServerName www.example.com:80

# UseCanonicalName: Determines how Apache constructs self-referencing 
# URLs and the SERVER_NAME and SERVER_PORT variables.
UseCanonicalName Off

# DocumentRoot: The directory out of which you will serve your
# documents. By default, all requests are taken from this directory, but
# symbolic links and aliases may be used to point to other locations.
DocumentRoot @instance_path@/var/htdocs

#
# Each directory to which Apache has access can be configured with respect
# to which services and features are allowed and/or disabled in that
# directory (and its subdirectories). 
#
# First, we configure the "default" to be a very restrictive set of 
# features.  
#
<Directory />
    Options FollowSymLinks
    AllowOverride None
</Directory>

#
# Note that from this point forward you must specifically allow
# particular features to be enabled - so if something's not working as
# you might expect, make sure that you have specifically enabled it
# below.
#

#
# This should be changed to whatever you set DocumentRoot to.
#
<Directory "@instance_path@/var/htdocs">

#
# Possible values for the Options directive are "None", "All",
# or any combination of:
#   Indexes Includes FollowSymLinks SymLinksifOwnerMatch ExecCGI MultiViews
#
# Note that "MultiViews" must be named *explicitly* --- "Options All"
# doesn't give it to you.
#
# The Options directive is both complicated and important.  Please see
# http://httpd.apache.org/docs/2.2/mod/core.html#options
# for more information.
#
    Options -Indexes FollowSymLinks

#
# AllowOverride controls what directives may be placed in .htaccess files.
# It can be "All", "None", or any combination of the keywords:
#   Options FileInfo AuthConfig Limit
#
    AllowOverride None

#
# Controls who can get stuff from this server.
#
    Order allow,deny
    Allow from all

</Directory>

#
# UserDir: The name of the directory that is appended onto a user's home
# directory if a ~user request is received.
#
# The path to the end user account 'public_html' directory must be
# accessible to the webserver userid.  This usually means that ~userid
# must have permissions of 711, ~userid/public_html must have permissions
# of 755, and documents contained therein must be world-readable.
# Otherwise, the client will only receive a "403 Forbidden" message.
#
# See also: http://httpd.apache.org/docs/misc/FAQ.html#forbidden
#
<IfModule mod_userdir.c>
    #
    # UserDir is disabled by default since it can confirm the presence
    # of a username on the system (depending on home directory
    # permissions).
    #
    UserDir disable

    #
    # To enable requests to /~user/ to serve the user's public_html
    # directory, remove the "UserDir disable" line above, and uncomment
    # the following line instead:
    # 
    #UserDir public_html

</IfModule>

#
# DirectoryIndex: sets the file that Apache will serve if a directory
# is requested.
#
# The index.html.var file (a type-map) is used to deliver content-
# negotiated documents.  The MultiViews Option can be used for the 
# same purpose, but it is much slower.
#
DirectoryIndex index.html index.htm index.php

#
# AccessFileName: The name of the file to look for in each directory
# for additional configuration directives.  See also the AllowOverride
# directive.
#
AccessFileName .htaccess

#
# The following lines prevent .htaccess and .htpasswd files from being 
# viewed by Web clients. 
#
<Files ~ "^\.ht">
    Order allow,deny
    Deny from all
</Files>

#
# TypesConfig describes where the mime.types file (or equivalent) is
# to be found.
#
TypesConfig @instance_path@/etc/mime.types

#
# DefaultType is the default MIME type the server will use for a document
# if it cannot otherwise determine one, such as from filename extensions.
# If your server contains mostly text or HTML documents, "text/plain" is
# a good value.  If most of your content is binary, such as applications
# or images, you may want to use "application/octet-stream" instead to
# keep browsers from trying to display binary files as though they are
# text.
#
DefaultType text/plain

#
# The mod_mime_magic module allows the server to use various hints from the
# contents of the file itself to determine its type.  The MIMEMagicFile
# directive tells the module where the hint definitions are located.
#
<IfModule mod_mime_magic.c>
    MIMEMagicFile @instance_path@/etc/magic
</IfModule>

#
# HostnameLookups: Log the names of clients or just their IP addresses
# e.g., www.apache.org (on) or 204.62.129.132 (off).
# The default is off because it'd be overall better for the net if people
# had to knowingly turn this feature on, since enabling it means that
# each client request will result in AT LEAST one lookup request to the
# nameserver.
#
HostnameLookups Off

#
# EnableMMAP: Control whether memory-mapping is used to deliver
# files (assuming that the underlying OS supports it).
# The default is on; turn this off if you serve from NFS-mounted 
# filesystems.  On some systems, turning it off (regardless of
# filesystem) can improve performance; for details, please see
# http://httpd.apache.org/docs/2.2/mod/core.html#enablemmap
#
#EnableMMAP off

#
# EnableSendfile: Control whether the sendfile kernel support is 
# used to deliver files (assuming that the OS supports it). 
# The default is on; turn this off if you serve from NFS-mounted 
# filesystems.  Please see
# http://httpd.apache.org/docs/2.2/mod/core.html#enablesendfile
#
#EnableSendfile off

#
# ErrorLog: The location of the error log file.
# If you do not specify an ErrorLog directive within a <VirtualHost>
# container, error messages relating to that virtual host will be
# logged here.  If you *do* define an error logfile for a <VirtualHost>
# container, that host's errors will be logged there and not here.
#
ErrorLog var/log/error_log

#
# LogLevel: Control the number of messages logged to the error_log.
# Possible values include: debug, info, notice, warn, error, crit,
# alert, emerg.
#
LogLevel warn

#
# The following directives define some format nicknames for use with
# a CustomLog directive (see below).
#
LogFormat "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\"" combined
LogFormat "%h %l %u %t \"%r\" %>s %b" common
LogFormat "%{Referer}i -> %U" referer
LogFormat "%{User-agent}i" agent

# "combinedio" includes actual counts of actual bytes received (%I) and sent (%O); this
# requires the mod_logio module to be loaded.
#LogFormat "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\" %I %O" combinedio

#
# The location and format of the access logfile (Common Logfile Format).
# If you do not define any access logfiles within a <VirtualHost>
# container, they will be logged here.  Contrariwise, if you *do*
# define per-<VirtualHost> access logfiles, transactions will be
# logged therein and *not* in this file.
#
#CustomLog logs/access_log common

#
# If you would like to have separate agent and referer logfiles, uncomment
# the following directives.
#
#CustomLog logs/referer_log referer
#CustomLog logs/agent_log agent

#
# For a single logfile with access, agent, and referer information
# (Combined Logfile Format), use the following directive:
#
CustomLog var/log/access_log combined

#
# Optionally add a line containing the server version and virtual host
# name to server-generated pages (internal error documents, FTP directory
# listings, mod_status and mod_info output etc., but not CGI generated
# documents or custom error documents).
# Set to "EMail" to also include a mailto: link to the ServerAdmin.
# Set to one of:  On | Off | EMail
#
ServerSignature Off

#
# Aliases: Add here as many aliases as you need (with no limit). The format is 
# Alias fakename realname
#
# Note that if you include a trailing / on fakename then the server will
# require it to be present in the URL.  So "/icons" isn't aliased in this
# example, only "/icons/".  If the fakename is slash-terminated, then the 
# realname must also be slash terminated, and if the fakename omits the 
# trailing slash, the realname must also omit it.
#
# We include the /icons/ alias for FancyIndexed directory listings.  If you
# do not use FancyIndexing, you may comment this out.
#
Alias /icons/ "/var/www/icons/"

<Directory "/var/www/icons">
    Options Indexes MultiViews
    AllowOverride None
    Order allow,deny
    Allow from all
</Directory>

#
# WebDAV module configuration section.
# 
<IfModule mod_dav_fs.c>
    # Location of the WebDAV lock database.
    DAVLockDB @instance_path@/var/run/lockdb
</IfModule>

#
# ScriptAlias: This controls which directories contain server scripts.
# ScriptAliases are essentially the same as Aliases, except that
# documents in the realname directory are treated as applications and
# run by the server when requested rather than as documents sent to the client.
# The same rules about trailing "/" apply to ScriptAlias directives as to
# Alias.
#
<IfDefine CGI>
	ScriptAlias /cgi-bin/ "@instance_path@/var/cgi-bin/"

#
# "/var/www/cgi-bin" should be changed to whatever your ScriptAliased
# CGI directory exists, if you have that configured.
#
	<Directory "@instance_path@/var/cgi-bin">
	    AllowOverride None
	    Options None
	    Order allow,deny
	    Allow from all
	</Directory>

</IfDefine>
#
# Redirect allows you to tell clients about documents which used to exist in
# your server's namespace, but do not anymore. This allows you to tell the
# clients where to look for the relocated document.
# Example:
# Redirect permanent /foo http://www.example.com/bar

#
# Directives controlling the display of server-generated directory listings.
#

#
# IndexOptions: Controls the appearance of server-generated directory
# listings.
#
IndexOptions FancyIndexing VersionSort NameWidth=* HTMLTable

#
# AddIcon* directives tell the server which icon to show for different
# files or filename extensions.  These are only displayed for
# FancyIndexed directories.
#
AddIconByEncoding (CMP,/icons/compressed.gif) x-compress x-gzip

AddIconByType (TXT,/icons/text.gif) text/*
AddIconByType (IMG,/icons/image2.gif) image/*
AddIconByType (SND,/icons/sound2.gif) audio/*
AddIconByType (VID,/icons/movie.gif) video/*

AddIcon /icons/binary.gif .bin .exe
AddIcon /icons/binhex.gif .hqx
AddIcon /icons/tar.gif .tar
AddIcon /icons/world2.gif .wrl .wrl.gz .vrml .vrm .iv
AddIcon /icons/compressed.gif .Z .z .tgz .gz .zip
AddIcon /icons/a.gif .ps .ai .eps
AddIcon /icons/layout.gif .html .shtml .htm .pdf
AddIcon /icons/text.gif .txt
AddIcon /icons/c.gif .c
AddIcon /icons/p.gif .pl .py
AddIcon /icons/f.gif .for
AddIcon /icons/dvi.gif .dvi
AddIcon /icons/uuencoded.gif .uu
AddIcon /icons/script.gif .conf .sh .shar .csh .ksh .tcl
AddIcon /icons/tex.gif .tex
AddIcon /icons/bomb.gif core

AddIcon /icons/back.gif ..
AddIcon /icons/hand.right.gif README
AddIcon /icons/folder.gif ^^DIRECTORY^^
AddIcon /icons/blank.gif ^^BLANKICON^^

#
# DefaultIcon is which icon to show for files which do not have an icon
# explicitly set.
#
DefaultIcon /icons/unknown.gif

#
# AddDescription allows you to place a short description after a file in
# server-generated indexes.  These are only displayed for FancyIndexed
# directories.
# Format: AddDescription "description" filename
#
#AddDescription "GZIP compressed document" .gz
#AddDescription "tar archive" .tar
#AddDescription "GZIP compressed tar archive" .tgz

#
# ReadmeName is the name of the README file the server will look for by
# default, and append to directory listings.
#
# HeaderName is the name of a file which should be prepended to
# directory indexes. 
ReadmeName README.html
HeaderName HEADER.html

#
# IndexIgnore is a set of filenames which directory indexing should ignore
# and not include in the listing.  Shell-style wildcarding is permitted.
#
IndexIgnore .??* *~ *# HEADER* README* RCS CVS *,v *,t

#
# DefaultLanguage and AddLanguage allows you to specify the language of 
# a document. You can then use content negotiation to give a browser a 
# file in a language the user can understand.
#
# Specify a default language. This means that all data
# going out without a specific language tag (see below) will 
# be marked with this one. You probably do NOT want to set
# this unless you are sure it is correct for all cases.
#
# * It is generally better to not mark a page as 
# * being a certain language than marking it with the wrong
# * language!
#
# DefaultLanguage nl
#
# Note 1: The suffix does not have to be the same as the language
# keyword --- those with documents in Polish (whose net-standard
# language code is pl) may wish to use "AddLanguage pl .po" to
# avoid the ambiguity with the common suffix for perl scripts.
#
# Note 2: The example entries below illustrate that in some cases 
# the two character 'Language' abbreviation is not identical to 
# the two character 'Country' code for its country,
# E.g. 'Danmark/dk' versus 'Danish/da'.
#
# Note 3: In the case of 'ltz' we violate the RFC by using a three char
# specifier. There is 'work in progress' to fix this and get
# the reference data for rfc1766 cleaned up.
#
# Catalan (ca) - Croatian (hr) - Czech (cs) - Danish (da) - Dutch (nl)
# English (en) - Esperanto (eo) - Estonian (et) - French (fr) - German (de)
# Greek-Modern (el) - Hebrew (he) - Italian (it) - Japanese (ja)
# Korean (ko) - Luxembourgeois* (ltz) - Norwegian Nynorsk (nn)
# Norwegian (no) - Polish (pl) - Portugese (pt)
# Brazilian Portuguese (pt-BR) - Russian (ru) - Swedish (sv)
# Simplified Chinese (zh-CN) - Spanish (es) - Traditional Chinese (zh-TW)
#
AddLanguage ca .ca
AddLanguage cs .cz .cs
AddLanguage da .dk
AddLanguage de .de
AddLanguage el .el
AddLanguage en .en
AddLanguage eo .eo
AddLanguage es .es
AddLanguage et .et
AddLanguage fr .fr
AddLanguage he .he
AddLanguage hr .hr
AddLanguage it .it
AddLanguage ja .ja
AddLanguage ko .ko
AddLanguage ltz .ltz
AddLanguage nl .nl
AddLanguage nn .nn
AddLanguage no .no
AddLanguage pl .po
AddLanguage pt .pt
AddLanguage pt-BR .pt-br
AddLanguage ru .ru
AddLanguage sv .sv
AddLanguage zh-CN .zh-cn
AddLanguage zh-TW .zh-tw

#
# LanguagePriority allows you to give precedence to some languages
# in case of a tie during content negotiation.
#
# Just list the languages in decreasing order of preference. We have
# more or less alphabetized them here. You probably want to change this.
#
LanguagePriority de en ca cs da el eo es et fr he hr it ja ko ltz nl nn no pl pt pt-BR ru sv zh-CN zh-TW

#
# ForceLanguagePriority allows you to serve a result page rather than
# MULTIPLE CHOICES (Prefer) [in case of a tie] or NOT ACCEPTABLE (Fallback)
# [in case no accepted languages matched the available variants]
#
ForceLanguagePriority Prefer Fallback

#
# Specify a default charset for all content served; this enables
# interpretation of all content as UTF-8 by default.  To use the 
# default browser choice (ISO-8859-1), or to allow the META tags
# in HTML content to override this choice, comment out this
# directive:
#
AddDefaultCharset UTF-8

#
# AddType allows you to add to or override the MIME configuration
# file mime.types for specific file types.
#
#AddType application/x-tar .tgz

#
# AddEncoding allows you to have certain browsers uncompress
# information on the fly. Note: Not all browsers support this.
# Despite the name similarity, the following Add* directives have nothing
# to do with the FancyIndexing customization directives above.
#
#AddEncoding x-compress .Z
#AddEncoding x-gzip .gz .tgz

# If the AddEncoding directives above are commented-out, then you
# probably should define those extensions to indicate media types:
#
AddType application/x-compress .Z
AddType application/x-gzip .gz .tgz

#
# AddHandler allows you to map certain file extensions to "handlers":
# actions unrelated to filetype. These can be either built into the server
# or added with the Action directive (see below)
#
# To use CGI scripts outside of ScriptAliased directories:
# (You will also need to add "ExecCGI" to the "Options" directive.)
#
#AddHandler cgi-script .cgi

#
# For files that include their own HTTP headers:
#
#AddHandler send-as-is asis

#
# For type maps (negotiated resources):
# (This is enabled by default to allow the Apache "It Worked" page
#  to be distributed in multiple languages.)
#
AddHandler type-map var

#
# Filters allow you to process content before it is sent to the client.
#
# To parse .shtml files for server-side includes (SSI):
# (You will also need to add "Includes" to the "Options" directive.)
#
AddType text/html .shtml
AddOutputFilter INCLUDES .shtml

#
# Action lets you define media types that will execute a script whenever
# a matching file is called. This eliminates the need for repeated URL
# pathnames for oft-used CGI file processors.
# Format: Action media/type /cgi-script/location
# Format: Action handler-name /cgi-script/location
#

#
# Customizable error responses come in three flavors:
# 1) plain text 2) local redirects 3) external redirects
#
# Some examples:
#ErrorDocument 500 "The server made a boo boo."
#ErrorDocument 404 /missing.html
#ErrorDocument 404 "/cgi-bin/missing_handler.pl"
#ErrorDocument 402 http://www.example.com/subscription_info.html
#

#
# Putting this all together, we can internationalize error responses.
#
# We use Alias to redirect any /error/HTTP_<error>.html.var response to
# our collection of by-error message multi-language collections.  We use 
# includes to substitute the appropriate text.
#
# You can modify the messages' appearance without changing any of the
# default HTTP_<error>.html.var files by adding the line:
#
#   Alias /error/include/ "/your/include/path/"
#
# which allows you to create your own set of files by starting with the
# /var/www/error/include/ files and
# copying them to /your/include/path/, even on a per-VirtualHost basis.
#

Alias /error/ "@instance_path@/var/error/"

<IfModule mod_negotiation.c>
<IfModule mod_include.c>
    <Directory "@instance_path@/var/error">
        AllowOverride None
        Options IncludesNoExec
        AddOutputFilter Includes html
        AddHandler type-map var
        Order allow,deny
        Allow from all
        LanguagePriority en es de fr
        ForceLanguagePriority Prefer Fallback
    </Directory>

#    ErrorDocument 400 /error/HTTP_BAD_REQUEST.html.var
#    ErrorDocument 401 /error/HTTP_UNAUTHORIZED.html.var
#    ErrorDocument 403 /error/HTTP_FORBIDDEN.html.var
#    ErrorDocument 404 /error/HTTP_NOT_FOUND.html.var
#    ErrorDocument 405 /error/HTTP_METHOD_NOT_ALLOWED.html.var
#    ErrorDocument 408 /error/HTTP_REQUEST_TIME_OUT.html.var
#    ErrorDocument 410 /error/HTTP_GONE.html.var
#    ErrorDocument 411 /error/HTTP_LENGTH_REQUIRED.html.var
#    ErrorDocument 412 /error/HTTP_PRECONDITION_FAILED.html.var
#    ErrorDocument 413 /error/HTTP_REQUEST_ENTITY_TOO_LARGE.html.var
#    ErrorDocument 414 /error/HTTP_REQUEST_URI_TOO_LARGE.html.var
#    ErrorDocument 415 /error/HTTP_UNSUPPORTED_MEDIA_TYPE.html.var
#    ErrorDocument 500 /error/HTTP_INTERNAL_SERVER_ERROR.html.var
#    ErrorDocument 501 /error/HTTP_NOT_IMPLEMENTED.html.var
#    ErrorDocument 502 /error/HTTP_BAD_GATEWAY.html.var
#    ErrorDocument 503 /error/HTTP_SERVICE_UNAVAILABLE.html.var
#    ErrorDocument 506 /error/HTTP_VARIANT_ALSO_VARIES.html.var

</IfModule>
</IfModule>

#
# The following directives modify normal HTTP response behavior to
# handle known problems with browser implementations.
#
BrowserMatch "Mozilla/2" nokeepalive
BrowserMatch "MSIE 4\.0b2;" nokeepalive downgrade-1.0 force-response-1.0
BrowserMatch "RealPlayer 4\.0" force-response-1.0
BrowserMatch "Java/1\.0" force-response-1.0
BrowserMatch "JDK/1\.0" force-response-1.0

#
# The following directive disables redirects on non-GET requests for
# a directory that does not include the trailing slash.  This fixes a 
# problem with Microsoft WebFolders which does not appropriately handle 
# redirects for folders with DAV methods.
# Same deal with Apple's DAV filesystem and Gnome VFS support for DAV.
#
BrowserMatch "Microsoft Data Access Internet Publishing Provider" redirect-carefully
BrowserMatch "MS FrontPage" redirect-carefully
BrowserMatch "^WebDrive" redirect-carefully
BrowserMatch "^WebDAVFS/1.[0123]" redirect-carefully
BrowserMatch "^gnome-vfs/1.0" redirect-carefully
BrowserMatch "^XML Spy" redirect-carefully
BrowserMatch "^Dreamweaver-WebDAV-SCM1" redirect-carefully

#
# Allow server status reports generated by mod_status,
# with the URL of http://servername/server-status
# Change the ".example.com" to match your domain to enable.
#
<Location /server-status>
    SetHandler server-status
    Order deny,allow
    Deny from all
    Allow from @internal_net@
</Location>


# Allow remote server configuration reports, with the URL of
#  http://servername/server-info (requires that mod_info.c be loaded).
# Change the ".example.com" to match your domain to enable.
#
<Location /server-info>
    SetHandler server-info
    Order deny,allow
    Deny from all
    Allow from @internal_net@
</Location>

@end

