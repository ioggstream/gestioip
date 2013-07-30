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
        $gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{reservar_rango_message}","$vars_file");
        print_error("<b>ERROR</b><p>$$lang_vars{client_id_invalid_message}: $client_id","");
}

my $ip_version_ele=$gip->get_ip_version_ele() || "v4";

my $ip_version=$daten{'ip_version'} || "";
if ( $ip_version !~ /^(v4|v6)$/ ) {
        $gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{reservar_rango_message}","$vars_file");
        print_error("$client_id","$$lang_vars{formato_malo_message} (1)");
}

if ( $ip_version eq "v4" ) {
	if ( $daten{'red'} !~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\/\d{2}$/ || $daten{'adddel'} !~ /^add|del$/ ) {
		$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{reservar_rango_message}","$vars_file");
		$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (1)");
	}
} else  {
	$daten{'red'} =~ /^(\w+\:\w+\:\w+\:\w+\:\w+\:\w+\:\w+\:\w+)\//;
	my $checkred = $1;
	my $valid_v6=$gip->check_valid_ipv6("$checkred") || "0";
	if ( $valid_v6 != "1"  || $daten{'adddel'} !~ /^add|del$/ ) {
		$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{reservar_rango_message}","$vars_file");
		$gip->print_error("$client_id","$$lang_vars{no_valid_ipv6_address_message}");
	}
}


my $redob=$daten{'red'};
my $adddel=$daten{'adddel'};
$redob =~ /\/(\d{1,3}$)/;
my $BM = $1 || "";

my ($show_rootnet, $show_endnet, $hide_not_rooted);
$show_rootnet=$gip->get_show_rootnet_val() || "1";
$show_endnet=$gip->get_show_endnet_val() || "1";
$hide_not_rooted=$gip->get_hide_not_rooted_val() || "0";

$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{reservar_rango_red_message}","$vars_file");


$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (2)") if $BM !~ /^\d{1,3}$/;
$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (3)") if ($daten{'referer'} !~ /^host_list_view|red_view$/ );


my $tipo_ele = $daten{'tipo_ele'} || "NULL";
my $loc_ele = $daten{'loc_ele'} || "NULL";
my $start_entry=$daten{'start_entry'} || '0';
$gip->print_error("$client_id","$$lang_vars{formato_malo_message}") if $start_entry !~ /^\d{1,4}$/;
my $tipo_ele_id=$gip->get_cat_net_id("$client_id","$tipo_ele") || "-1";
my $loc_ele_id=$gip->get_loc_id("$client_id","$loc_ele") || "-1";
my $referer=$daten{'referer'};
my $order_by=$daten{'order_by'} || "red_auf";
my $host_order_by=$daten{'host_order_by'} || "IP_auf";

my $range=$daten{'range'};
my $range_type_id=$daten{'range_type_id'};

my $red;
if ( $ip_version eq "v4" ) {
	$redob =~ /^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\/\d{2}$/;
	$red = $1;
} else {
	$redob =~ /^(\w+\:\w+\:\w+\:\w+\:\w+\:\w+\:\w+\:\w+)\//;
	$red = $1;
}
my $red_num=$gip->get_red_id_from_red("$client_id","$red");
my $ipob_red = new Net::IP ($redob) || die "Can not create ip object $redob: $!\n";
my $redint=($ipob_red->intip());
$redint = Math::BigInt->new("$redint");
my $first_ip_int = $redint + 1;
my $broad_ip_int = ($ipob_red->last_int());
$broad_ip_int = Math::BigInt->new("$broad_ip_int");
my $last_ip_int = $broad_ip_int - 1;
my $red_loc=$gip->get_loc_from_redid("$client_id","$red_num") || "";
my $red_loc_id=$gip->get_loc_id("$client_id","$red_loc") || "-1";

if ( $adddel eq "add" ) {
	$gip->print_error("$client_id","$$lang_vars{no_rango_start_address_message}") if ( ! $daten{'reserve_start_address'} );
	if ( $ip_version eq "v4" ) {
		$gip->print_error("$client_id","$$lang_vars{formato_start_address_mala_message}") if ( $daten{'reserve_start_address'} !~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/ );
		$gip->print_error("$client_id","$$lang_vars{formato_end_address_mala_message}") if ( $daten{'reserve_end_address'} !~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/ && $ip_version eq "v4" );
	} else {
		my $valid_v6=$gip->check_valid_ipv6("$daten{'reserve_start_address'}") || "0";
		$gip->print_error("$client_id","$$lang_vars{formato_start_address_mala_message}") if ( $valid_v6 != "1" );
		$valid_v6=$gip->check_valid_ipv6("$daten{'reserve_end_address'}") || "0";
		$gip->print_error("$client_id","$$lang_vars{formato_start_address_mala_message}") if ( $valid_v6 != "1" );
	}
	$gip->print_error("$client_id","$$lang_vars{no_rango_end_address_message}") if ( ! $daten{'reserve_end_address'} );
	$gip->print_error("$client_id","$$lang_vars{no_comentario_message}") if ( ! $daten{'comentario'} );
	$gip->print_error("$client_id","$$lang_vars{palabra_reservada_range_NULL_message}") if $daten{'comentario'} eq "NULL";
	$gip->print_error("$client_id","$$lang_vars{caracter_reservada_rango_parentesis_message}") if $daten{'comentario'} =~ /\[/ || $daten{'comentario'} =~ /\]/;
	$gip->print_error("$client_id","$$lang_vars{no_range_type_message}") if ! $daten{'range_type_id'};

	my $reserve_start_address=$daten{'reserve_start_address'};
	my $reserve_end_address=$daten{'reserve_end_address'};
	my $comentario=$daten{'comentario'};
	my $range_id = $gip->get_last_range_id();

	my $ipob_reserve_start_address = new Net::IP ($reserve_start_address) or $gip->print_error("$client_id","Can not create ip object $reserve_start_address: $!");
	my $reserve_start_address_int = ($ipob_reserve_start_address->intip());
	$reserve_start_address_int = Math::BigInt->new("$reserve_start_address_int");
	my $ipob_reserve_end_address = new Net::IP ($reserve_end_address) or $gip->print_error("$client_id","Can not create ip object $reserve_end_address: $!");
	my $reserve_end_address_int=($ipob_reserve_end_address->intip());
	$reserve_end_address_int = Math::BigInt->new("$reserve_end_address_int");

	if ( $reserve_start_address_int lt $first_ip_int || $reserve_start_address_int gt $last_ip_int ) { $gip->print_error("$client_id","$$lang_vars{start_IP_out_of_range_message} $redob"); }
	if ( $reserve_end_address_int lt $first_ip_int || $reserve_end_address_int gt $last_ip_int ) { $gip->print_error("$client_id","$$lang_vars{end_IP_out_of_range_message} $redob"); }
	if ( $reserve_start_address_int ge $reserve_end_address_int ) { $gip->print_error("$client_id","$$lang_vars{end_mas_grande_message} $reserve_start_address_int ge $reserve_end_address_int"); }
	if ( $reserve_start_address_int eq $redint ) { $gip->print_error("$client_id","$$lang_vars{start_IP_net_address_message}"); }
	if ( $reserve_start_address_int eq $broad_ip_int ) { $gip->print_error("$client_id","$$lang_vars{start_IP_broad_address_message}"); }
	if ( $reserve_end_address_int eq $redint ) { $gip->print_error("$client_id","$$lang_vars{end_IP_net_address_message}"); }
	if ( $reserve_end_address_int eq $broad_ip_int ) { $gip->print_error("$client_id","$$lang_vars{end_IP_broad_address_message}"); }

	my @rangos = $gip->get_rangos("$client_id");
	if ( $rangos[0]->[0] ) {
		my $k=0;
		foreach (@rangos) {
			my $start_ip = $gip->int_to_ip("$client_id","$rangos[$k]->[1]","$ip_version");
			my $end_ip = $gip->int_to_ip("$client_id","$rangos[$k]->[2]","$ip_version");
			$rangos[$k]->[1] = Math::BigInt->new("$rangos[$k]->[1]");
			$rangos[$k]->[2] = Math::BigInt->new("$rangos[$k]->[2]");
			if ( $reserve_start_address_int >= $rangos[$k]->[1] && $reserve_start_address_int <= $rangos[$k]->[2] ) {
				$gip->print_error("$client_id","$$lang_vars{rango_overlap_message} <i>$start_ip-$end_ip ($rangos[$k]->[3])</i>");
			} elsif ( $reserve_end_address_int >= $rangos[$k]->[1] && $reserve_end_address_int <= $rangos[$k]->[2] ) {
				$gip->print_error("$client_id","$$lang_vars{rango_overlap_message} <i>$start_ip-$end_ip ( $rangos[$k]->[3])</i>");
			} elsif ( $reserve_start_address_int < $rangos[$k]->[1] && $reserve_end_address_int > $rangos[$k]->[2] ) {
				$gip->print_error("$client_id","$$lang_vars{rango_overlap_message} <i>$start_ip-$end_ip ($rangos[$k]->[3])</i>");
			}
			$k++;
		}
	}

	my $mydatetime = time();

	my $range_type=$gip->get_range_type_from_id("$client_id","$range_type_id");
	my $cat_id;
	if ( $range_type eq "workst (DHCP)" ) {
		$cat_id = $gip->get_cat_from_id("$client_id","workst") || "-1";
	} elsif ( $range_type eq "wifi (DHCP)" ) {
		$cat_id = $gip->get_cat_from_id("$client_id","wifi") || "-1";
	} elsif ( $range_type eq "VoIP (DHCP)" ) {
		$cat_id = $gip->get_cat_from_id("$client_id","VoIP") || "-1";
	} elsif ( $range_type eq "other (DHCP)" ) {
		$cat_id = $gip->get_cat_from_id("$client_id","other") || "-1";
	} elsif ( $range_type eq "other" ) {
		$cat_id = $gip->get_cat_from_id("$client_id","other") || "-1";
	} else {
		$cat_id = "-1"; #unasigned
		$range_type="---";
	}

	my @ch=$gip->get_host("$client_id","$reserve_start_address_int","$reserve_end_address_int","$red_num");
	my $j=0;
	my $new_range_id = $range_id;
	$new_range_id++;
	my $i = "";
	$i = Math::BigInt->new("$i");
	for ($i = $reserve_start_address_int; $i <= $reserve_end_address_int; $i++) {
		if ( $ch[$j]) {
			if ( $ch[$j]->[0] eq "$i" ) {
				$gip->update_range_id_host("$client_id","$new_range_id","$i","$red_loc_id","$cat_id","$mydatetime");
				$gip->delete_custom_host_column_entry("$client_id","$ch[$j]->[11]");

				my $audit_type="14";
				my $audit_class="1";
				my $update_type_audit="9";
				my $ip=$gip->int_to_ip("$client_id","$ch[$j]->[0]","$ip_version");
				my $hostname_audit = $ch[$j]->[1];
				my $descr_audit = $ch[$j]->[2] || "---";
				$descr_audit = "---" if $descr_audit eq "NULL";
				my $loc_audit = $ch[$j]->[3] || "---";
				$loc_audit = "---" if $loc_audit eq "NULL";
				my $cat_audit = $ch[$j]->[4] || "---";
				$cat_audit = "---" if $cat_audit eq "NULL";
				my $comentario_audit = $ch[$j]->[6] || "---";
				$comentario_audit = "---" if $comentario_audit eq "NULL";
				my $int_admin_audit = $ch[$j]->[5] || "n";
				my $event="$ip,$hostname_audit,$descr_audit,$loc_audit,$cat_audit,$comentario_audit,$int_admin_audit";
				$gip->insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");

				$audit_type="28";
				$audit_class="1";
				$update_type_audit="9";
				my $red_loc_audit = $red_loc;
				$red_loc_audit = "---" if $red_loc eq "NULL";
				$event="$ip,---,---,$red_loc_audit,$range_type,[$comentario],n";
				$gip->insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");
				$j++;
			} else {
				$gip->insert_range_id_host("$client_id","$new_range_id","$i","$red_loc_id","$cat_id",'-1',"$mydatetime","$red_num","$ip_version");

				my $audit_type="28";
				my $audit_class="1";
				my $update_type_audit="9";
				my $ip=$gip->int_to_ip("$client_id","$ch[$j]->[0]","$ip_version");
				my $red_loc_audit = $red_loc;
				$red_loc_audit = "---" if $red_loc eq "NULL";
				my $event="$ip,---,---,$red_loc_audit,$range_type,[$comentario],n";
				$gip->insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");
			}
		} else {
			$gip->insert_range_id_host("$client_id","$new_range_id","$i","$red_loc_id","$cat_id",'-1',"$mydatetime","$red_num","$ip_version");
			my $audit_type="28";
			my $audit_class="1";
			my $update_type_audit="9";
			my $ip=$gip->int_to_ip("$client_id","$i","$ip_version");
			my $red_loc_audit = $red_loc;
			$red_loc_audit = "---" if $red_loc eq "NULL";
			my $event="$ip,---,---,$red_loc_audit,$range_type,[$comentario],n";
			$gip->insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");
		}
	}

	$gip->insert_range("$client_id","$comentario","$reserve_start_address_int","$reserve_end_address_int","$red_num","$range_type_id","$vars_file");

	my $audit_type="19";
	my $audit_class="2";
	my $update_type_audit="9";
	my $event="$redob: $reserve_start_address-$reserve_end_address $comentario - $range_type";
	$gip->insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");

	print "<p><b>$$lang_vars{rango_added_message}: <i>$reserve_start_address-$reserve_end_address ($comentario)</i></b><br>\n";

} elsif ( $adddel eq "del" ) {

	my $range_id = $daten{'range_id'};
	$gip->print_error("$client_id","$$lang_vars{formato_malo_message}") if ( $daten{'range_id'} !~ /^\d{1,3}$/ );

	my @rangos = $gip->get_rango("$client_id","$range_id");
	$gip->print_error("$client_id","$$lang_vars{range_no_exists_message}") if ! $rangos[0]->[0];
	my $start_ip_int=$rangos[0]->[0];
	$start_ip_int = Math::BigInt->new("$start_ip_int");
	my $end_ip_int=$rangos[0]->[1];
	$end_ip_int = Math::BigInt->new("$end_ip_int");

	my $audit_type="18";
	my $audit_class="2";
	my $update_type_audit="9";
	my $start_ip_audit = $gip->int_to_ip("$client_id","$start_ip_int","$ip_version");
	my $end_ip_audit = $gip->int_to_ip("$client_id","$end_ip_int","$ip_version");
	my $event="$redob: " . $start_ip_audit . "-" . $end_ip_audit . " " . $rangos[0]->[2];
	$gip->insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");

	my @ch=$gip->get_host("$client_id","$start_ip_int","$end_ip_int","$red_num");
	
	my $j = 0;
	my $i = "";
	for ($i = $start_ip_int; $i <= $end_ip_int; $i++) {
		$i = Math::BigInt->new("$i");
		if ( $ch[$j]->[1] ) {
			$gip->delete_custom_host_column_entry("$client_id","$ch[$j]->[11]");
			my $ip=$gip->int_to_ip("$client_id","$i","$ip_version");
			$ch[$j]->[1] = "---" if ! $ch[$j]->[1]; #hostname
			$ch[$j]->[1] = "---" if $ch[$j]->[1] eq "NULL";
			$ch[$j]->[2] = "---" if ! $ch[$j]->[2]; #host_descr
			$ch[$j]->[2] = "---" if $ch[$j]->[2] eq "NULL";
			$ch[$j]->[3] = "---" if $ch[$j]->[3] eq "NULL" || $ch[$j]->[3] eq "-1";
			$ch[$j]->[4] = "---" if $ch[$j]->[4] eq "NULL" || $ch[$j]->[4] eq "-1";
			$ch[$j]->[6] = "---" if ! $ch[$j]->[6]; # comentario
			$ch[$j]->[6] = "---" if $ch[$j]->[6] eq "NULL";
			$ch[$j]->[7] = "---" if ! $ch[$j]->[7];
			$ch[$j]->[7] = "---" if $ch[$j]->[7] eq "NULL" || $ch[$j]->[7] eq "-1";

			$audit_type="14";
			$audit_class="1";
			$update_type_audit="9";

			$event="$ip: $ch[$j]->[1],$ch[$j]->[2],$ch[$j]->[3],$ch[$j]->[4],$ch[$j]->[5],$ch[$j]->[6],$ch[$j]->[7]";
			$gip->insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");
		}
		$j++;
	}
	$gip->delete_range("$client_id","$range_id");
	print "<p><b>$$lang_vars{rango_borrado_message}: <i>$start_ip_audit-$end_ip_audit ($rangos[0]->[2])</i></b><br>\n";
} else {
	$gip->print_error("$client_id","$$lang_vars{formato_malo_message}");
}

if ( $referer eq "host_list_view"  ) {

	my ($start_entry_hosts,$entries_per_page_hosts);
	if ( $daten{'entries_per_page_hosts'} && $daten{'entries_per_page_hosts'} =~ /^\d{1,4}$/ ) {
		$entries_per_page_hosts=$daten{'entries_per_page_hosts'};
	} else {
		$entries_per_page_hosts = "254";
	}

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


	if ( defined($daten{'text_field_number_given'}) ) {
		$start_entry_hosts=$daten{'start_entry_hosts'} * $entries_per_page_hosts - $entries_per_page_hosts;
		$start_entry_hosts = 0 if $start_entry_hosts < 0;
	} else {
		$start_entry_hosts=$daten{'start_entry_hosts'} || '0';
	}
	$start_entry_hosts = Math::BigInt->new("$start_entry_hosts");


	my $knownhosts="all";

	my $anz_host_total=$gip->get_host_hash_count("$client_id","$red_num") || "0";

	my %anz_hosts_bm = $gip->get_anz_hosts_bm_hash("$client_id","$ip_version");
	my $anz_values_hosts_pages = $anz_hosts_bm{$BM};
	$anz_values_hosts_pages = Math::BigInt->new("$anz_values_hosts_pages");
	my $anz_values_hosts=$daten{'anz_values_hosts'} || $anz_hosts_bm{$BM};
	$anz_values_hosts = Math::BigInt->new("$anz_values_hosts");

	if ( $host_order_by =~ /IP/ ) {
		$anz_values_hosts=$entries_per_page_hosts;
		$anz_values_hosts_pages=$anz_hosts_bm{$BM};
	} else {
		$anz_values_hosts=$anz_host_total;
		$anz_values_hosts_pages=$anz_host_total;
	}

	$anz_values_hosts_pages =~ s/,//g;

	if ( $start_entry_hosts >= $anz_values_hosts_pages ) {
		$start_entry_hosts=$anz_values_hosts_pages/$entries_per_page_hosts;
		$start_entry_hosts=floor("$start_entry_hosts");
		$start_entry_hosts*= $entries_per_page_hosts;
	}

	$gip->print_error("$client_id","$$lang_vars{formato_malo_message}") if $daten{'start_entry_hosts'} && $daten{'start_entry_hosts'} !~ /^\d{1,20}$/;


	my ($host_hash_ref,$host_sort_helper_array_ref)=$gip->get_host_hash("$client_id","$first_ip_int","$last_ip_int","$host_order_by","$knownhosts","$red_num");
	($host_hash_ref,$first_ip_int,$last_ip_int)=$gip->prepare_host_hash("$client_id",$host_hash_ref,"$first_ip_int","$last_ip_int","res/ip_modip_form.cgi","$knownhosts","$$lang_vars{modificar_message}","$red_num","$red_loc","$vars_file","$anz_values_hosts","$start_entry_hosts","$entries_per_page_hosts","$host_order_by","$broad_ip_int","$ip_version");

my $pages_links=$gip->get_pages_links_host("$client_id","$start_entry_hosts","$anz_values_hosts_pages","$entries_per_page_hosts","$red_num","$knownhosts","$host_order_by","$first_ip_int",$host_hash_ref,"$broad_ip_int","$ip_version","$vars_file");

	$gip->PrintIpTabHead("$client_id","$knownhosts","res/ip_modip_form.cgi","$red_num","$vars_file","$start_entry_hosts","$anz_values_hosts","$entries_per_page_hosts","$pages_links","$host_order_by","$ip_version");

	$gip->PrintIpTab("$client_id",$host_hash_ref,"$first_ip_int","$last_ip_int","res/ip_modip_form.cgi","$knownhosts","$$lang_vars{modificar_message}","$red_num","$red_loc","$vars_file","$anz_values_hosts_pages","$start_entry_hosts","$entries_per_page_hosts","$host_order_by",$host_sort_helper_array_ref,"","$ip_version");

} else {
	my @ip=$gip->get_redes("$client_id","$tipo_ele_id","$loc_ele_id","$start_entry","$entries_per_page","$order_by","$ip_version_ele");
	my $anz_values_redes = scalar(@ip);

	my $pages_links=$gip->get_pages_links_red("$client_id","$start_entry","$anz_values_redes","$entries_per_page","$tipo_ele","$loc_ele","$order_by","","","$show_rootnet","$show_endnet","$hide_not_rooted");
	my $ip=$gip->prepare_redes_array("$client_id",\@ip,"$order_by","$start_entry","$entries_per_page","$ip_version_ele");

	$gip->PrintRedTabHead("$client_id","$vars_file","$start_entry","$entries_per_page","$pages_links","$tipo_ele","$loc_ele","$ip_version_ele","$show_rootnet","$show_endnet","$hide_not_rooted");
	$gip->PrintRedTab("$client_id",$ip,"$vars_file","extended","$start_entry","$tipo_ele","$loc_ele","$order_by","","$entries_per_page","$ip_version_ele","$show_rootnet","$show_endnet","","","$hide_not_rooted");
}

$gip->print_end("$client_id","$vars_file","go_to_top");
