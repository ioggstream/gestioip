#!/usr/bin/perl -w -T

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
use Net::IP qw(:PROC);
use Cwd;
use File::Find;
use File::stat;

my $daten=<STDIN>;
my $gip = GestioIP -> new();
my %daten=$gip->preparer($daten);

my $base_uri = $gip->get_base_uri();

my ($lang_vars,$vars_file,$entries_per_page);
my $server_proto=$gip->get_server_proto();

my $lang = $daten{'lang'} || "";
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

my $ip_version = $daten{'ip_version'} || "v4";
my $export_ipv4=$daten{'ipv4'} || "";
$export_ipv4="v4" if $export_ipv4;
my $export_ipv6=$daten{'ipv6'} || "";
$export_ipv6="v6" if $export_ipv6;

#$entries_per_page="unlimited";

if ( $daten{'export_radio'} !~ /^(all|match|network|host_search|red_search|vlans_match)$/ ) {
	$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{export_message}","$vars_file");
	$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (2)");
}

my $match;
if ( $daten{'export_match'} && $daten{'export_radio'} !~ /(all|network|host_search|red_search)/ ) {
	if ( length($daten{export_match}) == 1 ) {
		$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{export_message}","$vars_file");
		$gip->print_error("$client_id","$$lang_vars{dos_signos_message} (1)");
	} else {
		$match=$daten{'export_match'};
	}
}
	

if ( $daten{'export_type'} ) {
	if ( $daten{export_type} !~ /^(net|host|host_search|red_search|vlans)$/ ) {
		$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{export_message}","$vars_file");
		$gip->print_error("$client_id","$$lang_vars{dos_signos_message} (2)");
	}
}


$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{export_message}","$vars_file");

my $align="align=\"right\"";
my $align1="";
my $ori="left";
my $rtl_helper="<font color=\"white\">x</font>";
if ( $vars_file =~ /vars_he$/ ) {
	$align="align=\"left\"";
	$align1="align=\"right\"";
	$ori="right";
}

if ( $daten{'network_match'} && $daten{'export_radio'} =~ /network/ ) {
		my $valid_v6=$gip->check_valid_ipv6("$daten{'network_match'}") || "0";
		$gip->print_error("$client_id",$$lang_vars{formato_red_malo_message}) if $daten{'network_match'} !~ /^\d{1,3}\.\d{1,3}\.\d{1,3}.\d{1,3}$/ && $valid_v6 != "1" ;
}

my $tipo_ele = $daten{'tipo_ele'} || "NULL";
my $loc_ele = $daten{'loc_ele'} || "NULL";
my $start_entry=$daten{'start_entry'} || '0';
$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (3)") if $start_entry !~ /^\d{1,4}$/;
my $referer=$daten{'referer'};

my $tipo_ele_id=$gip->get_cat_net_id("$client_id","$tipo_ele") || "-1";
my $loc_ele_id=$gip->get_loc_id("$client_id","$loc_ele") || "-1";



my @ip;

my $i=0;
my $j=1;
my @csv_strings;
my $from_net;
my $hosts_found = "0";
if ( $daten{'export_type'} eq "net" ) {

	$gip->print_error("$client_id","$$lang_vars{radio_match_string_export_message}") if ( $daten{'export_radio'} eq "all" && $daten{'export_match'} );
	$gip->print_error("$client_id","$$lang_vars{introduce_export_match_string_message}") if ( $daten{'export_radio'} eq "match" && ! $daten{'export_match'} );

	my @cc_values=$gip->get_custom_columns("$client_id");
	my %cc_values=$gip->get_custom_column_values_red("$client_id");
	if ( $daten{'export_radio'} eq "all" ) {
		if ( $export_ipv4 && ! $export_ipv6 ) {
			@ip=$gip->get_redes("$client_id","$tipo_ele_id","$loc_ele_id","$start_entry","$entries_per_page","red_auf","$export_ipv4");
		} elsif ( ! $export_ipv4 && $export_ipv6 ) {
			@ip=$gip->get_redes("$client_id","$tipo_ele_id","$loc_ele_id","$start_entry","$entries_per_page","red_auf","$export_ipv6");
		} else {
			@ip=$gip->get_redes("$client_id","$tipo_ele_id","$loc_ele_id","$start_entry","$entries_per_page","red_auf");
		}
	} elsif ( $daten{'export_radio'} eq "net_search" ) {
	} else {
		if ( $export_ipv4 && ! $export_ipv6 ) {
			@ip=$gip->get_redes_match("$client_id","$match","$export_ipv4");
			$gip->print_error("$client_id","$$lang_vars{no_matching_network_message}") if ! $ip[0];
		} elsif ( ! $export_ipv4 && $export_ipv6 ) {
			@ip=$gip->get_redes_match("$client_id","$match","$export_ipv6");
			$gip->print_error("$client_id","$$lang_vars{no_matching_network_message}") if ! $ip[0];
		} else {
			@ip=$gip->get_redes_match("$client_id","$match");
			$gip->print_error("$client_id","$$lang_vars{no_matching_network_message}") if ! $ip[0];
		}
	}
	$csv_strings[0]="$$lang_vars{redes_message},BM,$$lang_vars{description_message},$$lang_vars{loc_message},$$lang_vars{cat_message},$$lang_vars{comentario_message},$$lang_vars{is_rootnet_message}";
	for ( my $k = 0; $k < scalar(@cc_values); $k++ ) {
		$csv_strings[0] .= "," . $cc_values[$k]->[0];
	}
	$csv_strings[0] .= "\n";
	foreach (@ip) {
		my $ip=$ip[$i]->[0];
		my $BM=$ip[$i]->[1];
		my $descr=$ip[$i]->[2] || "";
		my $loc=$ip[$i]->[4] || "";
		my $vigilada=$ip[$i]->[5] || "n";
		my $comentario=$ip[$i]->[6] || "";
		my $cat=$ip[$i]->[7] || "";
		my $is_rootnet=$ip[$i]->[10] || "";
		
		$descr =~ s/,//g;
		$descr =~ s/\n//g;
		if ( $descr =~ /"/ ) {
			$descr =~ s/"/""/g;
			$descr = '"' . $descr . '"';
		}
		$descr="" if $descr eq "NULL";
		$loc =~ s/,//g;
		if ( $loc =~ /"/ ) {
			$loc =~ s/"/""/g;
			$loc = '"' . $loc . '"';
		}
		$loc="" if $loc eq "NULL";
		$comentario =~ s/,//g;
		$comentario =~ s/\n//g;
		if ( $comentario =~ /"/ ) {
			$comentario =~ s/"/""/g;
			$comentario = '"' . $comentario . '"';
		}
		$comentario="" if $comentario eq "NULL";
		$cat =~ s/,//g;
		if ( $cat =~ /"/ ) {
			$cat =~ s/"/""/g;
			$cat = '"' . $cat . '"';
		}
		$cat="" if $cat eq "NULL";
		$is_rootnet="" if $is_rootnet eq 0;
		$is_rootnet="yes" if $is_rootnet eq 1;
		$csv_strings[$j]="$ip,$BM,$descr,$loc,$cat,$comentario,$is_rootnet";

		for ( my $k = 0; $k < scalar(@cc_values); $k++ ) {
			if ( $cc_values{"$cc_values[$k]->[1]_$ip[$i]->[3]"} ) {
				$cc_values{"$cc_values[$k]->[1]_$ip[$i]->[3]"} =~ s/\n//g;
				$csv_strings[$j] .= "," . $cc_values{"$cc_values[$k]->[1]_$ip[$i]->[3]"};
			} else {
				$csv_strings[$j] .= ",,";
			}
		}
		$csv_strings[$j] .= "\n";
		$i++;
		$j++;
	}
} elsif ( $daten{'export_type'} eq "host" ) {
## HOSTS

	$gip->print_error("$client_id","$$lang_vars{radio_match_string_export_host_message}") if ( $daten{'export_radio'} eq "all" && $daten{'export_match'} );
	$gip->print_error("$client_id","$$lang_vars{radio_match_string_export_host_message}") if ( $daten{'export_radio'} eq "all" && $daten{'network_match'} );
	$gip->print_error("$client_id","$$lang_vars{introduce_export_match_host_string_message}") if ( $daten{'export_radio'} eq "match" && ! $daten{'export_match'} );
	$gip->print_error("$client_id","$$lang_vars{introduce_export_match_host_network_string_message}") if ( $daten{'export_radio'} eq "network" && ! $daten{'network_match'} );

	my @cc_values=$gip->get_custom_host_columns("$client_id");
	my %cc_values=$gip->get_custom_host_column_values_host_hash("$client_id");

	my @hosts;
	if ( $daten{'export_radio'} eq "network" ) {
		$from_net = $daten{'network_match'};
		my $valid_v6 = $gip->check_valid_ipv6("$from_net") || "0";
		if ( $valid_v6 == "1" ) {
			$from_net = ip_expand_address ($from_net,6);
		}

		my $from_net_num = $gip->get_red_num_from_red_ip("$client_id","$from_net") or $gip->print_error("$client_id","$$lang_vars{red_no_existe_message}: $from_net");
		$ip[0]->[3] = $from_net_num;
		$match = "";
	} else {
		if ( $export_ipv4 && ! $export_ipv6 ) {
			@ip=$gip->get_redes("$client_id","$tipo_ele_id","$loc_ele_id","$start_entry","$entries_per_page","red_auf","$export_ipv4");
		} elsif ( ! $export_ipv4 && $export_ipv6 ) {
			@ip=$gip->get_redes("$client_id","$tipo_ele_id","$loc_ele_id","$start_entry","$entries_per_page","red_auf","$export_ipv6");
		} else {
			@ip=$gip->get_redes("$client_id","$tipo_ele_id","$loc_ele_id","$start_entry","$entries_per_page","red_auf");
		}
	}
	$csv_strings[0]="IP,$$lang_vars{hostname_message},$$lang_vars{description_message},$$lang_vars{loc_message},$$lang_vars{tipo_message},AI,$$lang_vars{comentario_message},$$lang_vars{redes_message},BM";
	for ( my $k = 0; $k < scalar(@cc_values); $k++ ) {
		$csv_strings[0] .= "," . $cc_values[$k]->[0];
	}
	$csv_strings[0] .= "\n";

	my $i = "0";
	foreach (@ip) {
		my $red = $ip[$i]->[0];
		my $BM = $ip[$i]->[1];
		my $red_num = $ip[$i]->[3];
		next if ! $red_num;
		my $k=0;
		if ( $daten{'export_radio'} eq "all" ) {
			if ( $export_ipv4 && ! $export_ipv6 ) {
				@hosts=$gip->get_host_from_red_id_ntoa("$client_id","$red_num","","$export_ipv4");
			} elsif ( ! $export_ipv4 && $export_ipv6 ) {
				@hosts=$gip->get_host_from_red_id_ntoa("$client_id","$red_num","","$export_ipv6");
			} else {
				@hosts=$gip->get_host_from_red_id_ntoa("$client_id","$red_num");
			}
			$hosts_found = "1" if $hosts[0];
		} else {
			if ( $export_ipv4 && ! $export_ipv6 ) {
				@hosts=$gip->get_host_from_red_id_ntoa("$client_id","$red_num","$match","$export_ipv4");
			} elsif ( ! $export_ipv4 && $export_ipv6 ) {
				@hosts=$gip->get_host_from_red_id_ntoa("$client_id","$red_num","$match","$export_ipv6");
			} else {
				@hosts=$gip->get_host_from_red_id_ntoa("$client_id","$red_num","$match");
			}
			$hosts_found = "1" if $hosts[0];
		}
		foreach ( @hosts ) {
			my $ip_version_host=$hosts[$k]->[12];
			my $ip;
			if ( $ip_version_host eq "v4" ) {	
				$ip=$hosts[$k]->[0];
			} else {
				my $ip_int=$hosts[$k]->[13];
				$ip=$gip->int_to_ip("$ip_int","$ip_version_host");
			}
			my $hostname=$hosts[$k]->[1];
			if  ( ! $hostname || $hostname eq "NULL" ) {
				$i++;
				next;
			}
			my $descr=$hosts[$k]->[2] || "NULL";;
			my $loc=$hosts[$k]->[3] || "NULL";
			my $cat=$hosts[$k]->[4] || "NULL";
			my $int_admin=$hosts[$k]->[5] || "n";
			my $comentario=$hosts[$k]->[6] || "NULL";

			$hostname =~ s/,//g;
			if ( $hostname =~ /"/ ) {
				$hostname =~ s/"/""/g;
				$hostname = '"' . $hostname . '"';
			}

			$descr =~ s/,//g;
			$descr =~ s/\n//g;
			if ( $descr =~ /"/ ) {
				$descr =~ s/"/""/g;
				$descr = '"' . $descr . '"';
			}
			$descr="" if $descr eq "NULL";

			$loc =~ s/,//g;
			if ( $loc =~ /"/ ) {
				$loc =~ s/"/""/g;
				$loc = '"' . $loc . '"';
			}
			$loc="" if $loc eq "NULL";

			$int_admin = "n" if $int_admin ne "y";

			$cat =~ s/,//g;
			if ( $cat =~ /"/ ) {
				$cat =~ s/"/""/g;
				$cat = '"' . $cat . '"';
			}
			$cat="" if $cat eq "NULL";

			$comentario =~ s/,//g;
			$comentario =~ s/\n//g;
			if ( $comentario =~ /"/ ) {
				$comentario =~ s/"/""/g;
				$comentario = '"' . $comentario . '"';
			}
			$comentario="" if $comentario eq "NULL";

			$csv_strings[$j]="$ip,$hostname,$descr,$loc,$cat,$int_admin,$comentario,$red,$BM";

			for ( my $l = 0; $l < scalar(@cc_values); $l++ ) {
				if ( $cc_values{"$cc_values[$l]->[1]_$hosts[$k]->[11]"}[0] ) {
					$cc_values{"$cc_values[$l]->[1]_$hosts[$k]->[11]"}[0] =~ s/\n//;
					$cc_values{"$cc_values[$l]->[1]_$hosts[$k]->[11]"}[0] =~ s/,/;/g if $cc_values{"$cc_values[$l]->[1]_$hosts[$k]->[11]"}[0] =~ /.*::.*:\/\//;
					$csv_strings[$j] .= "," . $cc_values{"$cc_values[$l]->[1]_$hosts[$k]->[11]"}[0];
				} else {
# TEST CHECKEN OB , ODER ,,		$csv_strings[$j] .= ",,";
					$csv_strings[$j] .= ",";
				}
			}
			$csv_strings[$j] .= "\n";

			$k++;
			$j++;
		}
		$i++;
	}
	if ( $daten{'export_radio'} eq "network" ) {
		$gip->print_error("$client_id","<b>$daten{'network_match'}</b>: $$lang_vars{network_does_not_contain_entries_message}") if $hosts_found != "1";
	} elsif ( $daten{'export_radio'} eq "all" ) {
		$gip->print_error("$client_id","$$lang_vars{no_hosts_found_message}") if $hosts_found != "1";
	} else {
		$gip->print_error("$client_id","$$lang_vars{no_matching_hosts_message}") if $hosts_found != "1";
	}
} elsif ( $daten{'export_type'} eq "host_search" ) {
#	$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (4)") if ! $daten{'search_string'};
	my @cc_values=$gip->get_custom_host_columns("$client_id");
	my %cc_values=$gip->get_custom_host_column_values_host_hash("$client_id");

	$csv_strings[0]="IP,$$lang_vars{hostname_message},$$lang_vars{description_message},$$lang_vars{loc_message},$$lang_vars{tipo_message},AI,$$lang_vars{comentario_message}";
	for ( my $k = 0; $k < scalar(@cc_values); $k++ ) {
		$csv_strings[0] .= "," . $cc_values[$k]->[0];
	}
	$csv_strings[0] .= "\n";

	my ($ip_hash,$host_sort_helper_array_ref)=$gip->search_db_hash("$client_id","$vars_file",\%daten);

	my $sort_order_ref = sub {
		lc ${a} cmp lc ${b};
	};
	my $j="1";
	foreach my $keys ( sort $sort_order_ref keys %{$ip_hash} ) {
		my $ip = $ip_hash->{$keys}[0];
		my $hostname = $ip_hash->{$keys}[1] || "";
		my $descr = $ip_hash->{$keys}[2] || "";
		$descr = "" if $descr eq "NULL";
		$descr =~ s/,//g;
		$descr =~ s/\n//g;
		my $loc = $ip_hash->{$keys}[3];
		$loc = "" if ! $loc || $loc eq "NULL";
		my $cat = $ip_hash->{$keys}[4];
		$cat = "" if $cat eq "NULL";
		my $int_admin = $ip_hash->{$keys}[5] || "";
		$int_admin = "n" if $int_admin ne "0";
		my $comentario = $ip_hash->{$keys}[6] || "";
		$comentario =~ s/\n//g;
		$comentario =~ s/,//g;
		$comentario = "" if $comentario eq "NULL";
		my $id = $ip_hash->{$keys}[12];
		
		$csv_strings[$j]="$ip,$hostname,$descr,$loc,$cat,$int_admin,$comentario";

		for ( my $l = 0; $l < scalar(@cc_values); $l++ ) {
			if ( $cc_values{"$cc_values[$l]->[1]_${id}"}[0] ) {
				$cc_values{"$cc_values[$l]->[1]_${id}"}[0] =~ s/\n//;
				$cc_values{"$cc_values[$l]->[1]_${id}"}[0] =~ s/,/;/g if $cc_values{"$cc_values[$l]->[1]_${id}"}[0] =~ /.*::.*:\/\/.*,/;
				$csv_strings[$j] .= "," . $cc_values{"$cc_values[$l]->[1]_${id}"}[0];
			} else {
				$csv_strings[$j] .= ",";
			}
		}
		$csv_strings[$j] .= "\n";
		$j++;	
	}
} elsif ( $daten{'export_type'} eq "red_search" ) {
#	$gip->print_error("$client_id","$$lang_vars{introduce_export_match_string_message}") if ( $daten{'export_radio'} eq "match" && ! $daten{'export_match'} );

	my @cc_values=$gip->get_custom_columns("$client_id");
	my %cc_values=$gip->get_custom_column_values_red("$client_id");
	my ( @ip ) = $gip->search_db_red("$client_id","$vars_file",\%daten);
	$csv_strings[0]="$$lang_vars{redes_message},BM,$$lang_vars{description_message},$$lang_vars{loc_message},$$lang_vars{cat_message},$$lang_vars{comentario_message}";
	for ( my $k = 0; $k < scalar(@cc_values); $k++ ) {
		$csv_strings[0] .= "," . $cc_values[$k]->[0];
	}
	$csv_strings[0] .= "\n";
	foreach (@ip) {
		my $ip=$ip[$i]->[0];
		my $BM=$ip[$i]->[1];
		my $descr=$ip[$i]->[2] || "";
		my $loc=$ip[$i]->[4] || "";
		my $vigilada=$ip[$i]->[5] || "n";
		my $comentario=$ip[$i]->[6] || "";
		my $cat=$ip[$i]->[7] || "";
		
		$descr =~ s/,//g;
		$descr =~ s/\n//g;
		if ( $descr =~ /"/ ) {
			$descr =~ s/"/""/g;
			$descr = '"' . $descr . '"';
		}
		$descr="" if $descr eq "NULL";
		$loc =~ s/,//g;
		if ( $loc =~ /"/ ) {
			$loc =~ s/"/""/g;
			$loc = '"' . $loc . '"';
		}
		$loc="" if $loc eq "NULL";
		$comentario =~ s/,//g;
		$comentario =~ s/\n//g;
		if ( $comentario =~ /"/ ) {
			$comentario =~ s/"/""/g;
			$comentario = '"' . $comentario . '"';
		}
		$comentario="" if $comentario eq "NULL";
		$cat =~ s/,//g;
		if ( $cat =~ /"/ ) {
			$cat =~ s/"/""/g;
			$cat = '"' . $cat . '"';
		}
		$cat="" if $cat eq "NULL";
		$csv_strings[$j]="$ip,$BM,$descr,$loc,$cat,$comentario";

		for ( my $k = 0; $k < scalar(@cc_values); $k++ ) {
			if ( $cc_values{"$cc_values[$k]->[1]_$ip[$i]->[3]"} ) {
				$cc_values{"$cc_values[$k]->[1]_$ip[$i]->[3]"} =~ s/\n//g;
				$csv_strings[$j] .= "," . $cc_values{"$cc_values[$k]->[1]_$ip[$i]->[3]"};
			} else {
				$csv_strings[$j] .= ",";
			}
		}

		$csv_strings[$j] .= "\n";
		$i++;
		$j++;
	}
} elsif ( $daten{'export_type'} eq "vlans" ) {
##VLANs
	$gip->print_error("$client_id","$$lang_vars{radio_match_string_export_message}") if ( $daten{'export_radio'} eq "all" && $daten{'vlans_match'} );
	$gip->print_error("$client_id","$$lang_vars{introduce_export_match_vlan_string_message}") if ( $daten{'export_radio'} eq "match" && ! $daten{'export_match'} );

	my @vlans = ();
	if ( $match && $daten{'export_radio'} eq "vlans_match" ) {
		@vlans = $gip->get_vlans_match("$client_id","$match");
	} else {
		@vlans = $gip->get_vlans("$client_id");
	}

	$csv_strings[0]="$$lang_vars{vlan_number_message},$$lang_vars{vlan_name_message},$$lang_vars{comentario_message}\n";

	my $i=1;
	foreach (@vlans) {
		if ( ! $_->[1] || ! $_->[2] ) {
			next;
		}
		my $vlan_num = $_->[1];
		my $vlan_name = $_->[2];
		my $vlan_comment = $_->[3] || "";
		$vlan_comment =~ s/,//g;
		$vlan_comment =~ s/\n//g;
		$csv_strings[$i]="$vlan_num,$vlan_name,$vlan_comment";
		$csv_strings[$i] .= "\n";
		$i++;
	}
}

my $export_dir = getcwd;
$export_dir =~ s/res.*/export/;

$export_dir =~ /^([\w.\/]+)$/;

# delete old files
my $found_file;
sub findfile {
	$found_file = $File::Find::name if ! -d;
	if ( $found_file ) {
		$found_file =~ /^(.*)$/;
		$found_file = $1;
		my $filetime = stat($found_file)->mtime;
		my $checktime=time();
		$checktime = $checktime - 3600;
		if ( $filetime < $checktime ) {
			unlink($found_file);
		}
	}
}

find( {wanted=>\&findfile,no_chdir=>1},$export_dir);

my $mydatetime=time();
my $csv_file_name;
if ( $daten{'export_type'} eq "net" || $daten{'export_type'} eq "red_search" ) {
	$csv_file_name="$mydatetime.networks.csv";
} elsif ( $daten{'export_type'} eq "host" || $daten{'export_type'} eq "host_search" ) {
	$csv_file_name="$mydatetime.hosts.csv";
} elsif ( $daten{'export_type'} eq "vlans" ) {
	$csv_file_name="$mydatetime.vlans.csv";
}
my $csv_file="../export/$csv_file_name";

open(EXPORT,">$csv_file") or $gip->print_error("$client_id","$!"); 

foreach ( @csv_strings ) {
	print EXPORT "$_";
}

close EXPORT;

print "<p><b style=\"float: $ori\">$$lang_vars{export_successful_message}</b><br><p>\n";
print "<p><span style=\"float: $ori\"><a href=\"$server_proto://$base_uri/export/$csv_file_name\">$$lang_vars{download_csv_file}</a></span><p>\n";

my ($audit_type,$event);
if ( $daten{'export_type'} eq "net" ) {
	$audit_type="29";
	if ( $daten{'export_radio'} eq "all" ) {
		$event="$$lang_vars{all_networks_message}";
	} else {
		$event="$$lang_vars{export_net_match_message}: $match";
	}
} else {
	$audit_type="30";
	if ( $daten{'export_radio'} eq "all" ) {
		$event="$$lang_vars{all_hosts_message}";
	} elsif ( $daten{'export_radio'} eq "network" ) {
		if ( $hosts_found == "1" ) {
			$event="$$lang_vars{export_host_network_message}: $from_net";
		} else {
			$event = "";
		}
	} else {
		if ( $hosts_found == "1" ) {
			$event="$$lang_vars{export_host_match_message}: $match";
		} else {
			$event = "";
		}
	}
}

my $audit_class="5";
my $update_type_audit="1";
if ( $daten{'export_type'} eq "net" || $hosts_found == "1" ) {
	$gip->insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");
}


$gip->print_end("$client_id");
