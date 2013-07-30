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
my ($lang_vars,$vars_file,$entries_per_page_hosts);
($lang_vars,$vars_file)=$gip->get_lang("","$lang");
if ( $daten{'entries_per_page_hosts'} && $daten{'entries_per_page_hosts'} =~ /^\d{1,4}$/ ) {
        $entries_per_page_hosts=$daten{'entries_per_page_hosts'};
} else {
        $entries_per_page_hosts = "254";
}

my $client_id = $daten{'client_id'} || $gip->get_first_client_id();
my $ip_version = $daten{'ip_version'};

my ($hostname, $ip);
my $host_order_by = $daten{'host_order_by'} || "IP_auf";


my $length_hostname=0;
$length_hostname = length($daten{'hostname'}) || "0" if $daten{'hostname'};
my $length_descr=0;
$length_descr = length($daten{'host_descr'}) || "0" if $daten{'host_descr'};
my $length_comentario=0;
$length_comentario = length($daten{'comentario'}) || "0" if $daten{'comentario'};

my ($ipob, $ip_int, $range_comentario);

my $search_index=$daten{'search_index'} || "false";
my $search_hostname=$daten{'search_hostname'} || "";
$host_order_by = "SEARCH" if $search_index eq "true";



$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{host_mass_update_message}","$vars_file");

my $url_method=$daten{'url_method'} || "";
if ( $url_method ) {
	$gip->print_error("$client_id","$$lang_vars{formato_malo_message}") if $url_method !~ /^(POST|GET)$/;
}

my $mass_update_type=$daten{'mass_update_type'};
$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (1)") if ! $mass_update_type;
my $anz_nets=$daten{'anz_nets'} || "0";


$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (2)") if ! $daten{'mass_update_host_ids'};
$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (3)") if ($daten{'mass_update_host_ids'} !~ /[0-9_]/ );
my $mass_update_host_ids=$daten{"mass_update_host_ids"} || "";


$gip->print_error("$client_id",$$lang_vars{max_signos_hostname_message}) if $length_hostname > 100 ;
$gip->print_error("$client_id",$$lang_vars{max_signos_descr_message}) if $length_descr > 100 ;
$gip->print_error("$client_id",$$lang_vars{max_signos_comentario_message}) if $length_comentario > 500 ;



my $red=$daten{'red'};
my $BM=$daten{'BM'};
my $red_num=$daten{'red_num'} || "";
my $host_descr=$daten{'host_descr'} || "NULL";
my $knownhosts = $daten{'knownhosts'} || "all";

$gip->print_error("$client_id","$$lang_vars{formato_malo_message}") if $daten{'anz_values_hosts'} && $daten{'anz_values_hosts'} !~ /^\d{2,4}||no_value$/;
$gip->print_error("$client_id","$$lang_vars{formato_malo_message}") if $daten{'knownhosts'} && $daten{'knownhosts'} !~ /^all|hosts|libre$/;
$gip->print_error("$client_id","$$lang_vars{formato_malo_message}") if $daten{'start_entry_hosts'} && $daten{'start_entry_hosts'} !~ /^\d{1,20}$/;
$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (4) $ip_version") if $ip_version !~ /^(v4|v6)$/;


my $redob = "$red/$BM";

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


my ( $first_ip_int, $last_ip_int, $last_ip_int_red, $start_entry, $redint, $redbroad_int, $start_ip_int);
$first_ip_int=$last_ip_int=$last_ip_int_red=$start_entry=$redint=$redbroad_int=$start_ip_int="";


if ( $search_index ne "true" ) {
	$ipob = new Net::IP ($redob) || $gip->print_error("$client_id","Can't create ip object: $redob: $!\n");
	$redint=($ipob->intip());
	$redbroad_int=($ipob->last_int());
	$redint = Math::BigInt->new("$redint");
	$first_ip_int = $redint + 1;
	$start_ip_int=$first_ip_int;
	$last_ip_int = ($ipob->last_int());
	$last_ip_int = Math::BigInt->new("$last_ip_int");
	$last_ip_int = $last_ip_int - 1;
	$last_ip_int_red=$last_ip_int;
}


my $mydatetime = time();

my $red_loc = $gip->get_loc_from_redid("$client_id","$red_num") || "";
my $red_loc_id = $gip->get_loc_id("$client_id","$red_loc") || "-1";


my @mass_update_types=();
if ( $mass_update_type =~ /_/ ) {
        @mass_update_types=split("_",$mass_update_type);
} else {
        $mass_update_types[0]=$mass_update_type;
}

my $descr="";
my $loc="";
#my $loc_id="-1";
my $loc_id="";
my $cat="";
#my $cat_id="-1";
my $cat_id="";
my $comentario="";
my $int_admin="";
my $utype="";
my $utype_id="";
my @mass_update_types_cc=();


my $i=0;
foreach (@mass_update_types) {
	if ( $_ eq $$lang_vars{description_message} ) {
		$gip->print_error("$client_id","$$lang_vars{introduce_description_message}") if ( ! $daten{'host_descr'} );
		$gip->print_error("$client_id","$$lang_vars{palabra_reservada_comment_NULL_message}") if $daten{'host_descr'} eq "NULL";
		$descr=$daten{'host_descr'} || "__NOVAL__";
	} elsif ( $_ =~ /$$lang_vars{loc_message}/ ) {
		$gip->print_error("$client_id","$$lang_vars{introduce_loc_message}") if ( ! $daten{'loc'} );
		$loc=$daten{'loc'} || "";
		$loc_id=$gip->get_loc_id("$client_id","$loc") || "-1";
	} elsif ( $_ =~ /$$lang_vars{tipo_message}/ ) {
		$cat=$daten{'cat'} || "";
		$cat_id=$gip->get_cat_id("$client_id","$cat") || "-1";
	} elsif ( $_ =~ /$$lang_vars{comentario_message}/ ) {
		$gip->print_error("$client_id","$$lang_vars{palabra_reservada_comment_NULL_message}") if $daten{'comentario'} eq "NULL";
		$comentario=$daten{'comentario'} || "__NOVAL__";
	} elsif ( $_ =~ /^AI$/ ) {
		$int_admin=$daten{'int_admin'} || "n";
	} elsif ( $_ =~ /^UT$/ ) {
		$utype=$daten{'update_type'} || "";
		$utype_id=$gip->get_utype_id("$client_id","$utype") || "-1";
	} else {
		$mass_update_types_cc[$i]=$_;	
		$i++;
	}
}

$gip->mass_update_hosts("$client_id","$mass_update_host_ids","$red_num","$ip_version","$descr","$loc_id","$cat_id","$comentario","$utype_id","$int_admin","$red_loc_id","$search_index");

my %cc_value=$gip->get_custom_host_columns_id_from_net_id_hash("$client_id","$red_num");
my @custom_columns = $gip->get_custom_host_columns("$client_id");
my $cc_anz=@custom_columns;

my $audit_entry_cc;

my ($mass_update_type_cc_name, $mass_update_type_cc_name_value, $mass_update_type_cc_name_id, $mass_update_type_cc_name_pcid);
foreach (@mass_update_types_cc) {
	$mass_update_type_cc_name=$_;
	$mass_update_type_cc_name_value=$mass_update_type_cc_name . "_value";
	$mass_update_type_cc_name_id=$mass_update_type_cc_name . "_id";
	$mass_update_type_cc_name_pcid=$mass_update_type_cc_name . "_pcid";
        my $cc_id=$daten{"$mass_update_type_cc_name_id"};
        my $cc_pcid=$daten{"$mass_update_type_cc_name_pcid"};
	if ( defined($daten{"$mass_update_type_cc_name_value"}) ) {
		$audit_entry_cc.="," if $audit_entry_cc;
		if ( length($daten{"$mass_update_type_cc_name_value"}) > 0 ) {	
			if ( $mass_update_type_cc_name eq "URL" ) {
				if ( $daten{$mass_update_type_cc_name_value} !~ /^(.{1,30}::.{1,750})(,.{1,30}.{1,750};?)?$/ ) {
					print "<font color=\"red\">$$lang_vars{wrong_url_format_message} - $daten{$mass_update_type_cc_name_value} - $$lang_vars{ignorado_message}</font><br>\n";
					next;
				}
				$gip->mass_update_custom_column_value_host("$client_id","$cc_id","$cc_pcid","$mass_update_host_ids","$daten{$mass_update_type_cc_name_value}","$red_num");
				$audit_entry_cc.="$mass_update_type_cc_name:$daten{$mass_update_type_cc_name_value}";
					
			} else {
				$gip->mass_update_custom_column_value_host("$client_id","$cc_id","$cc_pcid","$mass_update_host_ids","$daten{$mass_update_type_cc_name_value}","$red_num");
				$audit_entry_cc.="$mass_update_type_cc_name:$daten{$mass_update_type_cc_name_value}";
			}
		} else {
			$gip->mass_update_custom_column_value_host("$client_id","$cc_id","$cc_pcid","$mass_update_host_ids","__NOVAL__","$red_num");
			$audit_entry_cc.="$mass_update_type_cc_name:---";
		}
	}
}


$audit_entry_cc = "---" if ! $audit_entry_cc;

my $mass_update_host_ids_audit=$mass_update_host_ids;
$mass_update_host_ids_audit =~ s/_/,/g;

my $audit_type="1";
my $audit_class="1";
my $update_type_audit="1";
$host_descr = "---" if $host_descr eq "NULL" || ! $descr;
my $cat_audit = $cat;
$cat_audit = "---" if $cat_id eq "-1" || ! $cat;
my $loc_audit=$loc;
$loc_audit = "---" if $loc_id eq "-1" || ! $loc;
my $comentario_audit = $comentario;
$comentario_audit = "---" if $comentario eq "NULL" || ! $comentario;
$utype = "---" if ! $utype || $utype_id eq "-1";
my $int_admin_audit=$int_admin;
$int_admin_audit="n" if ! $int_admin;
my $event="mass update: $mass_update_host_ids_audit: $host_descr,$loc_audit,$int_admin_audit,$cat_audit,$comentario,$utype,$audit_entry_cc";
$gip->insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");


$knownhosts="all" if $knownhosts eq "libre";
my $go_to_address="";
$go_to_address=$ip;

my ($host_hash_ref,$host_sort_helper_array_ref);
if ( $search_index ne "true" ) {
	($host_hash_ref,$host_sort_helper_array_ref)=$gip->get_host_hash("$client_id","$first_ip_int","$last_ip_int","$host_order_by","$knownhosts","$red_num");
} else {
	($host_hash_ref,$host_sort_helper_array_ref)=$gip->search_db_hash("$client_id","$vars_file",\%daten);
}

my $anz_host_total=0;
if ( $search_index ne "true" ) {
	$anz_host_total=$gip->get_host_hash_count("$client_id","$red_num") || "0";
} else {
	$anz_host_total=scalar(%{$host_hash_ref});
}

my %anz_hosts_bm=();
my ($anz_values_hosts_pages, $anz_values_hosts);
if ( $search_index ne "true" ) {

	if ( $anz_host_total >= $entries_per_page_hosts ) {
		my $last_ip_int_new = $first_ip_int + $start_entry_hosts + $entries_per_page_hosts - 1;
		$last_ip_int = $last_ip_int_new if $last_ip_int_new < $last_ip_int;
	} else {
		$last_ip_int = ($ipob->last_int());
		$last_ip_int = $last_ip_int - 1;
	}

	%anz_hosts_bm = $gip->get_anz_hosts_bm_hash("$client_id","$ip_version");
	$anz_hosts_bm{$BM} =~ s/,//g;
	$anz_values_hosts_pages = $anz_hosts_bm{$BM};
	$anz_values_hosts_pages = Math::BigInt->new("$anz_values_hosts_pages");
	$anz_values_hosts=$daten{'anz_values_hosts'} || $anz_hosts_bm{$BM};
	$anz_values_hosts = Math::BigInt->new("$anz_values_hosts");


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

	$anz_values_hosts_pages =~ s/,//g;

	if ( $go_to_address ) {
		my $go_to_address_int=$ip_int;
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
			$add_dif++ if $ip_version eq "v6";
			$add_dif = Math::BigInt->new("$add_dif");
			$entries_per_page_hosts = Math::BigInt->new("$entries_per_page_hosts");
			$start_entry_hosts=$add_dif/$entries_per_page_hosts;
			$start_entry_hosts=int($start_entry_hosts + 0.5);
			$start_entry_hosts*= $entries_per_page_hosts;
		} elsif ( $knownhosts =~ /hosts/ && $ENV{HTTP_REFERER} =~ /ip_modip/ ) {
			$start_entry_hosts=$daten{start_entry_hosts};
		}

#		} else {
#			my $entry_number;
#			my $u=0;
#			my @hostnames=$gip->get_red_hostnames("$client_id","$red_num");
#			my $go_to_address_int=$gip->ip_to_int("$client_id","$go_to_address",'v6');
#			foreach (@hostnames) {
#				last if $_->[0] =~ /($go_to_address_int)/;
#				$u++;
#			}
#			$entry_number = $u;
#			my $anz_values_hosts_total=$gip->count_host_entries("$client_id","$red_num");
#			$start_entry_hosts=$entry_number/$entries_per_page_hosts;
#			$start_entry_hosts=int($start_entry_hosts + 0.5);
#			$start_entry_hosts*= $entries_per_page_hosts;
#		}

	} else {








		if ( $start_entry_hosts >= $anz_values_hosts_pages ) {
			$start_entry_hosts=$anz_values_hosts_pages/$entries_per_page_hosts;
			$start_entry_hosts=floor("$start_entry_hosts");
			$start_entry_hosts*= $entries_per_page_hosts;
		}
	}

	($host_hash_ref,$first_ip_int,$last_ip_int)=$gip->prepare_host_hash("$client_id",$host_hash_ref,"$first_ip_int","$last_ip_int","res/ip_modip_form.cgi","$knownhosts","$$lang_vars{modificar_message}","$red_num","$red_loc","$vars_file","$anz_values_hosts","$start_entry_hosts","$entries_per_page_hosts","$host_order_by","$redbroad_int","$ip_version");

	my $pages_links=$gip->get_pages_links_host("$client_id","$start_entry_hosts","$anz_values_hosts_pages","$entries_per_page_hosts","$red_num","$knownhosts","$host_order_by","$start_ip_int",$host_hash_ref,"$redbroad_int","$ip_version","$vars_file");

	$gip->PrintIpTabHead("$client_id","$knownhosts","res/ip_modip_form.cgi","$red_num","$vars_file","$start_entry_hosts","$anz_values_hosts","$entries_per_page_hosts","$pages_links","","$ip_version");

	$gip->PrintIpTab("$client_id",$host_hash_ref,"$first_ip_int","$last_ip_int","res/ip_modip_form.cgi","$knownhosts","$$lang_vars{modificar_message}","$red_num","$red_loc","$vars_file","$anz_values_hosts_pages","$start_entry_hosts","$entries_per_page_hosts","$host_order_by","$host_sort_helper_array_ref","","$ip_version","","","");

} else {
	$anz_values_hosts += keys %$host_hash_ref;
	$knownhosts="all";
	$start_entry_hosts="0";
	$entries_per_page_hosts="512";
	my $pages_links="NO_LINKS";
	$host_order_by = "SEARCH";
	$red_num = "";
	$red_loc = "";
	$redbroad_int = "1";
	$first_ip_int = "";
	$last_ip_int = "";
	my $client_independent="no";


	my %advanced_search_hash=();

	my @column_values=("advanced_search_hostname","advanced_search_host_descr","advanced_search_comentario","advanced_search_ip","advanced_search_loc","advanced_search_cat","advanced_search_int_admin","advanced_search_host_descr","advanced_search_hostname_exact","advanced_search_client_independent");

	foreach my $column ( @column_values ) {
		if ( $daten{"$column"} ) {
			$advanced_search_hash{"$column"}=$daten{"$column"};
		}
	}


	my @cc_values=$gip->get_custom_host_columns("$client_id");
	for ( my $k = 0; $k < scalar(@cc_values); $k++ ) {
		# mass update
		if (  defined $daten{"cc_id_$cc_values[$k]->[1]"} ) {
			my $key="cc_id_$cc_values[$k]->[1]";
			$advanced_search_hash{"$key"}=$daten{"$key"} if exists($daten{"$key"});
		}
	}


#	while ( my ($key, $value) = each(%advanced_search_hash) ) {
#		print "TEST ASH: $key => $value<br>\n";
#	    }

	my $advanced_search_hash=\%advanced_search_hash;


	$gip->PrintIpTab("$client_id",$host_hash_ref,"$first_ip_int","$last_ip_int","res/ip_modip_form.cgi","$knownhosts","$$lang_vars{modificar_message}","$red_num","$red_loc","$vars_file","$anz_values_hosts","$start_entry_hosts","$entries_per_page_hosts","$host_order_by",$host_sort_helper_array_ref,"$client_independent","$ip_version","$search_index","$search_hostname","",$advanced_search_hash);
}


$gip->print_end("$client_id","$vars_file","go_to_top");
