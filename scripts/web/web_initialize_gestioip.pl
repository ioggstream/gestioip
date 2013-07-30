#!/usr/bin/perl -w

# Copyright (C) 2011 Marc Uebel

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


# initialize_gestioip.pl Version 3.0.0

# script to initialize GestioIP's database
# see documentation for further information (www.gestioip.net)


use lib '/var/www/gestioip/modules';
use GestioIP;
use Getopt::Long;
Getopt::Long::Configure ("no_ignore_case");
use strict;
use FindBin qw($Bin);
use Fcntl qw(:flock);


#$ENV{PATH} = '';

my $gip = GestioIP -> new();

my $start_time=time();

my $VERSION="3.0.0";


my ( $disable_audit, $help, $version_arg, $configuration_arg,$community,$snmp_version,$client_id,$lang,$ini_devices,$gip_config_file,$user,$add_comment, $with_spreadsheet,$max_sync_procs, $smallest_bm4, $smallest_bm6, $init_known_networks, $local_routes, $static_routes, $other_routes, $ospf_routes, $rip_routes, $isis_routes, $eigrp_routes);
my $auth_proto="";
my $auth_pass="";
my $priv_proto="";
my $priv_pass="";
my $sec_level="";
my $ipv4="";
my $ipv6="";
my $process_networks_v4="";
my $process_networks_v6="";


GetOptions(
        "community=s"=>\$community,
        "id_client=s"=>\$client_id,
        "snmp_version=s"=>\$snmp_version,
        "lang=s"=>\$lang,
        "devices=s"=>\$ini_devices,
        "gestioip_config=s"=>\$gip_config_file,
        "user=s"=>\$user,
        "max_procs=s"=>\$max_sync_procs,
        "with_spreadsheet!"=>\$with_spreadsheet,
        "add_comment!"=>\$add_comment,
        "Version!"=>\$version_arg,
	"n=s"=>\$auth_proto,
	"o=s"=>\$auth_pass,
	"t=s"=>\$priv_proto,
	"q=s"=>\$priv_pass,
	"r=s"=>\$sec_level,
	"x=s"=>\$smallest_bm4,
	"y=s"=>\$smallest_bm6,
	"4!"=>\$ipv4,
	"6!"=>\$ipv6,
	"z!"=>\$init_known_networks,
#        "disable_audit!"=>\$disable_audit,
        "help!"=>\$help,
        "b!"=>\$local_routes,
        "1!"=>\$static_routes,
        "e!"=>\$other_routes,
        "f!"=>\$ospf_routes,
        "h!"=>\$rip_routes,
        "j!"=>\$isis_routes,
        "k!"=>\$eigrp_routes,
	"2=s"=>\$process_networks_v4,
	"3=s"=>\$process_networks_v6
) or print_help();

if ( ! $client_id ) {
        print STDERR "Parameter \"client_id\" missing\n\nexiting\n";
        exit 1;
}
if ( ! $gip_config_file ) {
        print STDERR "Parameter \"gip_config_file\" missing\n\nexiting\n";
        exit 1;
}


my $dir = $Bin;
$dir =~ /^(.*\/bin\/web)$/;
$dir = $1;
$dir =~ /^(.*)\/bin/;
my $base_dir=$1;

my $lockfile = $base_dir . "/var/run/" . $client_id . "_web_initialize_gestioip.lock";

no strict 'refs';
open($lockfile, '<', $0) or die("Unable to create lock file: $!\n");
use strict;

unless (flock($lockfile, LOCK_EX|LOCK_NB)) {
        print "DISCOVERY IN PROGRESS  - $0 is already running. Exiting.\n";
        exit(1);
}

my $pidfile = $base_dir . "/var/run/" . $client_id . "_web_initialize_gestioip.pid";
$pidfile =~ /^(.*_web_initialize_gestioip.pid)$/;
$pidfile = $1;
open(PID,">$pidfile") or die("Unable to create pid file $pidfile: $! (0)\n");
print PID $$;
close PID;

$SIG{'TERM'} = $SIG{'INT'} = \&do_term;

$gip_config_file =~ /^(.*\/priv\/ip_config)$/;
$gip_config_file = $1;
$gip_config_file =~ /^(.*)\/priv/;
my $gestioip_root=$1;
my $ini_stat=$gestioip_root . "/status/ini_stat.html";
my $log=$gestioip_root . "/status/" . $client_id . "_initialize_gestioip.log";
$log =~ /^(.*_initialize_gestioip.log)$/;
$log = $1;

open(LOG,">$log") or die "$log: $!\n";
*STDERR = *LOG;

if ( ! $community || ! $snmp_version || ! $client_id || ! $gip_config_file || ! $user) {
	print LOG "NOT ENOUGH ARGUMENTS - \nEXITING\n";
	close LOG;
	exit(1);
}
if ( $snmp_version == "3" ) {
	if ( ! $community ) {
		print LOG "No Username\n";
		close LOG;
		exit(1);
	}
#       {introduce_community_string_message}") if ! $community;
	if ( $auth_proto && ! $auth_pass ) {
		print LOG "No auth password\n";
		close LOG;
		exit(1);
	}
	if ( $auth_pass && ! $auth_proto ) {
		print LOG "No auth protocol\n";
		close LOG;
		exit(1);
	}
	if ( $priv_proto && ! $priv_pass ) {
		print LOG "No privacy password\n";
		close LOG;
		exit(1);
	}
	if ( $priv_pass && ! $priv_proto ) {
		print LOG "NO privacy protocol\n";
		close LOG;
		exit(1);
	}
	if ( $priv_proto && ( ! $auth_proto || ! $auth_pass ) ) {
		print LOG "No \"auth algorithm\" and \"auth password/auth key\"\n";
		close LOG;
		exit(1);
	}
}

if ( ! -d "${gestioip_root}/status" ) {
        print LOG "Log directory does not exists: ${gestioip_root}/status\n\exiting\n";
        exit(1);
}

$lang = "en" if ! $lang;
$lang =~ /^(\w{2,3})$/;
$lang = $1;

my $vars_file=$base_dir . "/etc/vars/vars_update_gestioip_" . "$lang";
if ( ! -r $vars_file ) {
        print LOG "vars_file not found: $vars_file\n\nexiting\n";
        exit(1);
}

my %lang_vars;


open(LANGVARS,"<$vars_file") or die "Can not open $vars_file: $!\n";
while (<LANGVARS>) {
        chomp;
        s/#.*//;
        s/^\s+//;
        s/\s+$//;
        next unless length;
        my ($var, $value) = split(/\s*=\s*/, $_, 2);
        $lang_vars{$var} = $value;
}
close LANGVARS;


my $enable_audit = "1";
$enable_audit = "0" if $disable_audit;


if ( $help ) { print_help(); }
if ( $version_arg ) { print_version(); }

my ($s, $mm, $h, $d, $m, $y) = (localtime) [0,1,2,3,4,5];
$m++;
$y+=1900;
if ( $d =~ /^\d$/ ) { $d = "0$d"; }
if ( $s =~ /^\d$/ ) { $s = "0$s"; }
if ( $m =~ /^\d$/ ) { $m = "0$m"; }
if ( $mm =~ /^\d$/ ) { $mm = "0$mm"; }
my $mydatetime = "$y-$m-$d $h:$mm:$s";

print LOG "$mydatetime Network initialization started\n\n";

if ( ! $max_sync_procs ) {
	print LOG "Using default number of childs: 128 (1)\n";
	$max_sync_procs = "128";
} elsif ( $max_sync_procs !~ /^(32|64|128|254)$/ ) {
	print LOG "Using default number of childs: 128 (2)\n";
	$max_sync_procs = "128";
}


my $audit_type="45";
my $audit_class="2";
my $update_type_audit="1";
my $event="---";
insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$user");

my $with_spreadsheet_arg="";
if ( $with_spreadsheet ) {
	$with_spreadsheet_arg='-w';
}

my $add_comment_arg="";
$add_comment_arg="-a" if $add_comment;
$community =~ /(.{1,50})/;
$community = $1;
$snmp_version =~ /^([123])$/;
$snmp_version = $1;
$client_id =~ /^(\d{1,5})$/;
$client_id = $1;
$ini_devices =~ /^([0-9,.]*)/;
$ini_devices = $1;
$user =~ /(.{1,50})/;
$user = $1;
$max_sync_procs =~ /^(\d{2,3})$/;
$max_sync_procs = $1;


my $auth_proto_arg = "";
$auth_proto_arg = "-n $auth_proto" if $auth_proto;
my $auth_pass_arg = "";
$auth_pass_arg = "-o $auth_pass" if $auth_pass;
my $priv_proto_arg = "";
$priv_proto_arg = "-t $priv_proto" if $priv_proto;
my $priv_pass_arg = "";
$priv_pass_arg = "-q $priv_pass" if $priv_pass;
my $sec_level_arg = "";
$sec_level_arg = "-r $sec_level" if $sec_level;

my $ipv4_arg = "";
$ipv4_arg = "-4" if $ipv4;
my $ipv6_arg = "";
$ipv6_arg = "-6" if $ipv6;
my $smallest_bm4_arg = " ";
$smallest_bm4_arg = "-x $smallest_bm4" if $ipv4;
my $smallest_bm6_arg = " ";
$smallest_bm6_arg = "-y $smallest_bm6" if $ipv6;

my $init_known_networks_arg = " ";
$init_known_networks_arg = "-z" if $init_known_networks;

my $local_routes_arg = "";
$local_routes_arg = "-b" if $local_routes;
my $static_routes_arg = "";
$static_routes_arg = "-1" if $static_routes;
my $other_routes_arg = "";
$other_routes_arg = "-e" if $other_routes;
my $ospf_routes_arg = "";
$ospf_routes_arg = "-f" if $ospf_routes;
my $rip_routes_arg = "";
$rip_routes_arg = "-h" if $rip_routes;
my $isis_routes_arg = "";
$isis_routes_arg = "-j" if $isis_routes;
my $eigrp_routes_arg = "";
$eigrp_routes_arg = "-k" if $eigrp_routes;

my $process_networks_v4_arg = "";
$process_networks_v4_arg = "-2 $process_networks_v4" if $process_networks_v4;
my $process_networks_v6_arg = "";
$process_networks_v6_arg = "-3 $process_networks_v6" if $process_networks_v6;



my $import_vlan_args = " -c $community -s $snmp_version -i $client_id -d $ini_devices -g $gip_config_file -u $user -l $lang -p $max_sync_procs $auth_proto_arg $auth_pass_arg $priv_proto_arg $priv_pass_arg $sec_level_arg";

my $discover_snmp_net_args = " -c $community -s $snmp_version -i $client_id -d $ini_devices -g $gip_config_file -u $user $add_comment_arg -l $lang $auth_proto_arg $auth_pass_arg $priv_proto_arg $priv_pass_arg $sec_level_arg $ipv4_arg $ipv6_arg $init_known_networks_arg $local_routes_arg $static_routes_arg $other_routes_arg $ospf_routes_arg $rip_routes_arg $isis_routes_arg $eigrp_routes_arg $process_networks_v4_arg $process_networks_v6_arg";

my $discover_snmp_host_args = " -s $snmp_version -i $client_id -g $gip_config_file -u $user $with_spreadsheet_arg -l $lang -p $max_sync_procs $auth_proto_arg $auth_pass_arg $priv_proto_arg $priv_pass_arg $sec_level_arg $ipv4_arg $ipv6_arg $smallest_bm4_arg $smallest_bm6_arg";

my $discover_dns_args = " -i $client_id -g $gip_config_file -u $user $with_spreadsheet_arg -l $lang -p $max_sync_procs $ipv4_arg $ipv6_arg $smallest_bm4_arg $smallest_bm6_arg";


unlink("$ini_stat") if -e $ini_stat;

print LOG "Creating ini_stat.html\n";
system("$dir/create_ini_stat.pl -g $gip_config_file -i $client_id -b 0 -a 0 -z 0 -l $lang");


print LOG "\n### Executing VLAN discovery via SNMP ###\n";
close LOG;

my $status_vlan=system("$dir/web_ip_import_vlans.pl $import_vlan_args");

$status_vlan=mod_status("$status_vlan");
if ( $status_vlan == "3" ) {
	&do_term;
}
open(LOG,">>$log") or die "$log: $!\n";
print LOG "\nVLAN discovery finished with errors\n" if $status_vlan ne "0" && $status_vlan ne "3";


print LOG "\n### Executing network discovery via SNMP ###\n";
close LOG;
my $status=system("$dir/web_get_networks_snmp.pl $discover_snmp_net_args");

$status=mod_status("$status");
if ( $status == "3" ) {
	&do_term;
}


if ( $status == "0" ) {

	if ( $community ne "public" ) {
		open(LOG,">>$log") or die "$log: $!\n";
		print  LOG"\n### Executing host discovery via SNMP (using from cgi passed community) ###\n";
		close LOG;

		$status=system("$dir/web_ip_update_gestioip_snmp.pl $discover_snmp_host_args -c $community");

		$status=mod_status("$status");
		if ( $status == "3" ) {
			sleep 8;
			&do_term;
		}
	}


	open(LOG,">>$log") or die "$log: $!\n";
	print LOG "\n### Executing host discovery via SNMP (using community: \"public\") ###\n";
	close LOG;

	my $status_snmp_pub=system("$dir/web_ip_update_gestioip_snmp.pl $discover_snmp_host_args -c public");

	$status_snmp_pub=mod_status("$status_snmp_pub");
	if ( $status_snmp_pub == "3" ) {
		sleep 8;
		&do_term;
	}


	open(LOG,">>$log") or die "$log: $!\n";
	print LOG "\n### Executing host discovery via DNS ###\n";
	close LOG;

	my $status_dns=system("$dir/web_ip_update_gestioip_dns.pl $discover_dns_args");

	$status_dns=mod_status("$status_dns");
	if ( $status_dns == "3" ) {
		sleep 8;
		&do_term;
	}

} else {

	open(LOG,">>$log") or die "$log: $!\n";

	my $end_time=time();
	my $duration=$end_time - $start_time;
	my @parts = gmtime($duration);
	my $duration_string = ""; 
	$duration_string = $parts[2] . "h, " if $parts[2] != "0";
	$duration_string = $duration_string . $parts[1] . "m";
	$duration_string = $duration_string . " and " . $parts[0] . "s";

	#change ini_stat.html
	my $new = "./ini_stat.html.tmp.$$";

	open(OLD, "< $ini_stat") or die "can't open $ini_stat: $!";
	open(NEW, "> $new") or die "can't open $new: $!";

	while (<OLD>) {
		$_ = "" if  $_ =~ /"refresh"/;
		$_ = "" if  $_ =~ /$lang_vars{refresh_message}/;
		 s//network_done_error.gif/;
		 s/$lang_vars{discovery_in_progress_message}/$lang_vars{discovery_finished_with_error_message}<br><p>($lang_vars{execution_time_message}: ${duration_string})<br><p><p>$lang_vars{please_consult_message} <FORM ACTION=""><INPUT TYPE="BUTTON" VALUE="STATUS LOG" ONCLICK="window.open('..\/status\/${client_id}_initialize_gestioip.log','STATUS','toolbar=0,scrollbars=1,location=1,status=1,menubar=0,directories=0,right=100,top=100,width=475,height=475,resizable')" class="input_link_w" style="display:inline;"><\/FORM> $lang_vars{discovery_detail_message}<p>/;
		 s/network_search.gif/network_done_error.gif/;
		(print NEW $_) or die "can't write to $new: $!";
	}

	close(OLD) or die "can't close $ini_stat: $!";
	close(NEW) or die "can't close $new: $!";

	rename($new, $ini_stat) or die "can't rename $new to $ini_stat: $!";

	print LOG "\nThere occured an error executing get_networks_snmp.pl - aborded\n\n";
	close LOG;
	unlink("${base_dir}/var/run/${client_id}_found_networks.tmp");
	unlink("${base_dir}/var/run/${client_id}_found_networks_spreadsheet.tmp");

	exit 1;
}

open(LOG,">>$log") or die "$log: $!\n";

my $end_time=time();
my $duration=$end_time - $start_time;
my @parts = gmtime($duration);
my $duration_string = ""; 
$duration_string = $parts[2] . "h, " if $parts[2] != "0";
$duration_string = $duration_string . $parts[1] . "m";
$duration_string = $duration_string . " and " . $parts[0] . "s";

#change ini_stat.html
my $new = "./ini_stat.html.tmp.$$";

open(OLD, "< $ini_stat") or die "can't open $ini_stat: $!";
open(NEW, "> $new") or die "can't open $new: $!";

while (<OLD>) {
	$_ = "" if  $_ =~ /"refresh"/;
	$_ = "" if  $_ =~ /$lang_vars{refresh_message}/;
	$_ = "" if  $_ =~ /infotable/;
	s/$lang_vars{discovery_in_progress_message}/$lang_vars{discovery_successfully_finished_message}<br><p>($lang_vars{execution_time_message}: ${duration_string})<br><p>$lang_vars{please_consult_message} <FORM ACTION="" style="display:inline;"><INPUT TYPE="BUTTON" VALUE="log file" ONCLICK="window.open('..\/status\/${client_id}_initialize_gestioip.log','STATUS LOG','toolbar=0,scrollbars=1,location=1,status=1,menubar=0,directories=0,right=100,top=100,width=575,height=475,resizable')" class="input_link_w"><\/FORM>  $lang_vars{discovery_detail_message}<p><\/center>/;
         s/network_search.gif/network_done.gif/;
        (print NEW $_) or die "can't write to $new: $!";
}

close(OLD) or die "can't close $ini_stat: $!";
close(NEW) or die "can't close $new: $!";

rename($new, $ini_stat) or die "can't rename $new to $ini_stat: $!";

unlink("${base_dir}/var/run/${client_id}_found_networks.tmp");
unlink("${base_dir}/var/run/${client_id}_found_networks_spreadsheet.tmp");

print LOG "\nInitialization prozess finished (execution time: ${duration_string})\n";
close LOG;

unlink("$pidfile");


##################
## Subroutines ###
##################

sub print_help {
        print "\nusage: initialize_gestioip.pl [OPTIONS...]\n\n";
        print "-V, --Version            print version and exit\n";
        print "-c, --configuratio_file  configuration to use (default: ./ip_update_gestioip.conf)\n";
        print "-d, --disable_audit      disable audit\n";
        print "-h, --help               help\n\n";
#        print "\n\nconfiguration file: $conf\n\n";
        exit;
}


sub print_version {
        print "\n$0 Version $VERSION\n\n";
        exit 0;
}

sub insert_audit {
        my ($client_id,$event_class,$event_type,$event,$update_type_audit,$user) = @_;
        my $mydatetime=time();
        my $audit_id=get_last_audit_id("$client_id");
        $audit_id++;
        my $dbh = $gip->_mysql_connection("$gip_config_file");
        my $qaudit_id = $dbh->quote( $audit_id );
        my $qevent_class = $dbh->quote( $event_class );
        my $qevent_type = $dbh->quote( $event_type );
        my $qevent = $dbh->quote( $event );
        my $quser = $dbh->quote( $user );
        my $qupdate_type_audit = $dbh->quote( $update_type_audit );
        my $qmydatetime = $dbh->quote( $mydatetime );
        my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("INSERT IGNORE audit (id,event,user,event_class,event_type,update_type_audit,date,client_id) VALUES ($qaudit_id,$qevent,$quser,$qevent_class,$event_type,$qupdate_type_audit,$qmydatetime,$qclient_id)") or die "Can not execute statement:<p>$DBI::errstr";
        $sth->execute() or die "Can not execute statement:<p>$DBI::errstr";
        $sth->finish();
}

sub get_last_audit_id {
        my ($client_id) = @_;
        my $last_audit_id;
        my $dbh = $gip->_mysql_connection("$gip_config_file");
        my $sth = $dbh->prepare("SELECT id FROM audit ORDER BY (id+0) DESC LIMIT 1
                        ") or die "select: $DBI::errstr";
        $sth->execute() or die "Can not execute statement: $DBI::errstr";
        $last_audit_id = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        $last_audit_id || 1;
        return $last_audit_id;
}


sub do_term {
	open(LOG,">>$log") or die "$log: $!\n";
	print LOG "$lang_vars{discovery_interrupted_by_user_log_message}\nexiting\n";
	close LOG;

	my $end_time=time();
	my $duration=$end_time - $start_time;
	my @parts = gmtime($duration);
	my $duration_string = ""; 
	$duration_string = $parts[2] . "h, " if $parts[2] != "0";
	$duration_string = $duration_string . $parts[1] . "m";
	$duration_string = $duration_string . " and " . $parts[0] . "s";

	#change ini_stat.html
	my $new = "./ini_stat.html.tmp.$$";

	open(OLD, "< $ini_stat") or die "can't open $ini_stat: $!";
	open(NEW, "> $new") or die "can't open $new: $!";

	while (<OLD>) {
		$_ = "" if  $_ =~ /"refresh"/;
		$_ = "" if  $_ =~ /$lang_vars{refresh_message}/;
		$_ = "" if  $_ =~ /infotable/;
		 s/$lang_vars{discovery_in_progress_message}/$lang_vars{discovery_interrupted_by_user_message}<br><p>($lang_vars{execution_time_message}: ${duration_string})<br><p>$lang_vars{please_consult_message} <FORM ACTION="" style="display:inline;"><INPUT TYPE="BUTTON" VALUE="log file" ONCLICK="window.open('..\/status\/${client_id}_initialize_gestioip.log','STATUS LOG','toolbar=0,scrollbars=1,location=1,status=1,menubar=0,directories=0,right=100,top=100,width=575,height=475,resizable')" class="input_link_w"><\/FORM> $lang_vars{discovery_detail_message}<\/center><p>/;
		 s/network_search.gif/network_done.gif/;
		(print NEW $_) or die "can't write to $new: $!";
	}

	close(OLD) or die "can't close $ini_stat: $!";
	close(NEW) or die "can't close $new: $!";

	rename($new, $ini_stat) or die "can't rename $new to $ini_stat: $!";

	unlink("${base_dir}/var/run/${client_id}_found_networks.tmp");
	unlink("${base_dir}/var/run/${client_id}_found_networks_spreadsheet.tmp");
	unlink("$pidfile");

	exit 1;
}

sub mod_status {
	my ($status) = @_;
	if ( $status > 764 ) {
		$status -= 765;
	} elsif ( $status > 509 ) {
		$status -= 510;
	} elsif ( $status > 255 ) {
		$status -=255;
	}
	return $status;
}


__DATA__

