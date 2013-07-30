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


use strict;
use lib '../modules';
use GestioIP;

my $daten=<STDIN>;
my $gip = GestioIP -> new();
my %daten=$gip->preparer($daten);

my $base_uri = $gip->get_base_uri();
my $server_proto=$gip->get_server_proto();

my $lang = $daten{'lang'} || "";
my ($lang_vars,$vars_file)=$gip->get_lang("","$lang");

my $client_id = $daten{'client_id'} || $gip->get_first_client_id();

$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{initialize_gestioip_message}","$vars_file");

my $align="align=\"right\"";
my $align1="";
my $ori="left";
my $rtl_helper="<font color=\"white\">x</font>";
if ( $vars_file =~ /vars_he$/ ) {
	$align="align=\"left\"";
	$align1="align=\"right\"";
	$ori="right";
}


$gip->print_error("$client_id","$$lang_vars{introduce_community_string_message}") if ( ! $daten{'community_string'} );
$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (1)") if length($daten{community_string}) > 35;
$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (2)") if ($daten{snmp_version} !~ /^[123]$/ );
$gip->print_error("$client_id","$$lang_vars{introduce_ini_devices_message}") if ( ! $daten{ini_devices} );
$gip->print_error("$client_id","$$lang_vars{ini_device_ip_message}") if ( $daten{ini_devices} !~ /\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}(,\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})*$/ );
$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (3)") if $daten{max_procs} !~ /^(32|64|128|254)$/;

my $ini_prog="/usr/share/gestioip/bin/web/web_initialize_gestioip.pl";
$gip->print_error("$client_id","$$lang_vars{ini_prog_not_found}") if ! -x $ini_prog;


my $community=$daten{'community_string'};
my $snmp_version=$daten{snmp_version};
my $ini_devices=$daten{ini_devices};
$ini_devices=~s/[\s\r\n\t]+//;
my $add_comment = "n";
$add_comment=$daten{'add_comment'} if $daten{'add_comment'};
my $include_spreadsheet_networks = "n";
$include_spreadsheet_networks=$daten{'include_spreadsheet_networks'} if $daten{'include_spreadsheet_networks'};
my $max_sync_procs=$daten{max_procs};

my $import_ipv4=$daten{'ipv4'} || "";
my $import_ipv6=$daten{'ipv6'} || "";
$gip->print_error("$client_id","$$lang_vars{choose_ip_version_redes_message}") if ! $import_ipv4 && ! $import_ipv6;

my $smallest_bm4=$daten{'smallest_bm4'} || "";
my $smallest_bm6=$daten{'smallest_bm6'} || "";

my $init_known_networks=$daten{'init_known_networks'} || "";

my $local_routes=$daten{'local_routes'} || "";
my $static_routes=$daten{'static_routes'} || "";
my $other_routes=$daten{'other_routes'} || "";
my $ospf_routes=$daten{'ospf_routes'} || "";
my $rip_routes=$daten{'rip_routes'} || "";
my $isis_routes=$daten{'isis_routes'} || "";
my $eigrp_routes=$daten{'eigrp_routes'} || "";

my $process_networks_v4=$daten{'process_networks_v4'} || "";
my $process_networks_v6=$daten{'process_networks_v6'} || "";



my $auth_pass="";
my $auth_proto="";
my $auth_is_key="";
my $priv_proto="";
my $priv_pass="";
my $priv_is_key="";
my $sec_level="noAuthNoPriv";

if ( $snmp_version == "3" ) {
        $auth_proto=$daten{'auth_proto'} || "";
        $auth_pass=$daten{'auth_pass'} || "";
#        $auth_is_key=$daten{'auth_is_key'} || "";
        $priv_proto=$daten{'priv_proto'} || "";
        $priv_pass=$daten{'priv_pass'} || "";
#        $priv_is_key=$daten{'priv_is_key'} || "";
        $sec_level=$daten{'sec_level'} || "";
        $gip->print_error("$client_id","$$lang_vars{introduce_community_string_message}") if ! $community;
        $gip->print_error("$client_id","$$lang_vars{introduce_auth_pass_message}") if $auth_proto && ! $auth_pass;
        $gip->print_error("$client_id","$$lang_vars{introduce_auth_proto_message}") if $auth_pass && ! $auth_proto;
        $gip->print_error("$client_id","$$lang_vars{introduce_priv_pass_message}") if $priv_proto && ! $priv_pass;
        $gip->print_error("$client_id","$$lang_vars{introduce_priv_proto_message}") if $priv_pass && ! $priv_proto;
        $gip->print_error("$client_id","$$lang_vars{introduce_priv_auth_missing_message}") if $priv_proto && ( ! $auth_proto || ! $auth_pass );
	if ( $auth_pass ) {
		$gip->print_error("$client_id","$$lang_vars{auth_pass_characters_message}") if $auth_pass !~ /^.{8,50}$/;
	}
	if ( $priv_pass ) {
		$gip->print_error("$client_id","$$lang_vars{priv_pass_characters_message}") if $priv_pass !~ /^.{8,50}$/;
	}
}


my @global_config = $gip->get_global_config("$client_id");
my $mib_dir=$global_config[0]->[3] || "";
my $vendor_mib_dirs=$global_config[0]->[4] || "";

my $mibdirs_ref = $gip->check_mib_dir("$client_id","$vars_file","$mib_dir","$vendor_mib_dirs");


my $pid;
if ($pid = fork) {

	print "<p>\n";
	print " <span style=\"float: $ori\"><b>$$lang_vars{discovery_started_message}</b></span>";
	print "<br><p><br>\n";
	print "<span style=\"float: $ori\"><FORM ACTION=\"\" style=\"display:inline;\"><INPUT TYPE=\"BUTTON\" VALUE=\"$$lang_vars{consult_discovery_status_message}\" ONCLICK=\"window.open('$server_proto://$base_uri/status/ini_stat.html','STATUS','toolbar=0,scrollbars=1,location=1,status=1,menubar=0,directories=0,right=100,top=100,width=475,height=475,resizable')\" class=\"input_link_w\"></FORM></span><br><p>\n";
	print "<span style=\"float: $ori\"><form name=\"show_networks\" method=\"POST\" action=\"$server_proto://$base_uri/res/ip_stop_discovery.cgi\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"submit\" class=\"input_link_w\" value=\"$$lang_vars{stop_discovery_message}\" name=\"B1\"></form></span>\n";


	$gip->print_end("$client_id");


} else {

	close (STDERR);
	close (STDOUT);
	close (STDIN);

	my $config_file;
	$ENV{'SCRIPT_FILENAME'} =~ /^(.*)\/res\/ip_initialize.cgi/;
	$config_file=$1;
	$config_file=$config_file . "/priv/ip_config";
	$ini_prog=~/^(.*web_initialize_gestioip.pl)$/;
	$ini_prog=$1;
	$vars_file =~ /.*_(\w{1,3})$/;
	$lang=$1 if ! $lang;
	my $user=$ENV{'REMOTE_USER'};

	my $add_comment_arg="";
	$add_comment_arg='-a' if $add_comment eq "yes";
	my $include_spreadsheet_networks_arg="";
	$include_spreadsheet_networks_arg='-w' if $include_spreadsheet_networks eq "yes";
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
	$ipv4_arg = "-4" if $import_ipv4;
	my $ipv6_arg = "";
	$ipv6_arg = "-6" if $import_ipv6;
	my $smallest_bm4_arg = "";
#	$smallest_bm4_arg = "-x $smallest_bm4" if $smallest_bm4;
	$smallest_bm4_arg = "-x 22" if $import_ipv4;
	my $smallest_bm6_arg = "";
#	$smallest_bm6_arg = "-y $smallest_bm6" if $smallest_bm6;
	$smallest_bm6_arg = "-y 64" if $import_ipv6;
	my $init_known_networks_arg = "";
	$init_known_networks_arg = "-z" if $init_known_networks eq "yes";
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

	exec ("$ini_prog -c $community -s $snmp_version -i $client_id -l $lang -d $ini_devices -g $config_file -u $user $add_comment_arg $include_spreadsheet_networks_arg -m $max_sync_procs $auth_proto_arg $auth_pass_arg $priv_proto_arg $priv_pass_arg $sec_level_arg $ipv4_arg $ipv6_arg $smallest_bm4_arg $smallest_bm6_arg $init_known_networks_arg $local_routes_arg $static_routes_arg $other_routes_arg $ospf_routes_arg $rip_routes_arg $isis_routes_arg $eigrp_routes_arg $process_networks_v4_arg $process_networks_v6_arg");


	exit 0;
}
