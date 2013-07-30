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
use lib '../modules';
use GestioIP;
use Net::IP;
use Net::IP qw(:PROC);
use Math::BigInt;


my $daten=<STDIN>;
my $gip = GestioIP -> new();
my %daten=$gip->preparer($daten);

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
my $ip_version = $daten{'ip_version'} || "";

my @config = $gip->get_config("$client_id");
my $smallest_bm = $config[0]->[0] || "22";
my $smallest_bm6 = $config[0]->[7] || "64";

my $red = "";
$red=$daten{'red'} if $daten{'red'};

if ( $ip_version eq "v4" && $red !~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\/\d{1,2}$/ ) {
        $gip->print_init("gestioip","$$lang_vars{split_red_message}","$$lang_vars{split_red_message}","$vars_file","$client_id");
        $gip->print_error("$client_id","$$lang_vars{formato_ip_malo_message}");
} elsif ( $ip_version eq "v6" && $red !~ /^(\w+\:\w+\:\w+\:\w+\:\w+\:\w+\:\w+\:\w+)\/\d{1,3}$/ ) {
        $gip->print_init("gestioip","$$lang_vars{split_red_message}","$$lang_vars{split_red_message}","$vars_file","$client_id");
        $gip->print_error("$client_id","$$lang_vars{formato_ip_malo_message}");
}

my ($show_rootnet, $show_endnet, $hide_not_rooted);
$show_rootnet=$gip->get_show_rootnet_val() || "1";
$show_endnet=$gip->get_show_endnet_val() || "1";
$hide_not_rooted=$gip->get_hide_not_rooted_val() || "0";

$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{split_red_message} $red","$vars_file");

$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (version_ele)") if $ip_version_ele !~ /^(v4|v6|46)$/;
$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (2)") if $ip_version !~ /^(v4|v6)$/;


my $tipo_ele = $daten{'tipo_ele'} || "NULL";
my $loc_ele = $daten{'loc_ele'} || "NULL";
my $start_entry=$daten{'start_entry'} || '0';
$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (3)") if $start_entry !~ /^\d{1,4}$/;
my $order_by=$daten{'order_by'} || "red_auf";

my $tipo_ele_id=$gip->get_cat_net_id("$client_id","$tipo_ele") || "-1";
my $loc_ele_id=$gip->get_loc_id("$client_id","$loc_ele") || "-1";


if ( ! $daten{'new_redes'} ) { $gip->print_error("$client_id","no new_redes"); }
if ( ! $daten{'red'} ) { $gip->print_error("$client_id","no red"); }
if ( $ip_version eq "v4" ) {
	if ( $daten{new_redes} !~ /^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\/\d{1,2}-)+\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\/\d{1,2}$/ ) { $gip->print_error("$client_id","$$lang_vars{formato_malo_message} (4) $daten{new_redes}") };
} else {
	if ( $daten{new_redes} !~ /^(\w+\:\w+\:\w+\:\w+\:\w+\:\w+\:\w+\:\w+\/\d{1,3}-)+\w+\:\w+\:\w+\:\w+\:\w+\:\w+\:\w+\:\w+\/\d{1,3}$/ ) { $gip->print_error("$client_id","$$lang_vars{formato_malo_message} (5) $daten{new_redes}") };
}

my $keep_hosts = "n"; 
$keep_hosts= $daten{keep_hosts} if $daten{keep_hosts};

my @new_redes=split('-',$daten{new_redes});
my $new_redes_count = @new_redes;

my @new_redes_detail;
for (my $l=0; $l <= $new_redes_count; $l++) {
	$new_redes_detail[$l]->[0] = $daten{"red_$l"};
	$new_redes_detail[$l]->[1] = $daten{"BM_$l"};
	$new_redes_detail[$l]->[2] = $daten{"descr_$l"} || "NULL";
	$new_redes_detail[$l]->[3] = $daten{"loc_$l"} || "NULL";
	$new_redes_detail[$l]->[4] = $daten{"cat_net_$l"} || "NULL";
	$new_redes_detail[$l]->[5] = $daten{"comentario_$l"} || "NULL";
	$new_redes_detail[$l]->[6] = $daten{"vigilada_$l"} || "n";
	$new_redes_detail[$l]->[6] = $ip_version;
}

my ( $red_old,$bm_old);
if ( $ip_version eq "v4" ) {
	$red =~ /^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\/(\d{1,2})$/;
	$red_old=$1;
	$bm_old=$2;
} else {
	$red =~ /^(\w+\:\w+\:\w+\:\w+\:\w+\:\w+\:\w+\:\w+)\/(\d{1,3})$/;
	$red_old=$1;
	$bm_old=$2;
}
my $ipob_old = new Net::IP ($red) or $gip->print_error("$client_id","$$lang_vars{formato_malo_message}<b>$red</b>");
my $red_old_int = ($ipob_old->intip());
$red_old_int = Math::BigInt->new("$red_old_int");
my $first_ip_old_int = $red_old_int + 1;
my $last_ip_old_int = ($ipob_old->last_int());
$last_ip_old_int = Math::BigInt->new("$last_ip_old_int");
$last_ip_old_int = $last_ip_old_int - 1;

my $red_id_old=$gip->get_red_id_from_red("$client_id","$red_old");
#my ($ip_hash,$host_sort_helper_array_ref)=$gip->get_host_hash("$client_id","$first_ip_old_int","$last_ip_old_int","IP_auf","hosts","$red_num");
my ($ip_hash,$host_sort_helper_array_ref)=$gip->get_host_hash("$client_id","$first_ip_old_int","$last_ip_old_int","IP_auf","hosts","$red_id_old");

my @values_redes = $gip->get_red("$client_id","$red_id_old");

my @linked_cc_id=$gip->get_custom_host_column_ids_from_name("$client_id","linked IP");
my $linked_cc_id=$linked_cc_id[0]->[0] || "";
my %linked_cc_values=$gip->get_linked_custom_columns_hash("$client_id","$red_id_old","$linked_cc_id","$ip_version");

my $m = "0";
my $event;
my %changed_red_num;
foreach my $ele (@new_redes_detail) {
	if ( ! $ele || ! $new_redes_detail[$m]->[0] ) { next; }

	my $red_nuevo=$new_redes_detail[$m]->[0];
	my $BM_nuevo=$new_redes_detail[$m]->[1];
	my $descr_nuevo = $new_redes_detail[$m]->[2] || "NULL";
	my $loc_nuevo = $new_redes_detail[$m]->[3] || "-1";
	my $loc_id_nuevo=$gip->get_loc_id("$client_id","$loc_nuevo") || "-1";
	my $cat_nuevo = $new_redes_detail[$m]->[4] || "-1";
	my $cat_id_nuevo=$gip->get_cat_net_id("$client_id","$cat_nuevo") || "-1";
	my $comentario_nuevo = $new_redes_detail[$m]->[5] || "NULL";
	my $vigilada_nuevo = $new_redes_detail[$m]->[6] || "n";

	my $redob = $red_nuevo . "/" . $BM_nuevo;
	my $ipob = new Net::IP ($redob) or $gip->print_error("$client_id","$$lang_vars{formato_malo_message}<b>$redob</b>");
	my $red_exists = $gip->check_red_exists("$client_id","$red_nuevo","$BM_nuevo","");
	if ( $red_exists ) {
		$gip->print_error("$client_id","$$lang_vars{red_exists_message} $redob");
	}
	my @overlap_redes=$gip->get_overlap_red("$ip_version","$client_id");
	my @overlap_found = $gip->find_overlap_redes("$client_id","$red_nuevo","$BM_nuevo",\@overlap_redes,"$ip_version","$vars_file");
	if ( $overlap_found[0] && $overlap_found[0] ne $red ) {
		$gip->print_error("$client_id","$redob $$lang_vars{overlaps_con_message} $overlap_found[0]");
	}
	my $red_id_nuevo=$gip->get_last_red_num("$client_id");
	$red_id_nuevo++;
	$gip->insert_net("$client_id","$red_id_nuevo","$red_nuevo","$BM_nuevo","$descr_nuevo","$loc_id_nuevo","$vigilada_nuevo","$comentario_nuevo","$cat_id_nuevo","$ip_version") or die $gip->print_error("$client_id","$$lang_vars{insert_net_error}");

	$changed_red_num{$red_id_nuevo}=$red_id_nuevo;

	my @rangos;
	@rangos = $gip->get_rangos_red("$client_id","$red_id_old");
	my $j = 0;
	foreach ( @rangos ) {
		$gip->delete_range("$client_id","$rangos[$j]->[0]");
		$j++;
	}

	my $first_ip_int = ($ipob->intip());
	my $last_ip_int = ($ipob->last_int());
	my $first_ip_int_update=$first_ip_int;
	my $last_ip_int_update=$last_ip_int;
#	if ( $ip_version eq "v6" ) {
#		$first_ip_int_update--;
#		$last_ip_int_update++;
#	}
	my $SMALLEST_BM;
	if ( $ip_version eq "v4" ) {
		$SMALLEST_BM="$smallest_bm" || "22";
	} else {
		$SMALLEST_BM="$smallest_bm6" || "64";
	}
	if ( $keep_hosts eq "y" && $BM_nuevo >= $SMALLEST_BM && $ip_version eq "v4" ) {
			$gip->update_host_red_id_ip_all("$client_id","$red_id_nuevo","$first_ip_int_update","$last_ip_int_update","$ip_version");

			if ( $ip_hash->{$first_ip_int}[12] && $ip_hash->{$first_ip_int}[12] =~ /\d/ ) {
				my $first_host_id = $ip_hash->{$first_ip_int}[12];
				$gip->delete_custom_host_column_entry("$client_id","$first_host_id");

				my @switches;
				my @switches_new;
				my $switch_id_hash = $ip_hash->{$first_ip_int}[12];
				@switches = $gip->get_vlan_switches_match("$client_id","$switch_id_hash");
				my $i="0";
				if (scalar(@switches) != 0) {
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


			if ( $ip_hash->{$last_ip_int}[12] && $ip_hash->{$last_ip_int}[12] =~ /\d/ ) {
				my $last_host_id = $ip_hash->{$last_ip_int}[12];
				$gip->delete_custom_host_column_entry("$client_id","$last_host_id");

				my @switches;
				my @switches_new;
				my $switch_id_hash = $ip_hash->{$last_ip_int}[12];
				@switches = $gip->get_vlan_switches_match("$client_id","$switch_id_hash");
				if (scalar(@switches) != 0) {
					foreach ( @switches ) {
						my $vlan_id = $_->[0] || "";
						my $switches = $_->[1] || "";
						$switches =~ s/,$switch_id_hash,/,/;
						$switches =~ s/^$switch_id_hash,//;
						$switches =~ s/,$switch_id_hash$//;
						$switches =~ s/^$switch_id_hash$//;
						$gip->update_vlan_switches("$client_id","$vlan_id","$switches") if $vlan_id;
					}
				}

				for ( my $i=$first_ip_int; $i <= $last_ip_int; $i++ ) {
					if ( exists $linked_cc_values{$i} ) {
						my $linked_ips_delete=$linked_cc_values{$i}[0];
						my $ip_ad=$linked_cc_values{$i}[1];
						my $host_id=$linked_cc_values{$i}[2];
						my @linked_ips=split(",",$linked_ips_delete);
						foreach my $linked_ip_delete(@linked_ips){
							$gip->delete_linked_ip("$client_id","$ip_version","$linked_ip_delete","$ip_ad");
						}
					}
				}

				$gip->delete_ip("$client_id","$last_ip_int","$last_ip_int","$ip_version");
			}
	} elsif ( $keep_hosts eq "y" && $BM_nuevo >= $SMALLEST_BM && $ip_version eq "v6" ) {
			$gip->update_host_red_id_ip_all("$client_id","$red_id_nuevo","$first_ip_int_update","$last_ip_int_update","$ip_version");
	} elsif ( $keep_hosts ne "y" ) {
		$gip->delete_custom_column_entry("$client_id","$red_id_old");
		my @switches;
		my @switches_new;

		foreach my $key ( keys %$ip_hash ) { 

			my $switch_id_hash = $ip_hash->{$key}[12];
			@switches = $gip->get_vlan_switches_match("$client_id","$switch_id_hash");
			if (scalar(@switches) != 0) {
				foreach ( @switches ) {
					my $vlan_id = $_->[0] || "";
					my $switches = $_->[1] || "";
					$switches =~ s/,$switch_id_hash,/,/;
					$switches =~ s/^$switch_id_hash,//;
					$switches =~ s/,$switch_id_hash$//;
					$switches =~ s/^$switch_id_hash$//;
					$gip->update_vlan_switches("$client_id","$vlan_id","$switches") if $vlan_id;
				}
			}

			for ( my $i=$first_ip_int; $i <= $last_ip_int; $i++ ) {
				if ( exists $linked_cc_values{$i} ) {
					my $linked_ips_delete=$linked_cc_values{$i}[0];
					my $ip_ad=$linked_cc_values{$i}[1];
					my $host_id=$linked_cc_values{$i}[2];
					my @linked_ips=split(",",$linked_ips_delete);
					foreach my $linked_ip_delete(@linked_ips){
						$gip->delete_linked_ip("$client_id","$ip_version","$linked_ip_delete","$ip_ad");
					}
				}
			}

			$gip->delete_ip("$client_id","$first_ip_int","$last_ip_int","$ip_version");
		}
	}

	#audit
	$descr_nuevo = "---" if $descr_nuevo eq "NULL";
	$loc_nuevo = "---" if $loc_nuevo eq "NULL";
	$cat_nuevo = "---" if $cat_nuevo eq "NULL";
	$comentario_nuevo = "---" if $comentario_nuevo eq "NULL";
	if ( $event ) {
		$event = "$event;$red_nuevo/$BM_nuevo,$descr_nuevo,$loc_nuevo,$cat_nuevo,$comentario_nuevo,$vigilada_nuevo" if $new_redes_detail[$m]->[0];
	} else {
		$event = "$red_nuevo/$BM_nuevo,$descr_nuevo,$loc_nuevo,$cat_nuevo,$comentario_nuevo,$vigilada_nuevo" if $new_redes_detail[$m]->[0];
	}
	$m++;
}



my $descr_old_audit = "$values_redes[0]->[2]" || "---";
$descr_old_audit = "---" if $descr_old_audit eq "NULL";
my $loc_old_audit=$gip->get_loc_from_redid("$client_id","$red_id_old");
$loc_old_audit = "---" if $loc_old_audit eq "NULL";
my $vigilada_old_audit = "$values_redes[0]->[4]" || "";
my $comentario_old_audit = "$values_redes[0]->[5]" || "---";
$comentario_old_audit = "---" if $comentario_old_audit eq "NULL";
my $cat_id_old_audit = "$values_redes[0]->[6]" || "---";
my $cat_old_audit=$gip->get_cat_net_from_id("$client_id","$cat_id_old_audit");
$cat_old_audit = "---" if $cat_old_audit eq "NULL";

$gip->delete_red("$client_id","$red_id_old");

print "<p><b>$$lang_vars{ha_dividido_message} $red $$lang_vars{en_los_redes_message}:<br><p>\n";
my $n = 0;
foreach ( @new_redes_detail ) {
        print "$new_redes_detail[$n]->[0]" . "/" . "$new_redes_detail[$n]->[1]<br>" if $new_redes_detail[$n]->[0];
        $n++;
}
print "</b>";


my $audit_type="5";
my $audit_class="2";
my $update_type_audit="1";
$event = "$red,$descr_old_audit,$loc_old_audit,$cat_old_audit,$comentario_old_audit,$vigilada_old_audit" . " -> " . $event;
$gip->insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");


my @ip=$gip->get_redes("$client_id","$tipo_ele_id","$loc_ele_id","$start_entry","$entries_per_page","$order_by","$ip_version_ele","$show_rootnet","$show_endnet","$hide_not_rooted");
my $ip=$gip->prepare_redes_array("$client_id",\@ip,"$order_by","$start_entry","$entries_per_page","$ip_version_ele");

my $anz_values_redes = scalar(@ip);
my $pages_links=$gip->get_pages_links_red("$client_id","$start_entry","$anz_values_redes","$entries_per_page","$tipo_ele","$loc_ele","red_auf","","","$show_rootnet","$show_endnet","$hide_not_rooted");

$gip->PrintRedTabHead("$client_id","$vars_file","$start_entry","$entries_per_page","$pages_links","$tipo_ele","$loc_ele","$ip_version_ele","$show_rootnet","$show_endnet","$hide_not_rooted");

if ( @ip ) {
	$gip->PrintRedTab("$client_id",$ip,"$vars_file","extended","$start_entry","$tipo_ele","$loc_ele","$order_by","","$entries_per_page","$ip_version_ele","$show_rootnet","$show_endnet",\%changed_red_num,"","$hide_not_rooted");
} else {
	print "<p class=\"NotifyText\">$$lang_vars{no_resultado_message}</p><br>\n";
}

$gip->print_end("$client_id","$vars_file","go_to_top");
