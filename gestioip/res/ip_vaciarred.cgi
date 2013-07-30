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


use strict;
use lib '../modules';
use GestioIP;
use Net::IP;
use Net::IP qw(:PROC);
use Math::BigInt;

my $daten=<STDIN>;
my $gip = GestioIP -> new();
my %daten=$gip->preparer($daten) if $daten;

my $lang = $daten{'lang'} || "";
my ($lang_vars,$vars_file,$entries_per_page,$entries_per_page_hosts,$start_entry_hosts);
if ( $daten{'entries_per_page'} ) {
        $daten{'entries_per_page'} = "500" if $daten{'entries_per_page'} !~ /^\d{1,3}$/;
        ($lang_vars,$vars_file,$entries_per_page)=$gip->get_lang("$daten{'entries_per_page'}","$lang");
} else {
        ($lang_vars,$vars_file,$entries_per_page)=$gip->get_lang("","$lang");
}

my $client_id = $daten{'client_id'} || $gip->get_first_client_id();
if ( $client_id !~ /^\d{1,4}$/ ) {
        $client_id = 1;
        $gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{clear_explic_message}","$vars_file");
        $gip->print_error("$client_id","$$lang_vars{formato_malo_message} (1)");
}

my $ip_version_ele = $daten{'ip_version_ele'} || $gip->get_ip_version_ele();

my $red_num = $daten{'red_num'};
my $anz_nets=$daten{'anz_nets'} || "0";
my @mass_update_network_ids=();
my $mass_update_network_ids="";

$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{clear_explic_message}","$vars_file");

if ( ! $daten{'mass_submit'} ) {
	if ( $daten{'red_num'} !~ /^\d{1,6}$/ ) {
		$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (2)");
	}
	$mass_update_network_ids[0]=$red_num;
	$red_num = "$daten{'red_num'}";
} else {
	my $k;
	my $j=0;
	for ($k=0;$k<=$anz_nets;$k++) {
		if ( $daten{"mass_update_red_submit_${k}"} ) {
			$mass_update_network_ids.=$daten{"mass_update_red_submit_${k}"} . "_";
			$mass_update_network_ids[$j]=$daten{"mass_update_red_submit_${k}"};
			$j++;
		}
	}
	$mass_update_network_ids =~ s/_$//;
	$gip->print_error("$client_id","$$lang_vars{select_network_message}") if ! $mass_update_network_ids;
	$gip->print_error("$client_id","$$lang_vars{formato_malo_message} $mass_update_network_ids (1)") if ($mass_update_network_ids !~ /[0-9_]/ );
}

my $referer = $daten{'referer'} || "";
my $order_by = "red_auf";
$order_by = "$daten{'order_by'}" if $daten{'order_by'};
my $host_order_by =  "IP_auf";


my ($tipo_ele, $loc_ele, $start_entry, $tipo_ele_id, $loc_ele_id, $pages_links, $ip_version, $BM, $first_ip_int, $last_ip_int,$broad_ip_int,$red_loc);

foreach $red_num(@mass_update_network_ids) {
	my @values_redes = $gip->get_red("$client_id","$red_num");
	if ( ! $values_redes[0] ) {
		$gip->print_error("$client_id","$$lang_vars{algo_malo_message}");
	}


	my $red = "$values_redes[0]->[0]" || "";
	$BM = "$values_redes[0]->[1]" || "";
	$ip_version = "$values_redes[0]->[7]" || "";

	my $redob = "$red/$BM";

#	$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$red/$BM: $$lang_vars{vaciar_red_done_list_view_message}","$vars_file");

	$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (4)") if $ip_version_ele !~ /^(v4|v6|46)$/;

	$tipo_ele = $daten{'tipo_ele'} || "NULL";
	$loc_ele = $daten{'loc_ele'} || "NULL";
	$start_entry=$daten{'start_entry'} || '0';
	$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (5)" ) if $start_entry !~ /^\d{1,4}$/;

	$tipo_ele_id=$gip->get_cat_net_id("$client_id","$tipo_ele") || "-1";
	$loc_ele_id=$gip->get_loc_id("$client_id","$loc_ele") || "-1";

	my $red_check=$gip->comprueba_red("$client_id","$red_num");

	if ( ! $red_check ) {
		$gip->print_error("$client_id","$$lang_vars{red_no_existe_message}: <b>$daten{red}</b>");
	}

	my $red_loc_id = "$values_redes[0]->[3]" || "-1";
	$red_loc=$gip->get_loc_from_id("$client_id","$red_loc_id");


	my $ipob_red = new Net::IP ($redob) or $gip->print_error("$client_id","$$lang_vars{comprueba_red_BM_message}: <b>$red/$BM</b>");
	my $redint=($ipob_red->intip());
	$redint = Math::BigInt->new("$redint");
	$first_ip_int = $redint + 1;
	$broad_ip_int = ($ipob_red->last_int());
	$broad_ip_int = Math::BigInt->new("$broad_ip_int");
	$last_ip_int = $broad_ip_int - 1;

	my $first_ip_int_del=$first_ip_int;
	my $last_ip_int_del=$last_ip_int;

	if ( $ip_version eq "v6" ) {
		$first_ip_int=$first_ip_int_del--;
		$last_ip_int=$last_ip_int_del++;
	}

	my ($host_hash_ref,$host_sort_helper_array_ref)=$gip->get_host_hash("$client_id","$first_ip_int","$last_ip_int","IP_auf","hosts","$red_num");

	my @linked_cc_id=$gip->get_custom_host_column_ids_from_name("$client_id","linked IP");
	my $linked_cc_id=$linked_cc_id[0]->[0] || "";
	my %linked_cc_values=$gip->get_linked_custom_columns_hash("$client_id","$red_num","$linked_cc_id","$ip_version");

	my @ch=$gip->get_host_no_rango("$client_id","$first_ip_int","$last_ip_int","$ip_version");
	$gip->delete_ip_no_rango_reservado("$client_id","$first_ip_int_del","$last_ip_int_del","$red_loc_id","$ip_version");
	$gip->delete_custom_host_column_entry_from_rednum("$client_id","$red_num");

	foreach my $key ( keys %$host_hash_ref ) {
		if ( exists $linked_cc_values{$key} ) {
			my $linked_ips_delete=$linked_cc_values{$key}[0];
			my $ip_ad=$linked_cc_values{$key}[1];
			my $host_id=$linked_cc_values{$key}[2];
			my @linked_ips=split(",",$linked_ips_delete);
			foreach my $linked_ip_delete(@linked_ips){
				$gip->delete_linked_ip("$client_id","$ip_version","$linked_ip_delete","$ip_ad");
			}
		}
	}



	my @switches;
	my @switches_new;

	foreach my $key ( keys %$host_hash_ref ) {

		if ( $host_hash_ref->{$key}[12] ) {
			#       next if $host_hash_ref->{$key}[4]....
			my $switch_id_hash = $host_hash_ref->{$key}[12] || "";
			@switches = $gip->get_vlan_switches_match("$client_id","$switch_id_hash");
			if (scalar(@switches) != 0) {
				foreach ( @switches ) {
					my $vlan_id = $_->[0];
					my $switches = $_->[1] || "";
					$switches =~ s/,$switch_id_hash,/,/;
					$switches =~ s/^$switch_id_hash,//;
					$switches =~ s/,$switch_id_hash$//;
					$switches =~ s/^$switch_id_hash$//;
					$gip->update_vlan_switches("$client_id","$vlan_id","$switches") if $vlan_id;
				}
			}
		}
	}


	my $i=0;
	if ( @ch ) {
		foreach (@ch) {	
			my $audit_class="1";
			my $audit_type="14";
			my $update_type_audit="11";
			my $ip=$gip->int_to_ip("$client_id","$ch[$i]->[0]","$ip_version");
			$ch[$i]->[1] = "---" if ! $ch[$i]->[1]; #hostname
			$ch[$i]->[1] = "---" if $ch[$i]->[1] eq "NULL";
			$ch[$i]->[2] = "---" if ! $ch[$i]->[2]; #host_descr
			$ch[$i]->[2] = "---" if $ch[$i]->[2] eq "NULL";
			$ch[$i]->[3] = "---" if $ch[$i]->[3] eq "NULL" || $ch[$i]->[3] eq "-1";
			$ch[$i]->[4] = "---" if $ch[$i]->[4] eq "NULL" || $ch[$i]->[4] eq "-1";
			$ch[$i]->[5] = "n" if ! $ch[$i]->[5]; # int_admin
			$ch[$i]->[6] = "---" if ! $ch[$i]->[6]; # comentario
			$ch[$i]->[6] = "---" if $ch[$i]->[6] eq "NULL";
			$ch[$i]->[7] = "---" if ! $ch[$i]->[7];
			$ch[$i]->[7] = "---" if $ch[$i]->[7] eq "NULL" || $ch[$i]->[7] eq "-1";
			my $event="$ip,$ch[$i]->[1],$ch[$i]->[2],$ch[$i]->[3],$ch[$i]->[4],$ch[$i]->[5],$ch[$i]->[6],$ch[$i]->[7]";
			$gip->insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");
			$i++;
		}
	}

	my $audit_type="7";
	my $audit_class="2";
	my $update_type_audit="1";
	my $event="$redob";
	$gip->insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");
}


my $knownhosts = $daten{'knownhosts'} || "all";
if ( $referer eq "host_list_view" ) {
	print "<p>\n";

	my $knownhosts="all";
	my $anz_host_total=$gip->get_host_hash_count("$client_id","$red_num") || "0";
	my %anz_hosts_bm = $gip->get_anz_hosts_bm_hash("$client_id","$ip_version");
	my ($anz_values_hosts,$anz_values_hosts_pages);
	my ($start_entry_hosts,$entries_per_page_hosts);
	if ( $daten{'entries_per_page_hosts'} && $daten{'entries_per_page_hosts'} =~ /^\d{1,4}$/ ) {
		$entries_per_page_hosts=$daten{'entries_per_page_hosts'};
	} else {
		$entries_per_page_hosts = "254";

	}
	$start_entry_hosts="0";

	$anz_hosts_bm{$BM} =~ s/,//g;

	if ( $host_order_by =~ /IP/ ) {
		$anz_values_hosts=$entries_per_page_hosts;
		$anz_values_hosts_pages=$anz_hosts_bm{$BM};
	} else {
		$anz_values_hosts=$anz_host_total;
		$anz_values_hosts_pages=$anz_host_total;
	}


	my ($host_hash_ref,$host_sort_helper_array_ref)=$gip->get_host_hash("$client_id","$first_ip_int","$last_ip_int","$host_order_by","$knownhosts","$red_num");

	($host_hash_ref,$first_ip_int,$last_ip_int)=$gip->prepare_host_hash("$client_id",$host_hash_ref,"$first_ip_int","$last_ip_int","res/ip_modip_form.cgi","$knownhosts","$$lang_vars{modificar_message}","$red_num","$red_loc","$vars_file","$anz_values_hosts","$start_entry_hosts","$entries_per_page_hosts","$host_order_by","$broad_ip_int","$ip_version");

	my $pages_links=$gip->get_pages_links_host("$client_id","$start_entry_hosts","$anz_values_hosts_pages","$entries_per_page_hosts","$red_num","$knownhosts","$host_order_by","$first_ip_int",$host_hash_ref,"$broad_ip_int","$ip_version","$vars_file","$referer");

	$gip->PrintIpTabHead("$client_id","$knownhosts","res/ip_modip_form.cgi","$red_num","$vars_file","$start_entry_hosts","$anz_values_hosts","$entries_per_page_hosts","$pages_links","$host_order_by","$ip_version");

	$gip->PrintIpTab("$client_id",$host_hash_ref,"$first_ip_int","$last_ip_int","res/ip_modip_form.cgi","$knownhosts","$$lang_vars{modificar_message}","$red_num","$red_loc","$vars_file","$anz_values_hosts_pages","$start_entry_hosts","$entries_per_page_hosts","$host_order_by",$host_sort_helper_array_ref,"","$ip_version");

} else {
	my ($show_rootnet, $show_endnet, $hide_not_rooted);
	$show_rootnet=$gip->get_show_rootnet_val() || "1";
	$show_endnet=$gip->get_show_endnet_val() || "1";
	$hide_not_rooted=$gip->get_hide_not_rooted_val() || "0";

	my @ip=$gip->get_redes("$client_id","$tipo_ele_id","$loc_ele_id","$start_entry","$entries_per_page","$order_by","$ip_version_ele","$show_rootnet","$show_endnet","$hide_not_rooted");

	my $anz_values_redes = scalar(@ip);
	my $pages_links=$gip->get_pages_links_red("$client_id","$start_entry","$anz_values_redes","$entries_per_page","$tipo_ele","$loc_ele","$order_by","","","$show_rootnet","$show_endnet","$hide_not_rooted");

	$gip->PrintRedTabHead("$client_id","$vars_file","$start_entry","$entries_per_page","$pages_links","$tipo_ele","$loc_ele","$ip_version_ele","$show_rootnet","$show_endnet","$hide_not_rooted");
	my $ip=$gip->prepare_redes_array("$client_id",\@ip,"$order_by","$start_entry","$entries_per_page","$ip_version_ele");
	$gip->PrintRedTab("$client_id",$ip,"$vars_file","extended","$start_entry","$tipo_ele","$loc_ele","$order_by","","$entries_per_page","$ip_version_ele","$show_rootnet","$show_endnet","","","$hide_not_rooted");
}

$gip->print_end("$client_id","$vars_file","go_to_top");
