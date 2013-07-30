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
use Net::IP;
use Net::IP qw(:PROC);
use lib './modules';
use GestioIP;
use Math::BigInt;
use POSIX;

my $daten=<STDIN>;
my $gip = GestioIP -> new();
my %daten=$gip->preparer("$daten") if $daten;

my ($lang_vars,$vars_file,$entries_per_page_hosts);


my $lang = $daten{'lang'} || "";
($lang_vars,$vars_file)=$gip->get_lang("","$lang");

if ( $daten{'entries_per_page_hosts'} && $daten{'entries_per_page_hosts'} =~ /^\d{1,4}$/ ) {
	$entries_per_page_hosts=$daten{'entries_per_page_hosts'};	
} else {
	$entries_per_page_hosts = "254";
}

my $client_id = $daten{'client_id'} || $gip->get_first_client_id();
my $ip_version = $daten{'ip_version'};

my $red_num = "";
$red_num=$daten{'red_num'} if $daten{'red_num'};

if ( $red_num !~ /^\d{1,5}$/ ) {
	$gip->print_init("gestioip","$$lang_vars{redes_message}","$$lang_vars{redes_message}","$vars_file","$client_id");
	$gip->print_error("$client_id","$$lang_vars{formato_red_malo_message}") ;
}

my $host_order_by = $daten{'host_order_by'} || "IP_auf";

my $start_entry_hosts;
if ( defined($daten{'start_entry_hosts'}) ) {
	$daten{'start_entry_hosts'} = 0 if $daten{'start_entry_hosts'} !~ /^\d{1,35}$/;
}

$start_entry_hosts=$daten{'start_entry_hosts'} || '0';
$start_entry_hosts = Math::BigInt->new("$start_entry_hosts");

if ( defined($daten{'text_field_number_given'}) ) {
	$start_entry_hosts=$start_entry_hosts * $entries_per_page_hosts - $entries_per_page_hosts;
	$start_entry_hosts = 0 if $start_entry_hosts < 0;
}

my @values_redes = $gip->get_red("$client_id","$red_num");

my $red = "$values_redes[0]->[0]" || "";
my $BM = "$values_redes[0]->[1]" || "";
my $descr = "$values_redes[0]->[2]" || "";
my $cat_id = "$values_redes[0]->[6]" || "";
my $cat = $gip->get_cat_net_from_id("$client_id","$cat_id");
$cat = "NULL" if ! $cat;
$cat = "$cat - " || "";
$cat = "" if ( $cat =~ /NULL\s-\s/ );
$descr = "---" if ( $descr eq "NULL" );
my ($red_compressed1, $redob);
if ( $ip_version eq "v4" ) {
	$redob="$red/$BM";
} else {
	$red_compressed1=ip_compress_address ($red, 6) if $ip_version eq "v6";
	$redob = "$red_compressed1/$BM" ;
}

my $descr_orig=$descr;
$descr =~ s/^((\xC2\xA1|\xC2\xA2|\xC2\xA3|\xC2\xA4|\xC2\xA5|\xC2\xA6|\xC2\xA7|\xC2\xA8|\xC2\xA9|\xC2\xAA|\xC2\xAB|\xC2|\xC2\xAD|\xC2\xAE|\xC2\xAF|\xC2\xB0|\xC2\xB1|\xC2\xB2|\xC2\xB3|\xC2\xB4|\xC2\xB5|\xC2\xB6|\xC2\xB7|\xC2\xB8|\xC2\xB9|\xC2\xBA|\xC2\xBB|\xC2\xBC|\xC2\xBD|\xC2\xBE|\xC2\xBF|\xC3\x80|\xC3\x81|\xC3\x82|\xC3\x83|\xC3\x84|\xC3\x85|\xC3\x86|\xC3\x87|\xC3\x88|\xC3\x89|\xC3\x8A|\xC3\x8B|\xC3\x8C|\xC3\x8D|\xC3\x8E|\xC3\x8F|\xC3\x90|\xC3\x91|\xC3\x92|\xC3\x93|\xC3\x94|\xC3\x95|\xC3\x96|\xC3\x97|\xC3\x98|\xC3\x99|\xC3\x9A|\xC3\x9B|\xC3\x9C|\xC3\x9D|\xC3\x9E|\xC3\x9F|\xC3\xA0|\xC3\xA1|\xC3\xA2|\xC3\xA3|\xC3\xA4|\xC3\xA5|\xC3\xA6|\xC3\xA7|\xC3\xA8|\xC3\xA9|\xC3\xAA|\xC3\xAB|\xC3\xAC|\xC3\xAD|\xC3\xAE|\xC3\xAF|\xC3\xB0|\xC3\xB1|\xC3\xB2|\xC3\xB3|\xC3\xB4|\xC3\xB5|\xC3\xB6|\xC3\xB7|\xC3\xB8|\xC3\xB9|\xC3\xBA|\xC3\xBB|\xC3\xBC|\xC3\xBD|\xC3\xBE|\xC3\xBF|\xe2\x82\xac|\xc5\x92|\xc5\x93|\xc5\xa0|\xc5\xa1|\xc5\xb8|\xc6\x92|\w|\?|_|\.|,|:|\-|\@|\(|\/|\[|\]|{|}|\||~|\+|\n|\r|\f|\t|\s){12})(.*)/$1/;
$descr = "$descr" . "..." if $2;

my ( $first_ip_int, $last_ip_int, $last_ip_int_red, $start_entry);

my $align="align=\"right\"";
my $align1="";
my $ori="left";
if ( $vars_file =~ /vars_he$/ ) {
	$align="align=\"left\"";
	$align1="align=\"right\"";
	$ori="right";
}


my $check_input_message="";
if ( $lang_vars =~ /vars_he$/ ) {
	$check_input_message="<span title=\"$descr_orig\" style=\"float: $ori\">$descr $cat - $redob</span>";	
} else {
	$check_input_message="<span title=\"$descr_orig\" style=\"float: $ori\">$redob - $cat $descr</span>";	
}

$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$check_input_message","$vars_file");

my $ipob = new Net::IP ($redob) || $gip->print_error("$client_id","Can't create ip object: $! $redob\n");
my $redint=($ipob->intip());
my $redbroad_int=($ipob->last_int());
$redint = Math::BigInt->new("$redint");
$first_ip_int = $redint + 1;
my $start_ip_int=$first_ip_int;
$last_ip_int = ($ipob->last_int());
$last_ip_int = Math::BigInt->new("$last_ip_int");
$last_ip_int = $last_ip_int - 1;
$last_ip_int_red=$last_ip_int;


my $knownhosts = $daten{'knownhosts'} || "all";

my @values_categorias=$gip->get_cat("$client_id");

my $red_compressed=$red;
$red_compressed=ip_compress_address ($red, 6) if $ip_version eq "v6";

$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (1) $ip_version") if $ip_version !~ /^(v4|v6)$/;

my $red_loc = $gip->get_loc_from_redid("$client_id","$red_num");
my ( $mask_bin,$mask );
if ( $ip_version eq "v4" ) {
	$mask_bin = ip_get_mask ($BM,4);
	$mask = ip_bintoip ($mask_bin,4);
} else {
	$mask_bin = ip_get_mask ($BM,6);
	$mask = ip_bintoip ($mask_bin,6);
}



my ($host_hash_ref,$host_sort_helper_array_ref);
($host_hash_ref,$host_sort_helper_array_ref)=$gip->get_host_hash("$client_id","$first_ip_int","$last_ip_int","$host_order_by","$knownhosts","$red_num");

my $anz_host_total=$gip->get_host_hash_count("$client_id","$red_num") || "0";


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
#$gip->print_error("$client_id","$$lang_vars{max_signos_message} $go_to_address") if $go_to_address !~ /^.{1,100}$/;
my $go_to_address_int="";
my $go_to_host="";
if ( $ip_version eq "v6" ) {
	my $valid_v6 = $gip->check_valid_ipv6("$go_to_address") || "0";
	if ( $valid_v6 != "1" ) { 
		$go_to_host=$go_to_address;
	}
} else {
	if ( $go_to_address !~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/ ) {
		$go_to_host=$go_to_address;
	}
}
if ( $go_to_host ) {
	$go_to_address_int=$gip->get_host_ip_int_from_hostname("$client_id","$go_to_host");
	$gip->print_error("$client_id","$$lang_vars{ip_and_host_not_found_message}: $go_to_host") if ! $go_to_address_int;
	$go_to_address = $gip->int_to_ip("$client_id","$go_to_address_int","$ip_version");
}
	
if ( $go_to_address ) {
	$go_to_address =~ s/\s|\t//g;
	if ( $ip_version eq "v6" ) {
#		my $valid_v6 = $gip->check_valid_ipv6("$go_to_address") || "0";
#		if ( $valid_v6 != "1" ) { 
#			$gip->print_error("$client_id","$$lang_vars{no_valid_ipv6_address_message} <b>$go_to_address</b>");
#		}
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
	
	if ( $knownhosts =~ /all/ ) { 
#	if ( $knownhosts !~ /hosts/ ) { 
		$add_dif = $go_to_address_int-$start_ip_int;
		$add_dif++ if $ip_version eq "v6";
		$add_dif = Math::BigInt->new("$add_dif");
		$entries_per_page_hosts= Math::BigInt->new("$entries_per_page_hosts");
		$start_entry_hosts=$add_dif/$entries_per_page_hosts;
		$start_entry_hosts=int($start_entry_hosts + 0.5);
		$start_entry_hosts*= $entries_per_page_hosts;

#		$add_dif = $go_to_address_int-$start_ip_int;
#		$add_dif++ if $ip_version eq "v6";
#		$add_dif++ if $ip_version eq "v6";
#		$add_dif = Math::BigInt->new("$add_dif");
#		$entries_per_page_hosts = Math::BigInt->new("$entries_per_page_hosts");
#		$anz_hosts_bm{$BM} = Math::BigInt->new("$anz_hosts_bm{$BM}");
#		my $last_page_show=$anz_hosts_bm{$BM}/$entries_per_page_hosts;
#		$start_entry_hosts=($add_dif*$last_page_show)/$anz_hosts_bm{$BM};
#		$start_entry_hosts*= $entries_per_page_hosts;

	} elsif ( $knownhosts =~ /libre/ ) {
		my $hostcount=$gip->count_host_entries_between("$client_id","$red_num","$start_ip_int","$go_to_address_int","$ip_version");
		$add_dif = $go_to_address_int-$start_ip_int-$hostcount;
		$add_dif++ if $ip_version eq "v6";
		$add_dif = Math::BigInt->new("$add_dif");
		$entries_per_page_hosts= Math::BigInt->new("$entries_per_page_hosts");
		$start_entry_hosts=$add_dif/$entries_per_page_hosts;
		$start_entry_hosts=int($start_entry_hosts + 0.5);
		$start_entry_hosts*= $entries_per_page_hosts;

	} elsif ( $knownhosts =~ /hosts/ ) {
		my $entry_number;
		my $u=0;
		my @hostnames=$gip->get_red_hostnames("$client_id","$red_num");
		my $go_to_address_int=$gip->ip_to_int("$client_id","$go_to_address","$ip_version");
		foreach (@hostnames) {
			last if $_->[0] =~ /($go_to_address_int)/;
			$u++;
		}
		$entry_number = $u;
		my $anz_values_hosts_total=$gip->count_host_entries("$client_id","$red_num");
		$start_entry_hosts=$entry_number/$entries_per_page_hosts;
#		$start_entry_hosts=int($start_entry_hosts + 0.5);
		$start_entry_hosts=floor($start_entry_hosts);
		$start_entry_hosts*= $entries_per_page_hosts;
	}
}


$start_entry_hosts = Math::BigInt->new("$start_entry_hosts");

if ( $start_entry_hosts >= $anz_values_hosts_pages && ! defined($daten{'go_to_address'}) ) {
	if ( $knownhosts !~ /libre/ ) { 
		$start_entry_hosts=$anz_values_hosts_pages/$entries_per_page_hosts;
		$start_entry_hosts=floor("$start_entry_hosts");
		$start_entry_hosts = Math::BigInt->new("$start_entry_hosts");
		$start_entry_hosts*= $entries_per_page_hosts;
	} else {
		my $anz_values_hosts_total=$gip->count_host_entries("$client_id","$red_num");
		$start_entry_hosts=$anz_values_hosts_pages/$entries_per_page_hosts;
		$start_entry_hosts=floor("$start_entry_hosts");
		$start_entry_hosts = Math::BigInt->new("$start_entry_hosts");
		$start_entry_hosts*= $entries_per_page_hosts;
		$start_entry_hosts+=$anz_values_hosts_total;
	}
}


($host_hash_ref,$first_ip_int,$last_ip_int)=$gip->prepare_host_hash("$client_id",$host_hash_ref,"$first_ip_int","$last_ip_int","res/ip_modip_form.cgi","$knownhosts","$$lang_vars{modificar_message}","$red_num","$red_loc","$vars_file","$anz_values_hosts","$start_entry_hosts","$entries_per_page_hosts","$host_order_by","$redbroad_int","$ip_version");

my $pages_links=$gip->get_pages_links_host("$client_id","$start_entry_hosts","$anz_values_hosts_pages","$entries_per_page_hosts","$red_num","$knownhosts","$host_order_by","$start_ip_int",$host_hash_ref,"$redbroad_int","$ip_version","$vars_file","host_list_view");

$gip->PrintIpTabHead("$client_id","$knownhosts","res/ip_modip_form.cgi","$red_num","$vars_file","$start_entry_hosts","$anz_values_hosts","$entries_per_page_hosts","$pages_links","$host_order_by","$ip_version");

$gip->PrintIpTab("$client_id",$host_hash_ref,"$first_ip_int","$last_ip_int","res/ip_modip_form.cgi","$knownhosts","$$lang_vars{modificar_message}","$red_num","$red_loc","$vars_file","$anz_values_hosts_pages","$start_entry_hosts","$entries_per_page_hosts","$host_order_by","$host_sort_helper_array_ref","","$ip_version","","","$go_to_address_int");

$gip->print_end("$client_id","$vars_file","go_to_top");
