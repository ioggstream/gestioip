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
if ( $ip_version eq "v4" ) {
	$ip=$daten{'ip'} if ( $daten{'ip'} =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/ );
} else {
	$ip=$daten{'ip'};
}
my $host_order_by = $daten{'host_order_by'} || "IP_auf";


my $length_hostname = length($daten{'hostname'});
my $length_descr = length($daten{'host_descr'});
my $length_comentario = length($daten{'comentario'});
my ($ipob, $ip_int, $range_comentario);

my $search_index=$daten{'search_index'} || "false";
my $search_hostname=$daten{'search_hostname'} || "";
$host_order_by = "SEARCH" if $search_index eq "true";


if ( ! $daten{'hostname'} || ! $daten{'loc'} || ! $ip || $daten{'hostname'} =~ /\s+/ || $length_hostname > 75 || $length_hostname < 2 || $length_descr > 100 || $length_comentario > 500) {
	$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{cambiar_host_message} $ip","$vars_file");
	$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (1)") if ! $ip;
	$ipob = new Net::IP ($ip) or $gip->print_error("$client_id","$$lang_vars{formato_ip_malo_message}: <b>+$ip+</b>");
	$ip_int = ($ipob->intip());
	$range_comentario=$gip->get_rango_comentario_host("$client_id","$ip_int");
	$gip->print_error("$client_id","$$lang_vars{introduce_hostname_message}") if ! $daten{'hostname'};
	$gip->print_error("$client_id","$$lang_vars{min_signos_hostname_message}") if $length_hostname < 2;
	$gip->print_error("$client_id","$$lang_vars{introduce_loc_message}") if ! $daten{'loc'};
	$gip->print_error("$client_id","$$lang_vars{whitespace_message}") if $daten{'hostname'} =~ /\s+/;
	$gip->print_error("$client_id","$$lang_vars{max_signos_hostname_message}") if $length_hostname > 75;
	$gip->print_error("$client_id","$$lang_vars{max_signos_descr_message}") if $length_descr > 100;
	$gip->print_error("$client_id","$$lang_vars{max_signos_comentario_message}") if $length_hostname > 500;
} else { 
	$hostname=$daten{'hostname'} || "$ip";
	$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$hostname: $$lang_vars{cambiar_host_done_message}","$vars_file");
	$ipob = new Net::IP ($ip) or $gip->print_error("$client_id","$$lang_vars{formato_ip_malo_message}: <b>+$ip+</b>");
	$ip_int = ($ipob->intip());
	$range_comentario=$gip->get_rango_comentario_host("$client_id","$ip_int");
}

my $url_method=$daten{'url_method'} || "";
if ( $url_method ) {
	$gip->print_error("$client_id","$$lang_vars{formato_malo_message}") if $url_method !~ /^(POST|GET)$/;
}


my $loc=$daten{'loc'} || "NULL";
my $red=$daten{'red'};
my $BM=$daten{'BM'};
my $red_num=$daten{'red_num'};
my $host_descr=$daten{'host_descr'} || "NULL";
my $cat=$daten{'cat'} || "NULL";
my $host_exist=$daten{'host_exist'};
my $comentario=$daten{'comentario'} || "NULL";
my $knownhosts = $daten{'knownhosts'} || "all";
my $int_admin = $daten{'int_admin'} || "n";
my $utype = $daten{'update_type'};
my $host_id = $daten{'host_id'} || "";

$gip->print_error("$client_id","$$lang_vars{formato_malo_message}") if $daten{'anz_values_hosts'} && $daten{'anz_values_hosts'} !~ /^\d{2,4}||no_value$/;
$gip->print_error("$client_id","$$lang_vars{formato_malo_message}") if $daten{'knownhosts'} && $daten{'knownhosts'} !~ /^all|hosts|libre$/;
$gip->print_error("$client_id","$$lang_vars{formato_malo_message}") if $daten{'start_entry_hosts'} && $daten{'start_entry_hosts'} !~ /^\d{1,20}$/;
$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (2)") if $ip_version !~ /^(v4|v6)$/;

my $redob = "$red/$BM";
my $loc_id=$gip->get_loc_id("$client_id","$loc") || "-1";
my $cat_id=$gip->get_cat_id("$client_id","$cat") || "-1";
my $utype_id=$gip->get_utype_id("$client_id","$utype") || "-1";

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


my ( $first_ip_int, $last_ip_int, $last_ip_int_red, $start_entry);

$ipob = new Net::IP ($redob) || $gip->print_error("$client_id","Can't create ip object: $!\n");
my $redint=($ipob->intip());
my $redbroad_int=($ipob->last_int());
$redint = Math::BigInt->new("$redint");
$first_ip_int = $redint + 1;
my $start_ip_int=$first_ip_int;
$last_ip_int = ($ipob->last_int());
$last_ip_int = Math::BigInt->new("$last_ip_int");
$last_ip_int = $last_ip_int - 1;
$last_ip_int_red=$last_ip_int;


my $mydatetime = time();

my $red_loc = $gip->get_loc_from_redid("$client_id","$red_num");
my @ch=$gip->get_host("$client_id","$ip_int","$ip_int");

if ( @ch ) {
	my $alive = $ch[0]->[8] || "-1";
	$gip->update_ip_mod("$client_id","$ip_int","$hostname","$host_descr","$loc_id","$int_admin","$cat_id","$comentario","$utype_id","$mydatetime","$red_num","$alive","$ip_version");
} else {
	$gip->insert_ip_mod("$client_id","$ip_int","$hostname","$host_descr","$loc_id","$int_admin","$cat_id","$comentario","$utype_id","$mydatetime","$red_num","-1","$ip_version");
}


$host_id = $gip->get_last_host_id("$client_id") if ! $host_id;

my %cc_value=$gip->get_custom_host_columns_id_from_net_id_hash("$client_id","$red_num");
my @custom_columns = $gip->get_custom_host_columns("$client_id");
my $cc_anz=@custom_columns;

my $audit_entry_cc;
my $audit_entry_cc_new;
my @linked_ips_not_exists=();
my @linked_ips_not_valid=();

for (my $o=0; $o<$cc_anz; $o++) {
        my $cc_name=$daten{"custom_${o}_name"};
        my $cc_value=$daten{"custom_${o}_value"} || "";
	if ( defined($daten{"custom_${o}_value_known"}) && $daten{"vendor_radio"} eq "known" ) {
		$cc_value=$daten{"custom_${o}_value_known"} || "";
	} elsif ( defined($daten{"custom_${o}_value_unknown"}) ) {
		$cc_value=$daten{"custom_${o}_value_unknown"} || "";
	}
        my $cc_id=$daten{"custom_${o}_id"};
        my $pc_id=$daten{"custom_${o}_pcid"};

	my $prede_column_name=$gip->get_predef_host_column_name("$client_id","$pc_id");

        if ( $cc_value ) {
                my $cc_entry_host=$gip->get_custom_host_column_entry("$client_id","$host_id","$cc_name","$pc_id") || "";
                if ( $cc_entry_host ) {
			if ( $prede_column_name eq "URL" ) {
				if ( $cc_value !~ /^(.{1,30}::.{1,750})(,.{1,30}.{1,750};?)?$/ ) {
					print "<font color=\"red\">$$lang_vars{wrong_url_format_message} - $cc_value</font><br>\n";
					next;
				}
				
			} elsif ( $prede_column_name eq "linked IP" ) {
				my @linked_ips=();
				my @linked_ips_old=();
				@linked_ips_old=split(",",$cc_entry_host);
				$cc_value =~ s/\s*//g;
				@linked_ips=split(",",$cc_value);

				# elements which are only in linked_ips_old
				my %seen;
				my @linked_ips_old_only;
				@seen{@linked_ips} = ();
				foreach my $item (@linked_ips_old) {
					push(@linked_ips_old_only, $item) unless exists $seen{$item};
				}

				# delete linked IP from elements of @linked_ips_old_only
				foreach my $linked_ip_old_only(@linked_ips_old_only){
					$gip->delete_linked_ip("$client_id","$ip_version","$linked_ip_old_only","$ip");
				}

				# update linked IP
				my $cc_value_new="";
				foreach my $linked_ip( @linked_ips ) {

					my $ip_version_linked_ip;
					if ( $linked_ip =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/ ) {
						$ip_version_linked_ip="v4";
					} else {
						$ip_version_linked_ip="v6";
					}

					my $ip_version_ip;
					if ( $ip =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/ ) {
						$ip_version_ip="v4";
					} else {
						$ip_version_ip="v6";
					}

					my $ip_comp=$ip;
					$ip_comp = ip_compress_address ($ip_comp, 6) if $ip_version_ip eq "v6";

					next if $linked_ip eq $ip_comp;

					my $valid_ip=0;
					if ( $linked_ip =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/ ) {
						$valid_ip = 1;
					} else {
						$valid_ip = $gip->check_valid_ipv6("$linked_ip") || "0";
					}
					if ( $valid_ip != 1 ) {
						push(@linked_ips_not_valid,"$linked_ip");
						next;
					}

					my $ip_int_linked=$gip->ip_to_int("$client_id","$linked_ip","$ip_version_linked_ip");
					my @host=$gip->get_host("$client_id","$ip_int_linked","$ip_int_linked");
					if ( ! $host[0] ) {
						push(@linked_ips_not_exists,"$linked_ip");
						next;
					}

					my $linked_ip_comp;
					if ( $ip_version_linked_ip eq "v6" ) {
						$linked_ip_comp = ip_compress_address ($linked_ip, 6);
					} else {
						$linked_ip_comp=$linked_ip;
					}
					$cc_value_new.="," . $linked_ip_comp;
					
					my $linked_host_id=$host[0]->[11];
					my $linked_cc_entry=$gip->get_custom_host_column_entry("$client_id","$linked_host_id","$cc_name","$pc_id") || "";

					if ( $linked_cc_entry ) {
						if ( $linked_cc_entry !~ /\b${ip_comp}\b/ ) {
							$linked_cc_entry.="," . $ip_comp;
							$gip->update_custom_host_column_value_host_modip("$client_id","$cc_id","$pc_id","$linked_host_id","$linked_cc_entry");
						}
					} else {
						$gip->insert_custom_host_column_value_host("$client_id","$cc_id","$pc_id","$linked_host_id","$ip_comp");
					}
				}
				$cc_value_new =~ s/^,//;
				$cc_value=$cc_value_new;
			}

			$gip->update_custom_host_column_value_host_modip("$client_id","$cc_id","$pc_id","$host_id","$cc_value");

			if ( $audit_entry_cc ) {
				$audit_entry_cc = $audit_entry_cc . "," . $cc_entry_host;
			} else {
				$audit_entry_cc = $cc_entry_host;
			}
			if ( $audit_entry_cc_new ) {
				$audit_entry_cc_new = $audit_entry_cc_new . "," .$cc_value;
			} else {
				$audit_entry_cc_new = $cc_value;
			}
                } else {
			if ( $prede_column_name eq "URL" ) {
				if ( $cc_value !~ /^.{1,30}::.{1,300}$/ ) {
					print "<font color=\"red\">$$lang_vars{wrong_url_format_message} - $cc_value</font><br>\n";
					next;
				}
			} elsif ( $prede_column_name eq "linked IP" ) {
				my @linked_ips=();
				$cc_value =~ s/\s*//g;
				@linked_ips=split(",",$cc_value);

				# update linked IP
				my $cc_value_new="";
				foreach my $linked_ip( @linked_ips ) {

					my $ip_version_linked_ip;
					if ( $linked_ip =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/ ) {
						$ip_version_linked_ip="v4";
					} else {
						$ip_version_linked_ip="v6";
					}

					my $ip_version_ip;
					if ( $ip =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/ ) {
						$ip_version_ip="v4";
					} else {
						$ip_version_ip="v6";
					}

					my $ip_comp=$ip;
					$ip_comp = ip_compress_address ($ip_comp, 6) if $ip_version_ip eq "v6";

					next if $linked_ip eq $ip_comp;

					my $valid_ip=0;
					if ( $linked_ip =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/ ) {
						$valid_ip = 1;
					} else {
						$valid_ip = $gip->check_valid_ipv6("$linked_ip") || "0";
					}
					if ( $valid_ip != 1 ) {
						push(@linked_ips_not_valid,"$linked_ip");
						next;
					}

					my $ip_int_linked=$gip->ip_to_int("$client_id","$linked_ip","$ip_version_linked_ip");
					my @host=$gip->get_host("$client_id","$ip_int_linked","$ip_int_linked");
					if ( ! $host[0] ) {
						push(@linked_ips_not_exists,"$linked_ip");
						next;
					}

					my $linked_ip_comp;
					if ( $ip_version_linked_ip eq "v6" ) {
						$linked_ip_comp = ip_compress_address ($linked_ip, 6);
					} else {
						$linked_ip_comp=$linked_ip;
					}
					$cc_value_new.="," . $linked_ip_comp;

					my $linked_host_id=$host[0]->[11];
					my $linked_cc_entry=$gip->get_custom_host_column_entry("$client_id","$linked_host_id","$cc_name","$pc_id") || "";

					if ( $linked_cc_entry ) {
						if ( $linked_cc_entry !~ /\b${ip_comp}\b/ ) {
							$linked_cc_entry.="," . $ip_comp;
							$gip->update_custom_host_column_value_host_modip("$client_id","$cc_id","$pc_id","$linked_host_id","$linked_cc_entry");
						}
					} else {
						$gip->insert_custom_host_column_value_host("$client_id","$cc_id","$pc_id","$linked_host_id","$ip_comp");
					}
				}
				$cc_value_new =~ s/^,//;
				$cc_value=$cc_value_new || "";
			}

			$gip->insert_custom_host_column_value_host("$client_id","$cc_id","$pc_id","$host_id","$cc_value") if $cc_value;

			if ( $audit_entry_cc ) {
				$audit_entry_cc = $audit_entry_cc . ",---";
			} else {
				$audit_entry_cc = ",---";
			}
			if ( $audit_entry_cc_new ) {
				$audit_entry_cc_new = $audit_entry_cc_new . "," . $cc_value ;
			} else {
				$audit_entry_cc_new = $cc_value;
			}
                }
        } else {
                my $cc_entry_host=$gip->get_custom_host_column_entry("$client_id","$host_id","$cc_name","$pc_id") || "";
                if ( $cc_entry_host ) {
			if ( $prede_column_name eq "linked IP" ) {
				my @linked_ips_old_only=();
				@linked_ips_old_only=split(",",$cc_entry_host);

				# delete linked IP from elements of @linked_ips_old_only
				foreach my $linked_ip_old_only(@linked_ips_old_only){
					$gip->delete_linked_ip("$client_id","$ip_version","$linked_ip_old_only","$ip");
				}
			}

			$gip->delete_single_custom_host_column_entry("$client_id","$host_id","$cc_entry_host","$pc_id");
			if ( $audit_entry_cc ) {
				$audit_entry_cc = $audit_entry_cc . "," . $cc_entry_host;
			} else {
				$audit_entry_cc = $cc_entry_host;
			}
			if ( $audit_entry_cc_new ) {
				$audit_entry_cc_new = $audit_entry_cc_new . ",---" ;
			} else {
				$audit_entry_cc_new = "---";
			}
		} else {
			if ( $audit_entry_cc ) {
				$audit_entry_cc = $audit_entry_cc . ",---";
			} else {
				$audit_entry_cc = "---";
			}
			if ( $audit_entry_cc_new ) {
				$audit_entry_cc_new = $audit_entry_cc_new . ",---" ;
			} else {
				$audit_entry_cc_new = "---";
			}
		}
	}
}

$audit_entry_cc = "---" if ! $audit_entry_cc;
$audit_entry_cc_new = "---" if ! $audit_entry_cc_new;


if ( @ch ) {
	my $audit_class="1";
	my $audit_type="1";
	my $update_type_audit="1";
	$utype = "---" if ! $utype;
	$ch[0]->[1] = "---" if ! $ch[0]->[1];
	$ch[0]->[1] = "---" if $ch[0]->[1] eq "NULL";
	$ch[0]->[2] = "---" if ! $ch[0]->[2];
	$ch[0]->[2] = "---" if $ch[0]->[2] eq "NULL";
	$ch[0]->[3] = "---" if $ch[0]->[3] eq "NULL";
	$ch[0]->[4] = "---" if $ch[0]->[4] eq "NULL";
	$ch[0]->[5] = "n" if $ch[0]->[5] eq "NULL";
	$ch[0]->[6] = "---" if ! $ch[0]->[6];
	$ch[0]->[6] = "---" if $ch[0]->[6] eq "NULL";
	$ch[0]->[7] = "---" if ! $ch[0]->[7];
	$ch[0]->[7] = "---" if $ch[0]->[7] eq "-1" || $ch[0]->[7] eq "NULL";
	my $ip=$gip->int_to_ip("$client_id","$ip_int","$ip_version");
	$host_descr = "---" if $host_descr eq "NULL";
	$cat = "---" if $cat eq "NULL";
	$loc = "---" if $loc eq "NULL";
	$comentario = "---" if $comentario eq "NULL";
	$utype = "---" if ! $utype;
	my $hostname_audit = $hostname;
	$hostname_audit = "---" if $hostname_audit eq "NULL";
	if ( $range_comentario ) {
		if ( $comentario ne "---" ) {
			$comentario = "[" . $range_comentario . "] " . $comentario;
		} else {
			$comentario = "[" . $range_comentario . "] ";
		}
		if ( $ch[0]->[6] ne "---" ) {
			$ch[0]->[6] = "[" . $range_comentario . "] " . $ch[0]->[6];
		} else {
			$ch[0]->[6] = "[" . $range_comentario . "] ";
		}
	}
	my $event="$ip: $ch[0]->[1],$ch[0]->[2],$ch[0]->[3],$ch[0]->[4],$ch[0]->[5],$ch[0]->[6],$ch[0]->[7],$audit_entry_cc" . " -> " . "$hostname_audit,$host_descr,$loc,$cat,$int_admin,$comentario,$utype,$audit_entry_cc_new";
	$gip->insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");
} else {
	my $audit_type="15";
	my $audit_class="1";
	my $update_type_audit="1";
	$host_descr = "---" if $host_descr eq "NULL";
	$cat = "---" if $cat eq "NULL";
	$loc = "---" if $loc eq "NULL";
	$comentario = "---" if $comentario eq "NULL";
	$utype = "---" if ! $utype;
	my $hostname_audit = $hostname;
	$hostname_audit = "---" if $hostname_audit eq "NULL";
	my $event="$ip: $hostname_audit,$host_descr,$loc,$int_admin,$cat,$comentario,$utype,$audit_entry_cc_new";
	$gip->insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");
}


$knownhosts="all" if $knownhosts eq "libre";
my $go_to_address="";
$go_to_address=$ip;

my ($host_hash_ref,$host_sort_helper_array_ref);
if ( $search_index ne "true" ) {
	($host_hash_ref,$host_sort_helper_array_ref)=$gip->get_host_hash("$client_id","$first_ip_int","$last_ip_int","$host_order_by","$knownhosts","$red_num");
} else {
	($host_hash_ref,$host_sort_helper_array_ref)=$gip->search_db_hash("$client_id","$vars_file",\%daten);
}

my $anz_host_total=$gip->get_host_hash_count("$client_id","$red_num") || "0";


if ( $anz_host_total >= $entries_per_page_hosts ) {
        my $last_ip_int_new = $first_ip_int + $start_entry_hosts + $entries_per_page_hosts - 1;
        $last_ip_int = $last_ip_int_new if $last_ip_int_new < $last_ip_int;
} else {
        $last_ip_int = ($ipob->last_int());
        $last_ip_int = $last_ip_int - 1;
}


my %anz_hosts_bm4=();
my %anz_hosts_bm6=();
%anz_hosts_bm4 = $gip->get_anz_hosts_bm_hash("$client_id","v4");
%anz_hosts_bm6 = $gip->get_anz_hosts_bm_hash("$client_id","v6");
my %anz_hosts_bm=();
if ( $ip_version eq "v4" ) {
	%anz_hosts_bm=%anz_hosts_bm4;
} else {
	%anz_hosts_bm=%anz_hosts_bm6;
}
my ($anz_values_hosts_pages, $anz_values_hosts);
if ( $search_index ne "true" ) {
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
				$gip->print_error("$client_id","<b>$go_to_address</b>: $$lang_vars{no_net_address_message} (1)");
			}
		} else {
			if ( $go_to_address_int < $first_ip_int - 1 || $go_to_address_int > $last_ip_int_red + 1 ) {
				$gip->print_error("$client_id","<b>$go_to_address</b>: $$lang_vars{no_net_address_message} (2)");
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

	} else {
		if ( $start_entry_hosts >= $anz_values_hosts_pages ) {
			$start_entry_hosts=$anz_values_hosts_pages/$entries_per_page_hosts;
			$start_entry_hosts=floor("$start_entry_hosts");
			$start_entry_hosts*= $entries_per_page_hosts;
		}
	}

	if ( $linked_ips_not_exists[0] ) {
		my $base_uri=$gip->get_base_uri();
		my $server_proto=$gip->get_server_proto();
		my $values_redes=$gip->get_redes_hash("$client_id","","return_int");
		print "<span style=\"color:red;\">$$lang_vars{aviso_message}<br>\n";
		foreach ( @linked_ips_not_exists ) {
			my $ip_version_check;
			my %anz_hosts_bm_check=();
			if ( $_ =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/ ) {
				$ip_version_check="v4";
				%anz_hosts_bm_check=%anz_hosts_bm4;
			} else {
				$ip_version_check="v6";
				%anz_hosts_bm_check=%anz_hosts_bm6;
			}
			my $linked_ip_not_exitst_int=$gip->ip_to_int("$client_id","$_","$ip_version_check");
			$linked_ip_not_exitst_int = Math::BigInt->new("$linked_ip_not_exitst_int");
			my $linked_net_found=0;
			my $red_num_linked_red;
			for my $key (sort keys %$values_redes){
				#ignore other IP version
				next if ${$values_redes}{$key}->[7] ne $ip_version_check;
				#ignore rootnets
				next if ${$values_redes}{$key}->[9] == 1;
				my $red_int=${$values_redes}{$key}->[8];
				$red_int = Math::BigInt->new("$red_int");
				my $BM_red=${$values_redes}{$key}->[1];
				$red_num_linked_red=$key;

				my $anz_values_hosts_red = $anz_hosts_bm_check{$BM_red};
				$anz_values_hosts_red =~ s/,//g;	
				my $red_broad_int=$red_int+$anz_values_hosts_red+1;
				$red_broad_int = Math::BigInt->new("$red_broad_int");
				if ( $linked_ip_not_exitst_int >= $red_int && $linked_ip_not_exitst_int <= $red_broad_int ) {
					# Network found
					$linked_net_found=1;
					last;
				} else {
					next;
				}
			}
			if ( $linked_net_found == 1 ) {
				print "$$lang_vars{ip_without_host_message}: $_ -<form method=\"POST\" action=\"$server_proto://$base_uri/res/ip_modip_form.cgi\" style=\"display:inline\"><input name=\"ip\" type=\"hidden\" value=\"$linked_ip_not_exitst_int\"><input name=\"loc\" type=\"hidden\" value=\"$loc\"><input name=\"host_exist\" type=\"hidden\" value=\"no\"><input name=\"red_num\" type=\"hidden\" value=\"$red_num_linked_red\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input name=\"ip_version\" type=\"hidden\" value=\"$ip_version_check\"><input name=\"linked_ip\" type=\"hidden\" value=\"$ip\"><input type=\"submit\" name=\"B2\" class=\"input_link_w\" value=\"$$lang_vars{add_host_message}\" style=\"cursor:pointer;\" title=\"$$lang_vars{add_host_message}\"></form><br>";

			} else {
				print "$$lang_vars{no_network_found_for_ip}: $_ - $$lang_vars{ignorado_message}<br>\n";
			}
		}
		print "</span><p>\n";
	}

	if ( $linked_ips_not_valid[0] ) {
		print "<span style=\"color:red;\">$$lang_vars{aviso_message}<br>\n";
		foreach ( @linked_ips_not_valid ) {
			print "$$lang_vars{ip_invalid_message}: $_ - $$lang_vars{ignorado_message}<br>\n";
		}
		print "</span>\n";
	}

	($host_hash_ref,$first_ip_int,$last_ip_int)=$gip->prepare_host_hash("$client_id",$host_hash_ref,"$first_ip_int","$last_ip_int","res/ip_modip_form.cgi","$knownhosts","$$lang_vars{modificar_message}","$red_num","$red_loc","$vars_file","$anz_values_hosts","$start_entry_hosts","$entries_per_page_hosts","$host_order_by","$redbroad_int","$ip_version");

	my $pages_links=$gip->get_pages_links_host("$client_id","$start_entry_hosts","$anz_values_hosts_pages","$entries_per_page_hosts","$red_num","$knownhosts","$host_order_by","$start_ip_int",$host_hash_ref,"$redbroad_int","$ip_version","$vars_file");

	$gip->PrintIpTabHead("$client_id","$knownhosts","res/ip_modip_form.cgi","$red_num","$vars_file","$start_entry_hosts","$anz_values_hosts","$entries_per_page_hosts","$pages_links","","$ip_version");

	$gip->PrintIpTab("$client_id",$host_hash_ref,"$first_ip_int","$last_ip_int","res/ip_modip_form.cgi","$knownhosts","$$lang_vars{modificar_message}","$red_num","$red_loc","$vars_file","$anz_values_hosts_pages","$start_entry_hosts","$entries_per_page_hosts","$host_order_by","$host_sort_helper_array_ref","","$ip_version","","","$host_id");

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

	if ( $linked_ips_not_exists[0] ) {
		my $base_uri=$gip->get_base_uri();
		my $server_proto=$gip->get_server_proto();
		my $values_redes=$gip->get_redes_hash("$client_id","","return_int");
		print "<span style=\"color:red;\">$$lang_vars{aviso_message}<br>\n";
		foreach ( @linked_ips_not_exists ) {
			my $ip_version_check;
			my %anz_hosts_bm_check=();
			if ( $_ =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/ ) {
				$ip_version_check="v4";
				%anz_hosts_bm_check=%anz_hosts_bm4;
			} else {
				$ip_version_check="v6";
				%anz_hosts_bm_check=%anz_hosts_bm6;
			}
			my $linked_ip_not_exitst_int=$gip->ip_to_int("$client_id","$_","$ip_version_check");
			$linked_ip_not_exitst_int = Math::BigInt->new("$linked_ip_not_exitst_int");
			my $linked_net_found=0;
			my $red_num_linked_red;
			for my $key (sort keys %$values_redes){
				#ignore other IP version
                                next if ${$values_redes}{$key}->[7] ne $ip_version_check;
				#ignore rootnets
				next if ${$values_redes}{$key}->[9] == 1;
				my $red_int=${$values_redes}{$key}->[8];
				$red_int = Math::BigInt->new("$red_int");

				next if $linked_ip_not_exitst_int < $red_int;

				my $BM_red=${$values_redes}{$key}->[1];
				$red_num_linked_red=$key;

				my $anz_values_hosts_red = $anz_hosts_bm_check{$BM_red};
				$anz_values_hosts_red =~ s/,//g;	
				my $red_broad_int=$red_int+$anz_values_hosts_red+1;
				$red_broad_int = Math::BigInt->new("$red_broad_int");
				if ( $linked_ip_not_exitst_int >= $red_int && $linked_ip_not_exitst_int <= $red_broad_int ) {
					# Network found
					$linked_net_found=1;
					last;
				} else {
					next;
				}
			}
			if ( $linked_net_found == 1 ) {
				print "$$lang_vars{ip_without_host_message}: $_ -<form method=\"POST\" action=\"$server_proto://$base_uri/res/ip_modip_form.cgi\" style=\"display:inline\"><input name=\"ip\" type=\"hidden\" value=\"$linked_ip_not_exitst_int\"><input name=\"loc\" type=\"hidden\" value=\"$loc\"><input name=\"host_exist\" type=\"hidden\" value=\"no\"><input name=\"red_num\" type=\"hidden\" value=\"$red_num_linked_red\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input name=\"ip_version\" type=\"hidden\" value=\"$ip_version_check\"><input name=\"linked_ip\" type=\"hidden\" value=\"$ip\"><input type=\"submit\" name=\"B2\" class=\"input_link_w\" value=\"$$lang_vars{add_host_message}\" style=\"cursor:pointer;\" title=\"$$lang_vars{add_host_message}\"></form><br>";

			} else {
				print "$$lang_vars{no_network_found_for_ip}: $_ - $$lang_vars{ignorado_message}<br>\n";
			}
		}
		print "</span>\n";
	}

	if ( $linked_ips_not_valid[0] ) {
		print "<span style=\"color:red;\">$$lang_vars{aviso_message}<br>\n";
		foreach ( @linked_ips_not_valid ) {
			print "$$lang_vars{ip_invalid_message}: $_ - $$lang_vars{ignorado_message}<br>\n";
		}
		print "</span>\n";
	}

	$gip->PrintIpTab("$client_id",$host_hash_ref,"$first_ip_int","$last_ip_int","res/ip_modip_form.cgi","$knownhosts","$$lang_vars{modificar_message}","$red_num","$red_loc","$vars_file","$anz_values_hosts","$start_entry_hosts","$entries_per_page_hosts","$host_order_by",$host_sort_helper_array_ref,"$client_independent","$ip_version","$search_index","$search_hostname","$host_id");
}


$gip->print_end("$client_id","$vars_file","go_to_top");
