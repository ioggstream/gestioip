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
use POSIX;


my $daten=<STDIN>;
my $gip = GestioIP -> new();
my %daten=$gip->preparer("$daten");

my $lang = $daten{'lang'} || "";
my ($lang_vars,$vars_file,$entries_per_page_hosts);
($lang_vars,$vars_file)=$gip->get_lang("","$lang");
if ( $daten{'entries_per_page_hosts'} && $daten{'entries_per_page_hosts'} =~ /^\d{1,4}$/ ) {
        $entries_per_page_hosts=$daten{'entries_per_page_hosts'};
} else {
        $entries_per_page_hosts = "254";
}

my $client_id = $daten{'client_id'} || $gip->get_first_client_id();
if ( $client_id !~ /^\d{1,4}$/ ) {
        $client_id = 1;
        $gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{borrar_host_message}","$vars_file");
        $gip->print_error("$client_id","$$lang_vars{client_id_invalid_message}");
}
if ( $daten{'red_num'} !~ /^\d{1,6}$/ ) {
	$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{hosts_deleted_message}","$vars_file");
	$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (2)");
}

my $ip_version=$daten{'ip_version'};
my $anz_hosts=$daten{'anz_hosts'} || "0";
	
my ($ip_int, $ip_ad);
my $red_num=$daten{'red_num'};
#my $mass_update_host_ips;
my @mass_update_host_ips=();
my @mass_update_host_ips_int=();
my %mass_update_host_ips_int=();

my $search_index=$daten{'search_index'} || "false";

if ( ! $daten{'mass_submit'} ) {

	if ( $daten{'ip_int'} !~ /^\d{8,40}$/ ) {
		$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{borrar_host_message}","$vars_file");
		$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (1)");
	}
	$ip_int=$daten{'ip_int'};
	$ip_ad=$gip->int_to_ip("$client_id","$ip_int","$ip_version");
	$mass_update_host_ips_int[0]=$daten{'ip_int'};
} else {
	my $k;
	my $j=0;
	my $mass_update_host_ips_int="";
	for ($k=0;$k<=$anz_hosts;$k++) {
		if ( $daten{"mass_update_host_submit_${k}"} ) {
#			$mass_update_host_ips.=$daten{"mass_update_host_submit_${k}"} . "_";
			$mass_update_host_ips[$j]=$daten{"mass_update_host_submit_${k}"};
			$j++;
		}
	}
	$j=0;
	foreach (@mass_update_host_ips) {
		$mass_update_host_ips_int[$j++]=$gip->ip_to_int("$client_id","$_","$ip_version");
	}
		 
	$mass_update_host_ips_int =~ s/_$//;
}

my @values_redes = $gip->get_red("$client_id","$red_num");

my $red = "$values_redes[0]->[0]" || "";
my $BM = "$values_redes[0]->[1]" || "";
my $descr = "$values_redes[0]->[2]" || "";
my $knownhosts = $daten{'knownhosts'} || "all";
my $host_order_by = $daten{'host_order_by'} || "IP_auf";

my $checki_message;
if ( ! $daten{'mass_submit'} ) {
	$checki_message=$$lang_vars{borrar_host_done_message};
} else {
	$checki_message=$$lang_vars{hosts_deleted_message};
}

$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$checki_message","$vars_file");

my $utype = $daten{'update_type'};

my $start_entry_hosts;
if ( defined($daten{'start_entry_hosts'}) ) {
        $daten{'start_entry_hosts'} = 0 if $daten{'start_entry_hosts'} !~ /^\d{1,35}$/;
}

if ( defined($daten{'text_field_number_given'}) ) {
        $start_entry_hosts=$daten{'start_entry_hosts'} * $entries_per_page_hosts - $entries_per_page_hosts;
        $start_entry_hosts = 0 if $start_entry_hosts < 0;
} else {
        $start_entry_hosts=$daten{'start_entry_hosts'} || '0';
}
$start_entry_hosts = Math::BigInt->new("$start_entry_hosts");


$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (3)") if $daten{'anz_values_hosts'} && $daten{'anz_values_hosts'} !~ /^\d{2,4}||no_value$/;
$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (4)") if $daten{'knownhosts'} && $daten{'knownhosts'} !~ /^all|hosts|libre$/;
$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (5)") if $daten{'start_entry_hosts'} && $daten{'start_entry_hosts'} !~ /^\d{1,20}$/;
$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (6)") if $ip_version !~ /^(v4|v6)$/;


my ( $first_ip_int, $last_ip_int, $last_ip_int_red, $start_entry);

my $redob = "$red/$BM";
my $ipob = new Net::IP ($redob) || $gip->print_error("$client_id","Can't create ip object: $!\n");
my $redint=($ipob->intip());
$redint = Math::BigInt->new("$redint");
my $redbroad_int=($ipob->last_int());
$first_ip_int = $redint + 1;
my $start_ip_int=$first_ip_int;
$last_ip_int = ($ipob->last_int());
$last_ip_int = Math::BigInt->new("$last_ip_int");
$last_ip_int = $last_ip_int - 1;
$last_ip_int_red=$last_ip_int;



my %cc_value = ();
my @custom_columns = $gip->get_custom_host_columns("$client_id");
my @linked_cc_id=$gip->get_custom_host_column_ids_from_name("$client_id","linked IP");
my $linked_cc_id=$linked_cc_id[0]->[0] || "0";

my ($ip_hash,$host_sort_helper_array_ref_ip);
if ( $search_index ne "true" ) {
	($ip_hash,$host_sort_helper_array_ref_ip)=$gip->get_host_hash("$client_id","$first_ip_int","$last_ip_int","IP_auf","$knownhosts","$red_num");
} else {
	($ip_hash,$host_sort_helper_array_ref_ip)=$gip->search_db_hash("$client_id","$vars_file",\%daten);
}


foreach $ip_int( @mass_update_host_ips_int ) {

	next if ! defined($ip_hash->{$ip_int}[11]);


	$ip_ad=$ip_hash->{$ip_int}[0];
	my $host_id = $ip_hash->{$ip_int}[12];

	my $range_comentario=$gip->get_rango_comentario_host("$client_id","$ip_int");
	if ( $range_comentario ) {
		$gip->clear_ip("$client_id","$ip_int","$ip_int","$ip_version");
	} else {
		$gip->delete_ip("$client_id","$ip_int","$ip_int","$ip_version");
	}

	%cc_value=$gip->get_custom_host_columns_from_net_id_hash("$client_id","$host_id") if $host_id;

	my $audit_entry_cc="";

	if ( $custom_columns[0] ) {

		my $n=0;
		foreach my $cc_ele(@custom_columns) {
			my $cc_name = $custom_columns[$n]->[0];
			my $pc_id = $custom_columns[$n]->[3];
			my $cc_id = $custom_columns[$n]->[1];
			my $cc_entry = $cc_value{$cc_id}[1] || "";

			if ( $cc_id == $linked_cc_id ) {
				my $linked_ips=$cc_entry;
				my @linked_ips=split(",",$linked_ips);
				foreach my $linked_ip_delete(@linked_ips){
					$gip->delete_linked_ip("$client_id","$ip_version","$linked_ip_delete","$ip_ad");
				}
			}

			if ( $cc_entry ) {
				if ( $audit_entry_cc ) {
					$audit_entry_cc = $audit_entry_cc . "," . $cc_entry;
				} else {
					$audit_entry_cc = $cc_entry;
				}
			}
			$n++;
		}
	}


	$gip->delete_custom_host_column_entry("$client_id","$host_id");


	my @switches;
	my @switches_new;

	if ( $ip_hash->{$ip_int}[12] ) {
		my $switch_id_hash = $ip_hash->{$ip_int}[12];
		@switches = $gip->get_vlan_switches_match("$client_id","$switch_id_hash");
		my $i = 0;
		if (scalar(@switches) == 0) {
			foreach ( @switches ) {
				my $vlan_id = $_[0];
				my $switches = $_[1];
				$switches =~ s/,$switch_id_hash,/,/;
				$switches =~ s/^$switch_id_hash,//;
				$switches =~ s/,$switch_id_hash$//;
				$switches =~ s/^$switch_id_hash$//;
				$switches_new[$i]->[0]=$vlan_id;
				$switches_new[$i]->[1]=$switches;
				$i++;
			}

			foreach ( @switches_new ) {
				my $vlan_id_new = $_[0];
				my $switches_new = $_[1];
				$gip->update_vlan_switches("$client_id","$vlan_id_new","$switches_new");
			}
		}
	}



	my $audit_type="14";
	my $audit_class="1";
	my $update_type_audit="1";

	$ip_hash->{$ip_int}[2] = "---" if ! $ip_hash->{$ip_int}[2] || $ip_hash->{$ip_int}[2] eq "NULL";
	$ip_hash->{$ip_int}[3] = "---" if ! $ip_hash->{$ip_int}[3] || $ip_hash->{$ip_int}[3] eq "NULL";
	$ip_hash->{$ip_int}[4] = "---" if ! $ip_hash->{$ip_int}[4] || $ip_hash->{$ip_int}[4] eq "NULL";
	$ip_hash->{$ip_int}[5] = "---" if ! $ip_hash->{$ip_int}[5] || $ip_hash->{$ip_int}[5] eq "NULL";
	$ip_hash->{$ip_int}[6] = "---" if ! $ip_hash->{$ip_int}[6] || $ip_hash->{$ip_int}[6] eq "NULL";
	$ip_hash->{$ip_int}[7] = "---" if ! $ip_hash->{$ip_int}[7] || $ip_hash->{$ip_int}[7] eq "NULL";

	my $event="$ip_ad,$ip_hash->{$ip_int}[1],$ip_hash->{$ip_int}[2],$ip_hash->{$ip_int}[3],$ip_hash->{$ip_int}[4],$ip_hash->{$ip_int}[5],$ip_hash->{$ip_int}[6],$ip_hash->{$ip_int}[7],$audit_entry_cc ";
	$gip->insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");
}


my $red_loc = $gip->get_loc_from_redid("$client_id","$red_num");

my ($host_hash_ref,$host_sort_helper_array_ref);
if ( $search_index ne "true" ) {
	($host_hash_ref,$host_sort_helper_array_ref)=$gip->get_host_hash("$client_id","$first_ip_int","$last_ip_int","IP_auf","$knownhosts","$red_num");
} else {
	($host_hash_ref,$host_sort_helper_array_ref)=$gip->search_db_hash("$client_id","$vars_file",\%daten);
}


my $anz_host_total;
if ( $search_index ne "true" ) {
	$anz_host_total=$gip->get_host_hash_count("$client_id","$red_num") || "0";
} else {
	$anz_host_total=scalar keys %$ip_hash;
}

if ( $anz_host_total >= $entries_per_page_hosts ) {
        my $last_ip_int_new = $first_ip_int + $start_entry_hosts + $entries_per_page_hosts - 1;
        $last_ip_int = $last_ip_int_new if $last_ip_int_new < $last_ip_int;
} else {
        $last_ip_int = ($ipob->last_int());
        $last_ip_int = $last_ip_int - 1;
}


my %anz_hosts_bm = $gip->get_anz_hosts_bm_hash("$client_id","$ip_version");
my $anz_values_hosts_pages = $anz_hosts_bm{$BM};
$anz_values_hosts_pages =~ s/,//g;

my $anz_values_hosts=$daten{'anz_values_hosts'} || $entries_per_page_hosts;
$anz_values_hosts =~ s/,//g; 
$anz_values_hosts = Math::BigInt->new("$anz_values_hosts");
$anz_values_hosts_pages = Math::BigInt->new("$anz_values_hosts_pages");


$anz_hosts_bm{$BM} =~ s/,//g;
if ( $knownhosts eq "hosts" ) {
	if ( $entries_per_page_hosts > $anz_values_hosts_pages ) {
		$anz_values_hosts=$anz_hosts_bm{$BM};
		$anz_values_hosts_pages=$anz_host_total;
	} else {
		$anz_values_hosts=$entries_per_page_hosts;
		$anz_values_hosts_pages=$anz_host_total;
	}

} elsif ( $knownhosts =~ /libre/ ) { 
		
		$anz_values_hosts_pages=$anz_hosts_bm{$BM}-$anz_host_total;

} elsif ( $host_order_by =~ /IP/ ) { 
	$anz_values_hosts=$entries_per_page_hosts;
	$anz_values_hosts_pages=$anz_hosts_bm{$BM};
} else {
	$anz_values_hosts=$anz_host_total;
	$anz_values_hosts_pages=$anz_host_total;
}


$anz_values_hosts_pages = Math::BigInt->new("$anz_values_hosts_pages");

my $go_to_address=$daten{'go_to_address'} || "";
my $go_to_address_int="";
if ( $go_to_address ) {
	$go_to_address =~ s/\s|\t//g;
	if ( $ip_version eq "v6" ) {
		my $valid_v6 = $gip->check_valid_ipv6("$go_to_address") || "0";
		if ( $valid_v6 != "1" ) { 
			$gip->print_error("$client_id","$$lang_vars{no_valid_ipv6_address_message} <b>$go_to_address</b>");
		}
	} else {
		if ( $go_to_address !~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/ ) { $gip->print_error("$client_id","$$lang_vars{formato_ip_malo_message}") };
	}
	$go_to_address_int = $gip->ip_to_int("$client_id","$go_to_address","$ip_version");
	$go_to_address_int = Math::BigInt->new("$go_to_address_int");
	if ( $ip_version eq "v4" ) {
		if ( $go_to_address_int < $first_ip_int || $go_to_address_int > $last_ip_int_red ) {
			$gip->print_error("$client_id","<b>$go_to_address</b>: $$lang_vars{no_net_address_message}");
		}
	} else {
		if ( $go_to_address_int < $first_ip_int - 1 || $go_to_address_int > $last_ip_int_red + 1 ) {
			$gip->print_error("$client_id","<b>$go_to_address</b>: $$lang_vars{no_net_address_message}");
		}
	}
	my $add_dif;
	
	if ( $knownhosts !~ /hosts/ ) { 
		$add_dif = $go_to_address_int-$start_ip_int;
		$add_dif = Math::BigInt->new("$add_dif");
		$entries_per_page_hosts = Math::BigInt->new("$entries_per_page_hosts");
		$start_entry_hosts=$add_dif/$entries_per_page_hosts;
		$start_entry_hosts=int($start_entry_hosts + 0.5);
		$start_entry_hosts*= $entries_per_page_hosts;
	} else {
		my $entry_number;
		my $u=0;
		my @hostnames=$gip->get_red_hostnames("$client_id","$red_num");
		my $go_to_address_int=$gip->ip_to_int("$client_id","$go_to_address",'v6');
		foreach (@hostnames) {
			last if $_->[0] =~ /($go_to_address_int)/;
			$u++;
		}
		$entry_number = $u;
		my $anz_values_hosts_total=$gip->count_host_entries("$client_id","$red_num");
		$start_entry_hosts=$entry_number/$entries_per_page_hosts;
		$start_entry_hosts=int($start_entry_hosts + 0.5);
		$start_entry_hosts*= $entries_per_page_hosts;
	}
}


$start_entry_hosts = Math::BigInt->new("$start_entry_hosts");

my $pages_links;

if ( $search_index ne "true" ) {
	($host_hash_ref,$first_ip_int,$last_ip_int)=$gip->prepare_host_hash("$client_id",$host_hash_ref,"$first_ip_int","$last_ip_int","res/ip_modip_form.cgi","$knownhosts","$$lang_vars{modificar_message}","$red_num","$red_loc","$vars_file","$anz_values_hosts","$start_entry_hosts","$entries_per_page_hosts","$host_order_by","$redbroad_int","$ip_version");
	$pages_links=$gip->get_pages_links_host("$client_id","$start_entry_hosts","$anz_values_hosts_pages","$entries_per_page_hosts","$red_num","$knownhosts","$host_order_by","$start_ip_int",$host_hash_ref,"$redbroad_int","$ip_version","$vars_file");
	$gip->PrintIpTabHead("$client_id","$knownhosts","res/ip_modip_form.cgi","$red_num","$vars_file","$start_entry_hosts","$anz_values_hosts","$entries_per_page_hosts","$pages_links","$host_order_by","$ip_version");

	$gip->PrintIpTab("$client_id",$host_hash_ref,"$first_ip_int","$last_ip_int","res/ip_modip_form.cgi","$knownhosts","$$lang_vars{modificar_message}","$red_num","$red_loc","$vars_file","$anz_values_hosts_pages","$start_entry_hosts","$entries_per_page_hosts","$host_order_by",$host_sort_helper_array_ref,"","$ip_version","","","");
} else {
	my $anz_host_rest=scalar keys %$host_hash_ref;
	if ( $anz_host_rest < 1 ) {
		print "<p class=\"NotifyText\">$$lang_vars{hosts_deleted_message}</p><br>\n";
#		print "<p class=\"NotifyText\">$$lang_vars{no_resultado_message}</p><br>\n";
		$gip->print_end("$client_id","$vars_file","go_to_top");
	} else {

		$gip->PrintIpTab("$client_id",$host_hash_ref,"$first_ip_int","$last_ip_int","res/ip_modip_form.cgi","$knownhosts","$$lang_vars{modificar_message}","$red_num","$red_loc","$vars_file","$anz_values_hosts_pages","$start_entry_hosts","$entries_per_page_hosts","$host_order_by",$host_sort_helper_array_ref,"","$ip_version","","","");
	}
}



$gip->print_end("$client_id","$vars_file");
