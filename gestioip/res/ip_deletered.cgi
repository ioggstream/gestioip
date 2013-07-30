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
my ($lang_vars,$vars_file,$entries_per_page);
if ( $daten{'entries_per_page'} ) {
        $daten{'entries_per_page'} = "500" if $daten{'entries_per_page'} !~ /^\d{1,3}$/;
        ($lang_vars,$vars_file,$entries_per_page)=$gip->get_lang("$daten{'entries_per_page'}","$lang");
} else {
        ($lang_vars,$vars_file,$entries_per_page)=$gip->get_lang("","$lang");
}

my $client_id = $daten{'client_id'} || $gip->get_first_client_id();
if ( $client_id !~ /^\d{1,4}$/ ) {
	$client_id = 1;
	$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{redes_message}","$vars_file");
	$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (1)");
}

my $ip_version_ele = $daten{'ip_version_ele'} || "";

my $red_num;
my $anz_nets=$daten{'anz_nets'} || "0"; 
my @mass_update_network_ids=();
my $mass_update_network_ids="";

my $checki_message;
if ( ! $daten{'mass_submit'} ) {
	$checki_message=$$lang_vars{borrar_red_message};
} else {
	$checki_message=$$lang_vars{networks_deleted_message};
}

$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$checki_message","$vars_file");

if ( ! $daten{'mass_submit'} ) {
	$red_num = "$daten{'red_num'}" || "";
	$mass_update_network_ids[0] = "$daten{'red_num'}" || "";
	if ( $red_num !~ /^\d{1,5}$/ ) {
#		$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{borrar_red_message}","$vars_file");
		$gip->print_error("$client_id","$$lang_vars{formato_malo_message}");
	}
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



my ($show_rootnet, $show_endnet, $tipo_ele, $loc_ele, $start_entry, $order_by, $tipo_ele_id, $loc_ele_id, $anz_values_redes, $pages_links, $hide_not_rooted);

$show_rootnet=$gip->get_show_rootnet_val() || "1";
$show_endnet=$gip->get_show_endnet_val() || "1";
$hide_not_rooted=$gip->get_hide_not_rooted_val() || "0";

$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (version_ele)") if $ip_version_ele !~ /^(v4|v6|46)$/;

$tipo_ele = $daten{'tipo_ele'} || "NULL";
$loc_ele = $daten{'loc_ele'} || "NULL";
$start_entry=$daten{'start_entry'} || '0';
$gip->print_error("$client_id",$$lang_vars{formato_malo_message}) if $start_entry !~ /^\d{1,4}$/;
$order_by=$daten{'order_by'} || 'red_auf';

$tipo_ele_id=$gip->get_cat_net_id("$client_id","$tipo_ele") || "-1";
$loc_ele_id=$gip->get_loc_id("$client_id","$loc_ele") || "-1";

foreach $red_num(@mass_update_network_ids) {
		
	my @values_redes = $gip->get_red("$client_id","$red_num");
	my $red = "$values_redes[0]->[0]" || "";
	my $BM = "$values_redes[0]->[1]" || "";
	my $ip_version = "$values_redes[0]->[7]" || "";
	my $rootnet = "$values_redes[0]->[9]" || "0";
	if ( ! $red ) {
		$gip->print_error("$client_id","$$lang_vars{red_no_existe_message}");
	}
	my $red_check=$gip->comprueba_red("$client_id","$red_num");
	if ( ! $red_check ) {
		$gip->print_error("$client_id","$$lang_vars{red_no_existe_message}: <b>$daten{red}</b>");
	}


	my @linked_cc_id=$gip->get_custom_host_column_ids_from_name("$client_id","linked IP");
	my $linked_cc_id=$linked_cc_id[0]->[0] || "";
	my %linked_cc_values=$gip->get_linked_custom_columns_hash("$client_id","$red_num","$linked_cc_id","$ip_version");



	my $descr = "$values_redes[0]->[2]" || "---";
	$descr = "---" || "NULL";
	my $loc=$gip->get_loc_from_redid("$client_id","$red_num");
	$loc = "---" if $loc eq "NULL";
	my $vigilada = "$values_redes[0]->[4]" || "";
	my $comentario = "$values_redes[0]->[5]" || "---";
	$comentario = "---" || "NULL";
	my $cat_id = "$values_redes[0]->[6]" || "---";
	my $cat=$gip->get_cat_net_from_id("$client_id","$cat_id");
	$cat = "---" if $cat eq "NULL";


	$gip->delete_red("$client_id","$red_num");

	my $audit_type="16";
	my $audit_class="2";
	my $update_type_audit="1";
	my $event="$red/$BM,$descr,$loc,$cat,$comentario,$vigilada";
	$gip->insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");


	if ( $rootnet == 0 ) { 
		my $redob = "$red/$BM";

		my $ipob_red = new Net::IP ($redob) or $gip->print_error("$client_id","$$lang_vars{comprueba_red_BM_message}: <b>$red/$BM</b>");
		my $redint=($ipob_red->intip());
		$redint = Math::BigInt->new("$redint");
		my $first_ip_int = $redint + 1;
		my $last_ip_int = ($ipob_red->last_int());
		$last_ip_int = Math::BigInt->new("$last_ip_int");
		$last_ip_int = $last_ip_int - 1;


		my $first_ip_int_del=$first_ip_int;
		my $last_ip_int_del=$last_ip_int;
		if ($ip_version eq "v6" ) {
			$first_ip_int_del--;
			$last_ip_int_del++;
		}

		my ($host_hash_ref,$host_sort_helper_array_ref)=$gip->get_host_hash("$client_id","$first_ip_int","$last_ip_int","IP_auf","hosts","$red_num");
		my @switches;
		my @switches_new;

		foreach my $key ( keys %$host_hash_ref ) {

			if ( $host_hash_ref->{$key}[12] ) {
				#	next if $host_hash_ref->{$key}[4]....
				my $switch_id_hash = $host_hash_ref->{$key}[12];
				@switches = $gip->get_vlan_switches_match("$client_id","$switch_id_hash");
				my $i = 0;
				foreach ( @switches ) {
					my $vlan_id = $_->[0];
					my $switches = $_->[1];
					$switches =~ s/,$switch_id_hash,/,/;
					$switches =~ s/^$switch_id_hash,//;
					$switches =~ s/,$switch_id_hash$//;
					$switches =~ s/^$switch_id_hash$//;
					$switches_new[$i]->[0]=$vlan_id;
					$switches_new[$i]->[1]=$switches;
					$i++;
				}

				foreach ( @switches_new ) {
					my $vlan_id_new = $_->[0];
					my $switches_new = $_->[1];
					$gip->update_vlan_switches("$client_id","$vlan_id_new","$switches_new");
				}
			}
		}

		$gip->delete_custom_column_entry("$client_id","$red_num");

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

		$gip->delete_ip("$client_id","$first_ip_int_del","$last_ip_int_del","$ip_version");

		my @rangos=$gip->get_rangos_red("$client_id","$red_num");
		my $i=0;
		foreach ( @rangos ) {
			my $range_id = $rangos[$i]->[0];
			my $start_ip_int = "";
			$start_ip_int = Math::BigInt->new("$start_ip_int");
			$start_ip_int=$rangos[$i]->[1];
			my $end_ip_int=$rangos[$i]->[2];
		#	$end_ip_int = Math::BigInt->new("$end_ip_int");
			my $range_comentario = $rangos[$i]->[3] if $rangos[$i]->[3];
			my $range_red_num = $rangos[$i]->[5];

			$gip->delete_range("$client_id","$range_id") if $range_red_num eq "$red_num";

			my $audit_type="18";
			my $audit_class="2";
			my $update_type_audit="9";
			my $start_ip_audit = $gip->int_to_ip("$client_id","$start_ip_int","$ip_version");
			my $end_ip_audit = $gip->int_to_ip("$client_id","$end_ip_int","$ip_version");
			my $event="$redob:" . $start_ip_audit . "-" . $end_ip_audit;
			$event = $event . " " . $range_comentario if $range_comentario;
			$gip->insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");

			$i++;
		}
	}
}

my @ip=$gip->get_redes("$client_id","$tipo_ele_id","$loc_ele_id","$start_entry","$entries_per_page","$order_by","$ip_version_ele","$show_rootnet","$show_endnet","$hide_not_rooted");

$anz_values_redes = scalar(@ip);
$pages_links=$gip->get_pages_links_red("$client_id","$start_entry","$anz_values_redes","$entries_per_page","$tipo_ele","$loc_ele","$order_by","","","$show_rootnet","$show_endnet","$hide_not_rooted");

$gip->PrintRedTabHead("$client_id","$vars_file","$start_entry","$entries_per_page","$pages_links","$tipo_ele","$loc_ele","$ip_version_ele","$show_rootnet","$show_endnet","$hide_not_rooted");
my $ip=$gip->prepare_redes_array("$client_id",\@ip,"$order_by","$start_entry","$entries_per_page","$ip_version_ele");

if ( @ip ) {
	$gip->PrintRedTab("$client_id",$ip,"$vars_file","extended","$start_entry","$tipo_ele","$loc_ele","$order_by","","$entries_per_page","$ip_version_ele","$show_rootnet","$show_endnet","","","$hide_not_rooted");

} else {
        print "<p class=\"NotifyText\">$$lang_vars{no_resultado_message}</p><br>\n";
}


$gip->print_end("$client_id","$vars_file","go_to_top");
