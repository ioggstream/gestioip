#!/usr/bin/perl -T -w

# Copyright (C) 2013 Marc Uebel

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

# VERSION 3.0.0


use strict;
use SNMP;
use lib './modules';
use GestioIP;
use Net::IP qw(:PROC);

my $daten=<STDIN>;
my $gip = GestioIP -> new();
my %daten=$gip->preparer($daten);

my $lang = $daten{'lang'} || "";
my ($lang_vars,$vars_file)=$gip->get_lang("","$lang");

my $client_id = $daten{'client_id'} || $gip->get_first_client_id();

my $ip_version = $daten{'ip_version'} || "v4";

if ( ! $daten{'snmp_node'} ) {
                $gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{live_data_message}","$vars_file");
                $gip->print_error("$client_id","$$lang_vars{formato_malo_message} (0)");
}

if ( $ip_version eq "v6" ) {
	my $valid_v6=$gip->check_valid_ipv6("$daten{'snmp_node'}") || "0";
	if ( $valid_v6 != "1" ) {
		$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{live_data_message}","$vars_file");
		$gip->print_error("$client_id","$$lang_vars{no_valid_ipv6_address_message}");
	}
} elsif ( $ip_version eq "v4" ) {
	if ( $daten{'snmp_node'} !~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/ ) {
		$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{live_data_message}","$vars_file");
		$gip->print_error("$client_id","$$lang_vars{ip_invalido_message}");
	}
} else {
	$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{live_data_message}","$vars_file");
	$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (0a)");
}

my $node=$daten{'snmp_node'} || "";

$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{live_data_message} $node","$vars_file");


my $align="align=\"right\"";
my $align1="";
my $ori="left";
my $rtl_helper="<font color=\"white\">x</font>";
if ( $vars_file =~ /vars_he$/ ) {
	$align="align=\"left\"";
	$align1="align=\"right\"";
	$ori="right";
}

my $community=$daten{'community_string'} || "public";
my $snmp_version=$daten{snmp_version} || "1";


my @config = $gip->get_config("$client_id");
my $smallest_bm = $config[0]->[0] || "16";
my $smallest_bm6 = $config[0]->[7] || "64";

my $community_type="Community";

my $auth_pass="";
my $auth_proto="";
my $auth_is_key="";
my $priv_proto="";
my $priv_pass="";
my $priv_is_key="";
my $sec_level="noAuthNoPriv";

if ( $snmp_version == "3" ) {
	$community_type = "SecName";
	$auth_proto=$daten{'auth_proto'} || "";
	$auth_pass=$daten{'auth_pass'} || "";
#	$auth_is_key=$daten{'auth_is_key'} || "";
	$priv_proto=$daten{'priv_proto'} || "";
	$priv_pass=$daten{'priv_pass'} || "";
#	$priv_is_key=$daten{'priv_is_key'} || "";
	$sec_level=$daten{'sec_level'} || "";
	$gip->print_error("$client_id","$$lang_vars{introduce_community_string_message}") if ! $community;
	$gip->print_error("$client_id","$$lang_vars{introduce_auth_pass_message}") if $auth_proto && ! $auth_pass;
	$gip->print_error("$client_id","$$lang_vars{introduce_auth_proto_message}") if $auth_pass && ! $auth_proto;
	$gip->print_error("$client_id","$$lang_vars{introduce_priv_pass_message}") if $priv_proto && ! $priv_pass;
	$gip->print_error("$client_id","$$lang_vars{introduce_priv_proto_message}") if $priv_pass && ! $priv_proto;
	$gip->print_error("$client_id","$$lang_vars{introduce_priv_auth_missing_message}") if $priv_proto && ( ! $auth_proto || ! $auth_pass );
	if ( $auth_pass ) {
		$gip->print_error("$client_id","$$lang_vars{auth_pass_characters_message} $auth_pass") if $auth_pass !~ /^.{8,50}$/;
	}
	if ( $priv_pass ) {
		$gip->print_error("$client_id","$$lang_vars{priv_pass_characters_message}") if $priv_pass !~ /^.{8,50}$/;
	}
}


if ( $ip_version eq "v4" ) {
	if ( $node !~ /^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})$/ ) {
		$gip->print_error("$client_id","$$lang_vars{ip_invalido_message} <b>$node</b>");
	}
} else {
	my $valid_v6 = $gip->check_valid_ipv6("$node") || "0";
	$gip->print_error("$client_id","$$lang_vars{no_valid_ipv6_address_message} <b>$node</b>") if $valid_v6 != "1";
}


#LLDP INFO

my $na_gray="<font color=\"gray\">N/A</font>";
my $first_query_ok = "0";
my $vars;

#### SNMP INFO SESSION
my $debug="";
my $mibdirs_ref = $gip->check_mib_dir("$client_id","$vars_file");

my $snmp_info_session=$gip->create_snmp_info_session("$client_id","$node","$community","$community_type","$snmp_version","$auth_pass","$auth_proto","$auth_is_key","$priv_proto","$priv_pass","$priv_is_key","$sec_level",$mibdirs_ref,"$vars_file","$debug");

if ( ! $snmp_info_session ) {
	print "<p><b>$node</b>: $$lang_vars{snmp_connect_to_device_message}<br>\n";
	print "<p><br><p><FORM><INPUT TYPE=\"BUTTON\" VALUE=\"$$lang_vars{atras_message}\" ONCLICK=\"history.go(-1)\" class=\"error_back_link\"></FORM>\n";
	$gip->print_end("$client_id");
}

$snmp_info_session->bulkwalk(0);

if ($snmp_info_session->{ErrorStr}) {
	if ( $snmp_info_session->{ErrorStr} =~ /nosuchname/i ) {
#		print "<p><br><b>$node</b>: $$lang_vars{nosuchname_snmp_error_message}\n";
	} elsif ( $snmp_info_session->{ErrorStr} =~ /authentication failure/i ) {
		print "<p><b>$node</b>: $$lang_vars{snmp_authentication_error}<br>\n";
		print "<p><br><p><FORM><INPUT TYPE=\"BUTTON\" VALUE=\"$$lang_vars{atras_message}\" ONCLICK=\"history.go(-1)\" class=\"error_back_link\"></FORM>\n";
		$gip->print_end("$client_id");
	} else {
		print "<p><b>$node</b>: $$lang_vars{snmp_connect_error_message}<br>\n";
		print "<p>$snmp_info_session->{ErrorStr}<p><br>$$lang_vars{comprobar_host_and_community_message}<br>" if $snmp_version == 1 || $snmp_version == 2;
		print "<p><br><p><FORM><INPUT TYPE=\"BUTTON\" VALUE=\"$$lang_vars{atras_message}\" ONCLICK=\"history.go(-1)\" class=\"error_back_link\"></FORM>\n";
		$gip->print_end("$client_id");
	}
} else {
	$first_query_ok = "1";
}

my $device_model="";
my $device_vendor="";
my $device_serial="";
my $device_contact="";
my $device_name="";
my $device_location="";
my $device_descr="";
my $device_forwarder="";
my $device_os="";
my $device_uptime="";


$snmp_info_session->bulkwalk(0);
#	$snmp_info_connect ="0";
$device_model=$snmp_info_session->model() || "$na_gray";
$device_model = "$na_gray" if $device_model =~ /enterprises\.\d/;
$device_vendor=$snmp_info_session->vendor() || "$na_gray";
$device_serial=$snmp_info_session->serial() || "$na_gray";
$device_contact=$snmp_info_session->contact() || "$na_gray";
$device_name=$snmp_info_session->name() || "$na_gray";
$device_location=$snmp_info_session->location() || "$na_gray";
$device_descr=$snmp_info_session->description() || "$na_gray";
$device_forwarder=$snmp_info_session->ipforwarding() || "$na_gray";
$device_uptime=$snmp_info_session->uptime() || "$na_gray";


$device_os="$na_gray";

my $device_uptime_orig=$device_uptime;
if ( $device_uptime ne $na_gray ) {
	$device_uptime=$device_uptime/100;
	$device_uptime =~ s/\.\d+//;
	my $up_years = (int($device_uptime/(60*60*24*365)))%10;
	my $up_days=int($device_uptime/(24*60*60));
	my $up_hours=($device_uptime/(60*60))%24;
	my $up_mins=($device_uptime/60)%60;
	my $up_secs=$device_uptime%60;
	$device_uptime=$up_days ."d " . $up_hours . "h " . $up_mins . "m " . $up_secs . "s";
	$device_uptime=$up_years . "y " . $device_uptime if $up_years ne "0";
}



# Fetch interface information

my %if_values=();
my ($ifDescr,$ifIndex,$ifType,$ifSpeed,$ifPhysAddress,$ifAdminStatus,$ifOperStatus,$ifName,$ifAlias,$ifInErrors,$ifOutErrors,$ifLastChange,$duplex,$neighbor_ip,$neighbor_port,$duplex_admin,$vlan_num,$vlan_default,$vlan_default_name,$ifLastChange);
$ifDescr=$ifIndex=$ifType=$ifSpeed=$ifPhysAddress=$ifAdminStatus=$ifOperStatus=$ifName=$ifAlias=$ifInErrors=$ifOutErrors=$ifLastChange=$duplex=$neighbor_ip=$neighbor_port=$duplex_admin=$vlan_num=$vlan_default=$vlan_default_name=$ifLastChange="";

my $interfaces = $snmp_info_session->interfaces();

my $i_type=$snmp_info_session->i_type();
my $i_speed=$snmp_info_session->i_speed();
my $i_mac=$snmp_info_session->i_mac(); # ifPhysAddress
my $i_up=$snmp_info_session->i_up(); # ifOperStatus
my $i_up_admin=$snmp_info_session->i_up_admin(); # ifAdminStatus
my $i_lastchange=$snmp_info_session->i_lastchange(); # ifAdminStatus
my $i_errors_in=$snmp_info_session->i_errors_in(); # ifAdminStatus
my $i_errors_out=$snmp_info_session->i_errors_out(); # ifAdminStatus

my $interfaces_vlan = $snmp_info_session->interfaces();
my $vlans_default = $snmp_info_session->qb_i_vlan() || ();
my $i_vlan_membership = $snmp_info_session->i_vlan_membership() || ();
my $i_name = $snmp_info_session->i_name() || ();
my $i_vlan = $snmp_info_session->i_vlan() || ();

my $v_name = $snmp_info_session->v_name() || ();
foreach (keys %$v_name) {
    next if /^\d+$/; # Si la vlan es todo digitos, OK
    /\d+$/;
    $v_name->{$&} = $v_name->{$_};
    delete $v_name->{$_};
}

my $i_alias = $snmp_info_session->i_alias() || ();
my $qb_v_egress = $snmp_info_session->qb_v_egress() || ();
my $qb_v_untagged = $snmp_info_session->qb_v_untagged() || ();
my $v_index = $snmp_info_session->v_index() || ();
my $i_duplex   = $snmp_info_session->i_duplex();
my $i_duplex_admin = $snmp_info_session->i_duplex_admin();

my $name_dup  = $snmp_info_session->name();
my $class_dup = $snmp_info_session->class();
# print "SNMP::Info is using this device class : $class_dup<p>\n";


# Get CDP Neighbor snmp_info_session
my $c_if       = $snmp_info_session->c_if() || "";
my $c_ip       = $snmp_info_session->c_ip();
my $c_port     = $snmp_info_session->c_port();
my $c_index	= $snmp_info_session->i_index();

# data per port

use POSIX qw(strftime);
my $datetime=time();

foreach my $iid (keys %$interfaces){
	$ifType=$i_type->{$iid} || $na_gray;
	$ifSpeed=$i_speed->{$iid} || $na_gray;
	$ifPhysAddress=$i_mac->{$iid} || $na_gray;
	$ifOperStatus=$i_up->{$iid} || $na_gray;
	$ifAdminStatus=$i_up_admin->{$iid} || $na_gray;
#	$ifLastChange = ($snmp_info_session->uptime() - $i_lastchange->{$iid});
	$ifLastChange = ($datetime + $snmp_info_session->uptime() - $i_lastchange->{$iid});
	if ( $ifLastChange < 0 || ! $ifLastChange || $ifLastChange > $snmp_info_session->uptime() ) {
		$ifLastChange="-";
	} else {
		my $seconds = ($ifLastChange/100);
		$ifLastChange=sprintf ("%.1d Days<br>%.2d:%.2d:%.2d", $seconds/86400, $seconds/3600%24, $seconds/60%60, $seconds%60);
	}

	$ifInErrors=$i_errors_in->{$iid} || $na_gray;
	$ifOutErrors=$i_errors_out->{$iid} || $na_gray;
#	$ifName=$i_name->{$iid} || $na_gray;
	$ifName=$interfaces->{$iid} || $na_gray;
	$ifAlias=$i_alias->{$iid} || $na_gray;

	push @{$if_values{$iid}},"$ifDescr","$ifType","$ifSpeed","$ifPhysAddress","$ifAdminStatus","$ifOperStatus","$ifName","$ifAlias","$ifInErrors","$ifOutErrors","$ifLastChange";

	$duplex = $i_duplex->{$iid} || $na_gray;
	$duplex_admin=$i_duplex_admin->{$iid} || $na_gray;

	# The CDP Table has table entries different than the interface tables.
	# So we use c_if to get the map from cdp table to interface table.

	if ( $c_if ) {
		my %c_map = reverse %$c_if; 
		my $c_key = $c_map{$iid};

		if ( $c_key && exists($c_ip->{$c_key})) {
			$neighbor_ip = $c_ip->{$c_key};
		} else {
			$neighbor_ip=$na_gray;
		}
		if ( $c_key && exists($c_port->{$c_key})) {
			$neighbor_port = $c_port->{$c_key};
		} else {
			$neighbor_port=$na_gray;
		}

		push @{$if_values{$iid}},"$duplex","$neighbor_ip","$neighbor_port","$duplex_admin";
	} else {
		push @{$if_values{$iid}},"$duplex","$neighbor_ip","$neighbor_port","$duplex_admin";
	}

	if( defined @{$i_vlan_membership->{$iid}} ) {
		$vlan_num = join(',', sort { $a <=> $b } (@{$i_vlan_membership->{$iid}}));
	} else {
		$vlan_num = $na_gray;
	}
	$vlan_default = $i_vlan->{$iid} || $na_gray;
	$vlan_default_name=$v_name->{$i_vlan->{$iid}} if exists($i_vlan->{$iid});
	$vlan_default_name=$na_gray if ! $vlan_default_name;

	push @{$if_values{$iid}},"$vlan_num","$vlan_default","$vlan_default_name";
	push @{$if_values{$iid}},"$ifAlias";
}




my %portindex_mac_values;
$snmp_info_session->bulkwalk(0);


my $cisco_index = $snmp_info_session->cisco_comm_indexing();
my $vlan_numbers=$snmp_info_session->v_index();
my ($number_ports, $number_vlans); 
$number_ports=$number_vlans=$na_gray;


if ( $cisco_index == 1 ) {
	# CISCO
	my $i_name     = $snmp_info_session->i_name();

	foreach my $v_num(keys %$vlan_numbers) {
		if ( $v_num =~ /^\d\.\d+/ ) {
			$v_num =~ s/^\d\.//;
		}
		my $community_orig=$community;
		$community_orig.='@' . $v_num;
		my $snmp_info_session=$gip->create_snmp_info_session("$client_id","$node","$community_orig","$community_type","$snmp_version","$auth_pass","$auth_proto","$auth_is_key","$priv_proto","$priv_pass","$priv_is_key","$sec_level",$mibdirs_ref,"$vars_file","$debug");
		if ($snmp_info_session->{ErrorStr}) {
			if ( $snmp_info_session->{ErrorStr} =~ /nosuchname/i ) {
			#               print "<p><br><b>$node</b>: $$lang_vars{nosuchname_snmp_error_message}\n";
			} elsif ( $snmp_info_session->{ErrorStr} =~ /authentication failure/i ) {
				print "<p><b>$node</b>: $$lang_vars{snmp_authentication_error}<br>\n";
				print "<p><br><p><FORM><INPUT TYPE=\"BUTTON\" VALUE=\"$$lang_vars{atras_message}\" ONCLICK=\"history.go(-1)\" class=\"error_back_link\"></FORM>\n";
				$gip->print_end("$client_id");
			} else {
				print "<p><b>$node</b>: $$lang_vars{snmp_connect_error_message}:" . $snmp_info_session->{ErrorStr} . "<br>\n";
				print "<p>$snmp_info_session->{ErrorStr}<p><br>$$lang_vars{comprobar_host_and_community_message}<br>" if $snmp_version == 1 || $snmp_version == 2;
				print "<p><br><p><FORM><INPUT TYPE=\"BUTTON\" VALUE=\"$$lang_vars{atras_message}\" ONCLICK=\"history.go(-1)\" class=\"error_back_link\"></FORM>\n";
				$gip->print_end("$client_id");
			}
		} else {
			$first_query_ok = "1";
		}


		my $fw_mac     = $snmp_info_session->fw_mac();
		my $fw_port    = $snmp_info_session->fw_port();
		my $bp_index   = $snmp_info_session->bp_index();
		my $i_descr    = $snmp_info_session->i_description();

		foreach my $fw_index (keys %$fw_mac){
			my $mac   = $fw_mac->{$fw_index} || "";
			my $bp_id = $fw_port->{$fw_index} || "";
			my $iid   = $bp_index->{$bp_id} || "";
			my $port  = $interfaces->{$iid} || "";
			my $name = $i_name->{$iid} || "";
			my $description = $i_descr->{$iid} || "";
#			next if $name =~ /Nu0/i;
			next if ! $port;
			$name=$port if ! $name;
			$description=$port if ! $description;
			push @{$portindex_mac_values{$iid}},"$port%%$description%%$mac";
		}

		print "<p>\n";
		
		$number_ports=$snmp_info_session->b_ports() || "$na_gray";
		$number_vlans=$snmp_info_session->qb_vlans() || "$na_gray";
	}

} else {
	my $fw_mac     = $snmp_info_session->fw_mac();
	my $fw_port    = $snmp_info_session->fw_port();
	my $bp_index   = $snmp_info_session->bp_index();
	my $i_descr = $snmp_info_session->i_description();
	my $i_name = $snmp_info_session->i_name();

	foreach my $fw_index (keys %$fw_mac){
		my $mac   = $fw_mac->{$fw_index} || "";
		my $bp_id = $fw_port->{$fw_index} || "";
		my $iid   = $bp_index->{$bp_id} || "";
		my $port  = $interfaces->{$iid} || "";
		my $name = $i_name->{$iid} || "";
		my $description = $i_descr->{$iid} || "";
#		next if $name =~ /Nu0/i;
		next if ! $port;
		$name=$port if ! $name;
		$description=$port if ! $description;
		push @{$portindex_mac_values{$iid}},"$port%%$description%%$mac";
	}

	$number_ports=$snmp_info_session->b_ports() || "$na_gray";
	$number_vlans=$snmp_info_session->qb_vlans() || "$na_gray";
}



my $session=$gip->create_snmp_session("$client_id","$node","$community","$community_type","$snmp_version","$auth_pass","$auth_proto","$auth_is_key","$priv_proto","$priv_pass","$priv_is_key","$sec_level","$vars_file") || $gip->print_end("$client_id");

if ($session->{ErrorStr}) {
	if ( $session->{ErrorStr} =~ /nosuchname/i ) {
	#               print "<p><br><b>$node</b>: $$lang_vars{nosuchname_snmp_error_message}\n";
	} elsif ( $session->{ErrorStr} =~ /authentication failure/i ) {
		print "<p><b>$node</b>: $$lang_vars{snmp_authentication_error}<br>\n";
		print "<p><br><p><FORM><INPUT TYPE=\"BUTTON\" VALUE=\"$$lang_vars{atras_message}\" ONCLICK=\"history.go(-1)\" class=\"error_back_link\"></FORM>\n";
		$gip->print_end("$client_id");
	} else {
		print "<p><b>$node</b>: $$lang_vars{snmp_connect_error_message}<br>\n";
		print "<p>$session->{ErrorStr}<p><br>$$lang_vars{comprobar_host_and_community_message}<br>" if $snmp_version == 1 || $snmp_version == 2;
		print "<p><br><p><FORM><INPUT TYPE=\"BUTTON\" VALUE=\"$$lang_vars{atras_message}\" ONCLICK=\"history.go(-1)\" class=\"error_back_link\"></FORM>\n";
		$gip->print_end("$client_id");
	}
} else {
	$first_query_ok = "1";
}



### ARP Cache

my %arp_cache=();
# set up the data structure for the getnext command
$vars = new SNMP::VarList(['ipNetToMediaNetAddress'],
                          ['ipNetToMediaPhysAddress']);

# get first row
my ($ip,$mac) = $session->getnext($vars);
die $session->{ErrorStr} if ($session->{ErrorStr});

while (!$session->{ErrorStr} and 
	$$vars[0]->tag eq "ipNetToMediaNetAddress"){
	push @{$arp_cache{$ip}},"$mac";
	($ip,$mac) = $session->getnext($vars);
}

### RAM, Memoria

my ($load1,$load5,$load15,$swap_total,$swap_available,$ram_total,$ram_used,$ram_free,$ram_shared,$ram_buffered,$cached_mem_total,$proc_count);


if ( $device_vendor =~ /linux/i || $device_descr =~ /linux/i ) {
	$load1 = $session->get('.1.3.6.1.4.1.2021.10.1.3.1');
	$load5 = $session->get('.1.3.6.1.4.1.2021.10.1.3.2');
	$load15 = $session->get('.1.3.6.1.4.1.2021.10.1.3.3');
	$swap_total = $session->get('.1.3.6.1.4.1.2021.4.3.0');
	$swap_available = $session->get('.1.3.6.1.4.1.2021.4.4.0');
	$ram_total = $session->get('.1.3.6.1.4.1.2021.4.5.0');
	$ram_used = $session->get('.1.3.6.1.4.1.2021.4.6.0');
	$ram_free = $session->get('.1.3.6.1.4.1.2021.4.11.0');
	$ram_shared = $session->get('.1.3.6.1.4.1.2021.4.13.0');
	$ram_buffered = $session->get('.1.3.6.1.4.1.2021.4.14.0');
	$cached_mem_total = $session->get('.1.3.6.1.4.1.2021.4.15.0');
	$proc_count = $session->get('.1.3.6.1.4.1.2021.2.1.5');
}




### PRINT live data

print "<p>\n";
print "<b>$$lang_vars{model_message}</b>: $device_model<br><b>$$lang_vars{manufacturer_message}</b>: $device_vendor<br><b>$$lang_vars{serial_number_message}</b>: $device_serial<br><b>$$lang_vars{contact_message}</b>: $device_contact<br><b>$$lang_vars{name_message}</b>: $device_name<br><b>$$lang_vars{snmp_location_message}</b>: $device_location<br><b>$$lang_vars{description_message}</b>: $device_descr<br><b>$$lang_vars{forwarder_message}</b>: $device_forwarder<br><b>uptime</b>: $device_uptime<br>\n";

### Print VLANS

my %vlans;
if ( $cisco_index == 1 ) {
	my $cisco_vlan_index=$snmp_info_session->v_index() || ();
	my $cisco_vlan_names=$snmp_info_session->v_name() || ();
	foreach my $vnums (keys %$cisco_vlan_index) {
		my $vlan_name_show=$cisco_vlan_names->{$vnums};
		$vlans{$vnums}=$vlan_name_show;
	}
} else {
	my $qb_v_name = $snmp_info_session->qb_v_name() || ();
	foreach my $vnums (sort keys %$v_index) {
		my $vlan_name_show=$qb_v_name->{$vnums};
		$vlans{$vnums}=$vlan_name_show;
	}
}

if ( keys %vlans ) {
	print "<p>\n";
	my $vlan_name_show=$na_gray;
	print "<b>VLANS</b><p>\n";
	print "<table border=\"1\"  style=\"border-collapse: collapse;\">\n";
	print "<tr><td><b>ID</b></td><td><b>Name</b></td></tr>\n";
	foreach my $vnums (sort { $a <=> $b } keys %vlans) {
		print "<tr><td> $vnums </td><td> $vlans{$vnums} </td></tr>\n";
	}
	print "</table>\n";
}

### Print interface table

my $color_helper=0;

if ( %if_values ) {
	print "<p><br><b>$$lang_vars{interfaces_message}</b><p>\n";
	print "<table border=\"0\" style=\"border-collapse:collapse\" cellpadding=\"2\" width=\"100%\">\n";
	print "<tr><td><br><b>index</b></td><td><br><b>Name</b></td><td width=\"5\"><br><b>Alias</b></td><td><br><b>Speed</b></td><td><b><br>PhysAddress</b></td><td><b>Admin<br>Status</b></td><td><b>Oper<br>Status</b></td><td><b>PVID<br>Name</b></td><td><br><b>PVID</b></td><td><b>Last<br>Change</b></td><td><br><b>Duplex</b></td><td><b>Errors<br>In</b></td><td><b>Errors<br>Out</b></td><td><br><b>Neightb. IP</b></td><td><br><b>Neightb. Port</b></td><td><br><b>VLAN</b></td></tr>\n";

	my $vlan=$na_gray;
	my $color;
	foreach my $key ( sort { $a <=> $b } keys (%if_values) ) {
		next if ! $key;

		my @value=$if_values{$key};
		$ifIndex=$key;
		$ifDescr=$value[0]->[0] || $na_gray;
		$ifType=$value[0]->[1] || $na_gray;
		$ifSpeed=$value[0]->[2] || $na_gray;
		$ifPhysAddress=$value[0]->[3] || $na_gray;
		$ifAdminStatus=$value[0]->[4] || $na_gray;
		$ifOperStatus=$value[0]->[5] || $na_gray;
		$ifName=$value[0]->[6] || $na_gray;
		$ifAlias=$value[0]->[7] || $na_gray;
		$ifInErrors=$value[0]->[8] || "-";
		$ifOutErrors=$value[0]->[9] || "-";
		$ifLastChange=$value[0]->[10] || $na_gray;
		$duplex=$value[0]->[11] || $na_gray;
		$neighbor_ip=$value[0]->[12] || $na_gray;
		$neighbor_port=$value[0]->[13] || $na_gray;
		my $duplex_admin=$value[0]->[14] || $na_gray;
		$duplex = $duplex . "/" . $duplex_admin if $duplex_admin ne $na_gray && $duplex_admin ne "full" && $duplex_admin ne "half";
		$vlan=$value[0]->[15];
		$vlan_default=$value[0]->[16];
		$vlan_default_name=$value[0]->[17];

		if ( $ifName =~ /$na_gray/ || $ifName =~ /port.channel/i  || $ifName =~ /Nu0/ ) {
			next;
		}
		if ( $ifSpeed !~ /$na_gray/ ) {
			$ifSpeed=SNMP::Info::munge_speed($ifSpeed);
		}

		$ifAlias=$value[0]->[18];

		if ( $color_helper eq "0" ) {
			$color="#efefef";
			$color_helper="1";
		} else {
			$color="white";
			$color_helper="0";
		}
		
		print "<tr class=\"show_detail\" bgcolor=\"$color\"><td>$key</td><td>$ifName</td><td>$ifAlias</td><td>$ifSpeed</td><td>$ifPhysAddress</td><td>$ifAdminStatus</td><td>$ifOperStatus</td><td>$vlan_default_name</td><td>$vlan_default</td><td>$ifLastChange</td><td>$duplex</td><td>$ifInErrors</td><td>$ifOutErrors</td><td>$neighbor_ip</td><td>$neighbor_port</td><td>$vlan</td></tr>\n";	
	}

	print "</table>\n";
}


if ( $number_ports !~ /$na_gray/ || $number_vlans !~ /$na_gray/ ) {
	print "<p>\n";
	print "<b>$$lang_vars{number_ports_message}:</b> $number_ports<br>\n";
	print "<b>$$lang_vars{number_vlans_message}:</b> $number_vlans<br>\n";
}


if ($load1 || $load5 || $load15 || $swap_total || $swap_available || $ram_total || $ram_used || $ram_free || $ram_shared || $ram_buffered || $cached_mem_total || $proc_count) {
	
	print "<p><br><b>$$lang_vars{resource_usage_message}</b><p>\n";
	$load1 = $na_gray if $load1 =~ /Wrong Type/ || $load1 =~ /NULL/;
	$load5 = $na_gray if $load5 =~ /Wrong Type/ || $load5 =~ /NULL/;
	$load15 = $na_gray if $load15 =~ /Wrong Type/ || $load15 =~ /NULL/;
	print "$$lang_vars{load_average_message}: $$lang_vars{load_message} 1: $load1; $$lang_vars{load_message} 5: $load5; $$lang_vars{load_message} 15: $load15<br>\n";


	$swap_total =~ /^(\d+)\s(kb)/i;
	my $swap_total_mb=$1 || "";
	if ( $swap_total_mb ) {
		$swap_total_mb=$swap_total_mb/1000;
		$swap_total=$swap_total_mb . " Mb";
	}
	
	$swap_available =~ /^(\d+)\s(kb)/i;
	my $swap_available_mb=$1 || "";
	if ( $swap_available_mb ) {
		$swap_available_mb=$swap_available_mb/1000;
		$swap_available=$swap_available_mb . " Mb";
	}
	$ram_total =~ /^(\d+)\s(kb)/i;
	my $ram_total_mb=$1 || "";
	if ( $ram_total_mb ) {
		$ram_total_mb=$ram_total_mb/1000;
		$ram_total=$ram_total_mb . " Mb";
	}
	$ram_used =~ /^(\d+)\s(kb)/i;
	my $ram_used_mb=$1 || "";
	if ( $ram_used_mb ) {
	$ram_used_mb=$ram_used_mb/1000;
		$ram_used=$ram_used_mb . " Mb";
		$ram_free =~ /^(\d+)\s(kb)/i;
	}
	my $ram_free_mb=$1 || "";
	if (  $ram_free_mb ) {
		$ram_free_mb=$ram_free_mb/1000;
		$ram_free=$ram_free_mb . " Mb";
	}
	$ram_shared =~ /^(\d+)\s(kb)/i;
	my $ram_shared_mb=$1 || "";
	if ( $ram_shared_mb ) {
		$ram_shared_mb=$ram_shared_mb/1000 if $ram_shared_mb;
		$ram_shared=$ram_shared_mb . " Mb" if $ram_shared_mb;
	}
	$ram_buffered =~ /^(\d+)\s(kb)/i;
	my $ram_buffered_mb=$1 || "";
	if ( $ram_buffered_mb ) {
		$ram_buffered_mb=$ram_buffered_mb/1000;
		$ram_buffered=$ram_buffered_mb . " Mb";
	}
	$cached_mem_total =~ /^(\d+)\s(kb)/i;
	my $cached_mem_total_mb=$1 || "";
	if ( $cached_mem_total_mb ) {
		$cached_mem_total_mb=$cached_mem_total_mb/1000;
		$cached_mem_total=$cached_mem_total_mb . " Mb";
	}
	$swap_total = $na_gray if $swap_total =~ /Wrong Type/ || $swap_total =~ /NULL/;
	$swap_available = $na_gray if $swap_available =~ /Wrong Type/ || $swap_available =~ /NULL/;
	$ram_total = $na_gray if $ram_total =~ /Wrong Type/ || $ram_total =~ /NULL/;
	$ram_used = $na_gray if $ram_used =~ /Wrong Type/ || $ram_used =~ /NULL/;
	$ram_free = $na_gray if $ram_free =~ /Wrong Type/ || $ram_free =~ /NULL/;
	$ram_shared = $na_gray if $ram_shared =~ /Wrong Type/ || $ram_shared =~ /NULL/;
	$ram_buffered = $na_gray if $ram_buffered =~ /Wrong Type/ || $ram_buffered =~ /NULL/;
	$cached_mem_total = $na_gray if $cached_mem_total =~ /Wrong Type/ || $cached_mem_total =~ /NULL/;

	print "$$lang_vars{swap_total_message}: $swap_total; $$lang_vars{swap_available_message}: $swap_available<br>\n";
	print "$$lang_vars{ram_total_message}: $ram_total; $$lang_vars{ram_used_message}: $ram_used; $$lang_vars{ram_free_message}: $ram_free; $$lang_vars{ram_shared_message}: $ram_shared; $$lang_vars{buffered_message}: $ram_buffered; $$lang_vars{cached_mem_total_message}: $cached_mem_total<br>\n";

	$proc_count = $na_gray if $proc_count =~ /Wrong Type/ || $proc_count =~ /NULL/;
	print "$$lang_vars{proc_count_message}: $proc_count <br>\n";

}


if ( %portindex_mac_values && $device_vendor !~ /linux/i && $device_descr !~ /linux/i ) {
	print "<p><br><b>$$lang_vars{macs_on_ports_message}</b><p>\n";

	foreach my $key ( sort keys (%portindex_mac_values) ) {
		my $port;
		my $description;

		@{ $portindex_mac_values{$key} }[0] =~ /^(.*)%%(.*)%%(.*)$/;
		$port=$1;
		$description = $2;
		
		print "$port ($description)<br>\n";

		my %check_exists_hash=();
		for my $i ( 0 .. $#{ $portindex_mac_values{$key} } ) {
			@{ $portindex_mac_values{$key} }[$i] =~ /^(.*)%%(.*)%%(.*)$/;
			my $mac = $3 || "";
			
			print "$mac<br>\n" if $mac && ! defined $check_exists_hash{"$mac"};
			$check_exists_hash{"$mac"}=1;
			
		}
		print "<br>\n";
			
	}
}



if ( %arp_cache ) {
	print "<p><br><b>$$lang_vars{arp_cache_message}</b><p>\n";
	print "<table>\n";
	print "<tr><td><b>IP</b></td><td><b>MAC</b></td></tr>\n";

	foreach my $key ( sort keys (%arp_cache) ) {
		print "<tr><td>$key</td><td>$arp_cache{$key}[0]</td></tr>\n";
	}
	print "</table>\n";
	print "<br><p>\n";
}


print "</span>\n";

$gip->print_end("$client_id");
