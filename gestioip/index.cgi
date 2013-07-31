#!/usr/bin/perl -T -w


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
use DBI;
use lib './modules';
use GestioIP;

my $daten=<STDIN>;
my $gip = GestioIP -> new();
my %daten=$gip->preparer("$daten") if $daten;

my $lang = $daten{'lang'} || "";
my ($lang_vars,$vars_file,$entries_per_page);
if ( $daten{'entries_per_page'} ) {
	$daten{'entries_per_page'} = "500" if $daten{'entries_per_page'} !~ /^\d{1,3}$/; 
	($lang_vars,$vars_file,$entries_per_page)=$gip->get_lang("$daten{'entries_per_page'}","$lang");
} else {
	($lang_vars,$vars_file,$entries_per_page)=$gip->get_lang("","$lang");
}

my ($show_rootnet, $show_endnet, $hide_not_rooted);
if ( defined($daten{show_rootnet}) ) {
	$show_rootnet= $daten{show_rootnet} ? 1 : 0;
	$gip->set_show_rootnet_val("1");
} elsif (( defined($daten{filter_button}) || defined($daten{pages_links_red_button})) && ! defined($daten{show_rootnet}) ) {
	$show_rootnet="0";
	$gip->set_show_rootnet_val("0");
} else {
	$show_rootnet=$gip->get_show_rootnet_val();
}

if ( defined($daten{show_endnet}) ) {
	$show_endnet=$daten{show_endnet} ? 1 : 0;
	$gip->set_show_endnet_val("1");
} elsif (( defined($daten{filter_button}) || defined($daten{pages_links_red_button})) && ! defined($daten{show_endnet}) ) {
	$show_endnet="0";
	$gip->set_show_endnet_val("0");
} else {
	$show_endnet=$gip->get_show_endnet_val();
}

if ( defined($daten{hide_not_rooted}) ) {
	$hide_not_rooted=$daten{hide_not_rooted} ? 1 : 0;
	$gip->set_hide_not_rooted_val("1");
} elsif (( defined($daten{filter_button}) || defined($daten{pages_links_red_button})) && ! defined($daten{hide_not_rooted}) ) {
	$hide_not_rooted="0";
	$gip->set_hide_not_rooted_val("0");
} else {
	$hide_not_rooted=$gip->get_hide_not_rooted_val();
}

my $first_client_id = $gip->get_first_client_id();
my $client_id = $daten{'client_id'} || $gip->get_default_client_id("$first_client_id");

my @global_config = $gip->get_global_config("$client_id");
my $ipv4_only_mode=$global_config[0]->[5] || "yes";
my $ip_version_ele="";
if ( $ipv4_only_mode eq "no" ) {
	$ip_version_ele = $daten{'ip_version_ele'} || "";
	if ( $ip_version_ele ) {
		$ip_version_ele = $gip->set_ip_version_ele("$ip_version_ele");
	} else {
		$ip_version_ele = $gip->get_ip_version_ele();
	}
} else {
	$ip_version_ele = "v4";
}

$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{redes_dispo_message}","$vars_file");

my $server_proto=$gip->get_server_proto();
my $base_uri = $gip->get_base_uri();

my $tipo_ele = $daten{'tipo_ele'} || "NULL";
my $loc_ele = $daten{'loc_ele'} || "NULL";
my $start_entry=$daten{'start_entry'} || '0';
my $order_by=$daten{'order_by'} || 'red_auf';
my $first_call = $daten{'first_call'} || "no";
$first_call="no" if $first_call ne "yes";
$gip->print_error("$client_id",$$lang_vars{formato_malo_message}) if $start_entry !~ /^\d{1,4}$/;

my $tipo_ele_id=$gip->get_cat_net_id("$client_id","$tipo_ele") || "-1";
my $loc_ele_id=$gip->get_loc_id("$client_id","$loc_ele") || "-1";

my @ip=$gip->get_redes("$client_id","$tipo_ele_id","$loc_ele_id","$start_entry","$entries_per_page","$order_by","$ip_version_ele","$show_rootnet","$show_endnet","$hide_not_rooted");
my $anz_values_redes = scalar(@ip);
my $ip=$gip->prepare_redes_array("$client_id",\@ip,"$order_by","$start_entry","$entries_per_page","$ip_version_ele");

my $pages_links=$gip->get_pages_links_red("$client_id","$start_entry","$anz_values_redes","$entries_per_page","$tipo_ele","$loc_ele","$order_by","","","$show_rootnet","$show_endnet","$hide_not_rooted");

if ( $ip[0] ) {
	$gip->PrintRedTabHead("$client_id","$vars_file","$start_entry","$entries_per_page","$pages_links","$tipo_ele","$loc_ele","$ip_version_ele","$show_rootnet","$show_endnet","$hide_not_rooted");
	$gip->PrintRedTab("$client_id",$ip,"$vars_file","simple","$start_entry","$tipo_ele","$loc_ele","$order_by","","$entries_per_page","$ip_version_ele","$show_rootnet","$show_endnet","","","$hide_not_rooted");
} else {
	if ( $ip_version_ele eq "v4" ) {
		$gip->PrintRedTabHead("$client_id","$vars_file","$start_entry","$entries_per_page","$pages_links","$tipo_ele","$loc_ele","$ip_version_ele","$show_rootnet","$show_endnet","$hide_not_rooted");
		print "<p class=\"NotifyText\">$$lang_vars{no_networks_message}</p><br>\n";
	} else {
		$gip->PrintRedTabHead("$client_id","$vars_file","$start_entry","$entries_per_page","$pages_links","$tipo_ele","$loc_ele","$ip_version_ele","$show_rootnet","$show_endnet","$hide_not_rooted");
		print "<p class=\"NotifyText\">$$lang_vars{no_ipv6_networks_message}</p><br>\n";
	}

	if ( $first_call eq "yes" ) {
		print "<p><br><b>$$lang_vars{first_call1_message}</b><br><p><br>\n";
		print "$$lang_vars{import_sheet_message}<br>\n";
		print "<form name=\"import_red_spread\" method=\"POST\" action=\"$server_proto://$base_uri/res/ip_import_spreadsheet_form.cgi\" style=\"display:inline\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"submit\" class=\"input_link_w\" value=\"$$lang_vars{import_networks_from_spreadsheet_message}\" name=\"B1\"></form><br><p><br>\n";
		print "$$lang_vars{start_initialization_message}<br>\n";
		print "<form name=\"initialize\" method=\"POST\" action=\"$server_proto://$base_uri/res/ip_initialize_form.cgi\" style=\"display:inline\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"submit\" class=\"input_link_w\" value=\"$$lang_vars{discover_message}\" name=\"B1\"></form><br><p><br>\n";
		print "$$lang_vars{start_network_snmp_discovery_message}<br>\n";
		print "<form name=\"import_snmp\" method=\"POST\" action=\"$server_proto://$base_uri/res/ip_import_snmp_form.cgi\" style=\"display:inline\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"submit\" class=\"input_link_w\" value=\"$$lang_vars{import_networks_from_snmp_message}\" name=\"B1\"></form><br><p><br>\n";
		print "$$lang_vars{add_net_manually_message}<br>\n";
		print "<form name=\"insertred\" method=\"POST\" action=\"$server_proto://$base_uri/res/ip_insertred_form.cgi\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"submit\" class=\"input_link_w\" value=\"$$lang_vars{nuevo_message}\" name=\"B1\"></form><br>\n";
	}
}

$gip->print_end("$client_id","$vars_file","go_to_top");
