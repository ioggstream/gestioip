#!/usr/bin/perl -w


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
use Net::Ping::External qw(ping);
use Net::IP;
use Net::IP qw(:PROC);
use Parallel::ForkManager;
use lib './modules';
use GestioIP;
use Math::BigInt;

my $daten=<STDIN>;
my $gip = GestioIP -> new();
my %daten=$gip->preparer($daten) if $daten;

my $lang = $daten{'lang'} || "";
my ($lang_vars,$vars_file)=$gip->get_lang("","$lang");
my $base_uri = $gip->get_base_uri();

my $client_id = $daten{'client_id'} || $gip->get_first_client_id();
my $server_proto=$gip->get_server_proto();
my $ip_version = $daten{'ip_version'} || "";


if ( $client_id !~ /^\d{1,4}$/ ) {
        $client_id = 1;
        $gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{redes_message}","$vars_file");
        $gip->print_error("$client_id","$$lang_vars{formato_malo_message} (1)");
}

if ( $ip_version !~ /^(v4|v6)$/ ) {
        $client_id = 1;
        $gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{redes_message}","$vars_file");
	$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (2)");
}


### PING HISTORY PATCH to add ping status changes to host history####
### require new event_type: INSERT INTO event_types (id,event_type) VALUES (100,"ping status changed");
### disabled 0; enabled 1;
my $enable_ping_history=0;
my $update_type_audit="6";


my @config = $gip->get_config("$client_id");
my $max_procs = $config[0]->[1] || "254";
my $ping_timeout = $config[0]->[6] || "2";

my $red_num=$daten{'red_num'} || "";
my $first_ip_int_ping=$daten{'first_ip_int_ping'} || "";
my $last_ip_int_ping=$daten{'last_ip_int_ping'} || "";
my $view=$daten{'view'} || "";

if ( $red_num !~ /^\d{1,5}$/ ) {
	$gip->print_init("gestioip","$$lang_vars{redes_message}","$$lang_vars{redes_message}","$vars_file","$client_id");
	$gip->print_error("$client_id",$$lang_vars{formato_red_malo_message}) ;
}
if ( $first_ip_int_ping && $first_ip_int_ping !~ /^\d{6,50}$/ ) {
	$gip->print_init("gestioip","$$lang_vars{redes_message}","$$lang_vars{redes_message}","$vars_file","$client_id");
	$gip->print_error("$client_id","$$lang_vars{formato_malo_message} $first_ip_int_ping") ;
}
if ( $last_ip_int_ping && $last_ip_int_ping !~ /^\d{6,50}$/ ) {
	$gip->print_init("gestioip","$$lang_vars{redes_message}","$$lang_vars{redes_message}","$vars_file","$client_id");
	$gip->print_error("$client_id","$$lang_vars{formato_malo_message} $last_ip_int_ping") ;
}

my @values_redes = $gip->get_red("$client_id","$red_num");

my $red = "$values_redes[0]->[0]" || "";
my $BM = "$values_redes[0]->[1]" || "";
my $descr = "$values_redes[0]->[2]" || "";
my $cat_id = "$values_redes[0]->[6]" || "";
my $cat = $gip->get_cat_net_from_id("$client_id","$cat_id");
$cat = "NULL" if ! $cat;
$cat = "$cat - " if $cat;
$cat = "" if ( $cat =~ /NULL\s-\s/ );
$descr = "---" if ( $descr eq "NULL" );
my $redob = "$red/$BM";
my $red_compressed=$red;
$red_compressed=ip_compress_address ($red, 6) if $ip_version eq "v6";

$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{redes_message} $red/$BM - $cat $descr","$vars_file");

$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (1)") if $ip_version !~ /^(v4|v6)$/;

$descr =~ s/^((\xC2\xA1|\xC2\xA2|\xC2\xA3|\xC2\xA4|\xC2\xA5|\xC2\xA6|\xC2\xA7|\xC2\xA8|\xC2\xA9|\xC2\xAA|\xC2\xAB|\xC2|\xC2\xAD|\xC2\xAE|\xC2\xAF|\xC2\xB0|\xC2\xB1|\xC2\xB2|\xC2\xB3|\xC2\xB4|\xC2\xB5|\xC2\xB6|\xC2\xB7|\xC2\xB8|\xC2\xB9|\xC2\xBA|\xC2\xBB|\xC2\xBC|\xC2\xBD|\xC2\xBE|\xC2\xBF|\xC3\x80|\xC3\x81|\xC3\x82|\xC3\x83|\xC3\x84|\xC3\x85|\xC3\x86|\xC3\x87|\xC3\x88|\xC3\x89|\xC3\x8A|\xC3\x8B|\xC3\x8C|\xC3\x8D|\xC3\x8E|\xC3\x8F|\xC3\x90|\xC3\x91|\xC3\x92|\xC3\x93|\xC3\x94|\xC3\x95|\xC3\x96|\xC3\x97|\xC3\x98|\xC3\x99|\xC3\x9A|\xC3\x9B|\xC3\x9C|\xC3\x9D|\xC3\x9E|\xC3\x9F|\xC3\xA0|\xC3\xA1|\xC3\xA2|\xC3\xA3|\xC3\xA4|\xC3\xA5|\xC3\xA6|\xC3\xA7|\xC3\xA8|\xC3\xA9|\xC3\xAA|\xC3\xAB|\xC3\xAC|\xC3\xAD|\xC3\xAE|\xC3\xAF|\xC3\xB0|\xC3\xB1|\xC3\xB2|\xC3\xB3|\xC3\xB4|\xC3\xB5|\xC3\xB6|\xC3\xB7|\xC3\xB8|\xC3\xB9|\xC3\xBA|\xC3\xBB|\xC3\xBC|\xC3\xBD|\xC3\xBE|\xC3\xBF|\xe2\x82\xac|\xc5\x92|\xc5\x93|\xc5\xa0|\xc5\xa1|\xc5\xb8|\xc6\x92|\w|\?|_|\.|,|:|\-|\@|\(|\/|\[|\]|{|}|\||~|\+|\n|\r|\f|\t|\s){15})(.*)/$1/;
$descr = "$descr" . "..." if $2;


my $ipob = new Net::IP ($redob) || $gip->print_error("$client_id","Can't create ip object: $!\n");
my $redint=($ipob->intip());
$redint = Math::BigInt->new("$redint");
my $first_ip_int = $redint + 1;
$first_ip_int = Math::BigInt->new("$first_ip_int");
my $last_ip_int = ($ipob->last_int());
$last_ip_int = Math::BigInt->new("$last_ip_int");
$last_ip_int = $last_ip_int - 1;
my $anz_ip=($ipob->size());
my $ip_total=$anz_ip - 2;

if ( $ip_version eq "v6" ) {
	$first_ip_int--;
	$last_ip_int++;
	$ip_total += 2;
}


my $knownhosts = $daten{'knownhosts'} || "all";

my @values_categorias=$gip->get_cat("$client_id");
my $red_loc = $gip->get_loc_from_redid("$client_id","$red_num");
my @ip=$gip->get_host("$client_id","$first_ip_int","$last_ip_int","$red_num");

#my @unasigned_alive_hosts;
my %unasigned_alive_hosts;
my @export_result=();
if ( $first_ip_int_ping && $last_ip_int_ping ) {

	my $j=0;
	my $hostname;
	my ( $ip_ad, $pm, $pid, $ip );
	my ( %res_sub, %res, %result);

	my $MAX_PROCESSES=$max_procs || "254";
	$pm = new Parallel::ForkManager($MAX_PROCESSES);

	$pm->run_on_finish(
		sub { my ($pid, $exit_code, $ident) = @_;
			$res_sub{$pid}=$exit_code;
		}
	);
	$pm->run_on_start(
		sub { my ($pid,$ident)=@_;
			$res{$pid}="$ident";
		}
	);

	for (my $i = $first_ip_int; $i <= $last_ip_int; $i++) {
	my $exit;
	$ip_ad=$gip->int_to_ip("$client_id","$i","$ip_version");
		
			##fork
			$pid = $pm->start("$ip_ad") and next;
				#child
#				my $p = ping(host => "$ip_ad", timeout => $ping_timeout);
				my $p="";
				if ( $ip_version eq "v4" ) {
					$p = ping(host => "$ip_ad", timeout => $ping_timeout);
				} else {
					my $command='ping6 -c 1 ' .  $ip_ad;
					my $result=$gip->ping6_system("$command","0");
					$p=1 if $result == "0";
				}

				if ( $p ) {
					$exit=0;
				} else {
					$exit=1;
				}
			$pm->finish($exit); # Terminates the child process

	}

	$pm->wait_all_children;


	while (($pid,$ip) = each ( %res )) {
		$result{$ip}=$res_sub{$pid};
	}


	my $k = 0;
	my $m = 0;
	my $l = 0;
	for (my $i = $first_ip_int; $i <= $last_ip_int; $i++) {

		$ip_ad = $gip->int_to_ip("$client_id","$i","$ip_version");
		my $exit=$result{$ip_ad}; 
		my $ping_result=0;
		$ping_result=1 if $exit == "0";

		$export_result[$l++]="$ip_ad,$ping_result";

		if ( $ip[$k]->[0] && $ip[$k]->[1] =~ /.+/ ) {
			if ( $ip[$k]->[0] == "$i" ) {
#				$gip->update_host_ping_info("$client_id","$i","$ping_result");
				$gip->update_host_ping_info("$client_id","$i","$ping_result","$enable_ping_history","$ip_ad","$update_type_audit","$vars_file");
				$k++;
			} else {
				if ( $ping_result == "1" ) {
					$unasigned_alive_hosts{$i}="alive";
					$m++;
				}
			}
		} elsif ( $ip[$k]->[0] && $ip[$k]->[1] !~ /.+/ && $ip[$k]->[10] != "-1" ) {
			$k++;
			if ( $ping_result == "1" ) {
				$unasigned_alive_hosts{$i}="alive";
				$m++;
			}
		} else {
			if ( $ping_result == "1" ) {
				$unasigned_alive_hosts{$i}="alive";
				$m++;
			}
		}
	}
}


my ($percent_ocu,$percent_free,$ocu_color) = $gip->get_red_ocu("$client_id",$red_num,$ip_total);
my $ip_ocu=$gip->count_host_entries("$client_id","$red_num");
my $free=$ip_total-$ip_ocu;

my $mask_bin = ip_get_mask ($BM,4);
my $mask = ip_bintoip ($mask_bin,4);

@ip=$gip->get_host("$client_id","$first_ip_int","$last_ip_int","$red_num");



print "<table border=\"0\" width=\"100%\">";

if ( $view eq "short" ) {
	print "<tr><td><b>$$lang_vars{libre_message}:</b> <font color=\"$ocu_color\"><b>$free ($percent_free)</b></font> | <b>$$lang_vars{ocupadas_message}</b>: <font color=\"$ocu_color\"><b>$ip_ocu ($percent_ocu)</b></font> | <b>$$lang_vars{todas_message}</b>: <b>$ip_total</b></td><td align=\"left\"><form method=\"POST\" action=\"$server_proto://$base_uri/ip_show_red_overview.cgi\" style=\"display:inline\"><input name=\"first_ip_int_ping\" type=\"hidden\" value=\"$first_ip_int\"><input name=\"last_ip_int_ping\" type=\"hidden\" value=\"$last_ip_int\"><input name=\"red_num\" type=\"hidden\" value=\"$red_num\"><input type=\"hidden\" name=\"view\" value=\"short\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"hidden\" name=\"ip_version\" value=\"$ip_version\"><input type=\"submit\" value=\"$$lang_vars{check_all_message}\" name=\"B2\" class=\"input_link_w\"></form></td><td align=\"right\"><form method=\"POST\" action=\"$server_proto://$base_uri/ip_show.cgi\" style=\"display:inline\"><input name=\"red_num\" type=\"hidden\" value=\"$red_num\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"hidden\" name=\"ip_version\" value=\"$ip_version\"><input type=\"submit\" class=\"detailed_view_button\" value=\"\" title=\"$$lang_vars{vista_detallada_message}\"name=\"B1\"></form><form method=\"POST\" action=\"$server_proto://$base_uri/ip_show_red_overview.cgi\" style=\"display:inline\"><input type=\"hidden\" name=\"view\" value=\"long\"><input name=\"red_num\" type=\"hidden\" value=\"$red_num\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"hidden\" name=\"ip_version\" value=\"$ip_version\"><input type=\"submit\" class=\"long_view_button\" value=\"\" title=\"$$lang_vars{vista_larga_message}\"name=\"B1\"></form></td></tr>\n";
print "</table>\n";

print <<EOF;
<script language="JavaScript" type="text/javascript" charset="utf-8">
<!--
function checkhost(IP,HOSTNAME,CLIENT_ID,IP_VERSION)
{
var opciones="toolbar=no,right=100,top=100,width=500,height=300", i=0;
var URL="$server_proto://$base_uri/ip_checkhost.cgi?ip=" + IP + "&hostname=" + HOSTNAME + "&client_id=" + CLIENT_ID  + "&ip_version=" + IP_VERSION;
host_info=window.open(URL,"",opciones);
}
-->
</script>
EOF

} else {
	print "<tr><td><b>$$lang_vars{libre_message}:</b> <font color=\"$ocu_color\"><b>$free ($percent_free)</b></font> | <b>$$lang_vars{ocupadas_message}</b>: <font color=\"$ocu_color\"><b>$ip_ocu ($percent_ocu)</b></font> | <b>$$lang_vars{todas_message}</b>: <b>$ip_total</b></td><td align=\"right\"><form method=\"POST\" action=\"$server_proto://$base_uri/ip_show.cgi\" style=\"display:inline\"><input name=\"red_num\" type=\"hidden\" value=\"$red_num\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"hidden\" name=\"ip_version\" value=\"$ip_version\"><input type=\"submit\" class=\"detailed_view_button\" value=\"\" title=\"$$lang_vars{vista_detallada_message}\"name=\"B1\"></form><form method=\"POST\" action=\"$server_proto://$base_uri/ip_show_red_overview.cgi\" style=\"display:inline\"><input type=\"hidden\" name=\"view\" value=\"short\"><input name=\"red_num\" type=\"hidden\" value=\"$red_num\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"hidden\" name=\"ip_version\" value=\"$ip_version\"><input type=\"submit\" class=\"short_view_button\" value=\"\" title=\"$$lang_vars{vista_corta_message}\"name=\"B1\"></form></td></tr>\n";
print "</table>";
}
print "<p>\n";

print "<table border=\"0\" cellspacing=\"0\" cellpadding=\"0\"><tr>";
my $i = 1;
my $k = 0;
my $j = 25;
my $l = 0;
my $bgcolor="white";
my $range_address = "0";
my $count_help;
my $range_comentario;
my %ranges = $gip->get_rangos_hash_endip("$client_id","$red_num");
for (my $ip_int_count = $redint; $i <= $anz_ip; $ip_int_count++) {
	my $loc = $red_loc || "NULL";
	my $host_id="";
	my $hostname;
	my ( $ip_show_int, $ip_show, $ip_title, $button_class, $image, $cat); 
	$ip_show = $gip->int_to_ip("$client_id","$ip_int_count","$ip_version");
	my $fourth_oct;
	if ( $ip_version eq "v4" ) {
		$ip_show =~ /\d{1,3}\.\d{1,3}\.\d{1,3}\.(\d{1,3})/;
		$fourth_oct = $1;
	} else {
		$ip_show =~ /:(\w{1,4})$/;
		$fourth_oct = $1;
	}	
	if ( $ranges{"$ip_int_count"} ) {
		$bgcolor="#eaeaea";
		$ranges{"$ip_int_count"} =~ /^(.*)-(.*)$/;
		$count_help = $1;
		$range_comentario=$2;
		$count_help++;
		$range_address = "1";
	}
	if ( $count_help == $ip_int_count ) {
		$bgcolor="white";
		$range_comentario = "";
		$range_address = "0";
	}
	if ( $ip[$k]->[0] == $ip_int_count ) {
		$host_id = $ip[$k]->[11] || "";
		$hostname = $ip[$k]->[1] if $ip[$k]->[1];
		$hostname = "---" if ! $hostname;
		$hostname = "---" if $hostname eq "NULL";
		$loc = $ip[$k]->[3] if $ip[$k]->[3];
		$cat = $ip[$k]->[4] if $ip[$k]->[4];
		$cat = "---" if $cat eq "NULL";

		if ( $hostname eq "---" ) {
			$ip_title = "$$lang_vars{unasigned_message}: " . $ip_show;
			$ip_title = $ip_title . " [" . $range_comentario . "]" if $range_comentario;
		} else {
			$ip_title = "$ip_show $hostname";
			$ip_title = $ip_title . " " . $cat if $cat;
			$ip_title = $ip_title . " [" . $range_comentario . "]" if $range_comentario;
		}
		if ( $view eq "short" ) {
			if ( $hostname ne "---" && defined ($cat) && defined ($ip[$k]->[8]) && $ip[$k]->[8] eq "1" && $range_address == "0" ) {
				$button_class = "net_overview_responds_button";
			} elsif ( $hostname ne "---" && defined ($cat) && defined ($ip[$k]->[8]) && $ip[$k]->[8] eq "1" && $range_address == "1" ) {
				$button_class = "net_overview_responds_range_button";
			} elsif ( $hostname ne "---" && defined ($cat) && defined ($ip[$k]->[8]) && $ip[$k]->[8] eq "0" && $range_address == "0" ) {
				$button_class = "net_overview_no_responds_button";
			} elsif ( $hostname ne "---" && defined ($cat) && defined ($ip[$k]->[8]) && $ip[$k]->[8] eq "0" && $range_address == "1" ) {
				$button_class = "net_overview_no_responds_range_button";
			} elsif ( $hostname ne "---" && defined ($cat) && ! defined ($ip[$k]->[8]) && $range_address == "0" ) {
				$button_class = "net_overview_never_checked_button";
			} elsif ( $hostname ne "---" && defined ($cat) && ! defined ($ip[$k]->[8]) && $range_address == "1" ) {
				$button_class = "net_overview_never_checked_range_button";
			} elsif ( $hostname ne "---" && $ip[$k]->[8] == "-1" && $range_address == "0" ) {
				$button_class = "net_overview_never_checked_button";
			} elsif ( $hostname ne "---" && $ip[$k]->[8] == "-1" && $range_address == "1" ) {
				$button_class = "net_overview_never_checked_range_button";
			} elsif ( $hostname eq "---" && exists $unasigned_alive_hosts{"$ip[$k]->[0]"} && $range_address == "1" ) {
				$button_class = "net_overview_responds_unasigned_range_button";
			} elsif ( $range_address == "0" ) {
				$button_class = "net_overview_none_button";
			} else {
				$button_class = "net_overview_none_range_button";
			}
			$k++;
		} else {
			if ( defined ($cat) && $hostname ne "---" && defined ($ip[$k]->[8]) && $ip[$k]->[8] eq "1" ) {
				if ( $cat eq "Router" || $cat eq "L3 device" ) {
					$button_class = "router_ok_button";
				} elsif ( $cat eq "Switch" || $cat eq "L2 device" ) {
					$button_class = "switch_ok_button";
				} elsif ( $cat =~ /[Pp]rinter/ ) {
					$button_class = "printer_ok_button";
				} elsif ( $cat eq "FW" ) {
					$button_class = "firewall_ok_button";
				} elsif ( $cat eq "workst" ) {
					$button_class = "workstation_ok_button";
				} elsif ( $cat =~ /[Ss]erver/ ) {
					$button_class = "server_ok_button";
				} elsif ( $cat eq "DB" ) {
					$button_class = "database_ok_button";
				} elsif ( $cat eq "wifi" ) {
					$button_class = "mobil_equipo_ok_button";
				} elsif ( $cat eq "other" ) {
					$button_class = "other_ok_button";
				} elsif ( $cat eq "VoIP" ) {
					$button_class = "phone_ok_button";
				} elsif ( $cat ne "---" ) {
					$button_class = "other_ok_button";
				} else {
					$button_class = "unknown_ok_button";
				}
			} elsif ( defined ($cat) && $hostname ne "---" && defined ($ip[$k]->[8]) && $ip[$k]->[8] eq "0" ) {
				if ( $cat eq "Router" || $cat eq "L3 device" ) {
					$button_class = "router_failed_button";
				} elsif ( $cat eq "Switch" || $cat eq "L2 device" ) {
					$button_class = "switch_failed_button";
				} elsif ( $cat eq "printer" ) {
					$button_class = "printer_failed_button";
				} elsif ( $cat eq "FW" ) {
					$button_class = "firewall_failed_button";
				} elsif ( $cat eq "workst" ) {
					$button_class = "workstation_failed_button";
				} elsif ( $cat eq "server" ) {
					$button_class = "server_failed_button";
				} elsif ( $cat eq "DB" ) {
					$button_class = "database_failed_button";
				} elsif ( $cat eq "wifi" ) {
					$button_class = "mobil_equipo_failed_button";
				} elsif ( $cat eq "other" ) {
					$button_class = "other_failed_button";
				} elsif ( $cat eq "VoIP" ) {
					$button_class = "phone_failed_button";
				} elsif ( $cat ne "---" ) {
					$button_class = "other_failed_button";
				} else {
					$button_class = "unknown_failed_button";
				}
			} elsif ( defined ($cat) && $hostname ne "---" && ! defined ($ip[$k]->[8]) ) {
				if ( $cat eq "Router" || $cat eq "L3 device" ) {
					$button_class = "router_never_checked_button";
				} elsif ( $cat eq "Switch" || $cat eq "L2 device" ) {
					$button_class = "switch_never_checked_button";
				} elsif ( $cat eq "printer" ) {
					$button_class = "printer_never_checked_button";
				} elsif ( $cat eq "FW" ) {
					$button_class = "firewall_never_checked_button";
				} elsif ( $cat eq "workst" ) {
					$button_class = "workstation_never_checked_button";
				} elsif ( $cat eq "server" ) {
					$button_class = "server_never_checked_button";
				} elsif ( $cat eq "DB" ) {
					$button_class = "database_never_checked_button";
				} elsif ( $cat eq "wifi" ) {
					$button_class = "mobil_equipo_never_checked_button";
				} elsif ( $cat eq "other" ) {
					$button_class = "other_never_checked_button";
				} elsif ( $cat eq "VoIP" ) {
					$button_class = "phone_never_checked_button";
				} elsif ( $cat ne "---" ) {
					$button_class = "other_never_checked_button";
				} else {
					$button_class = "unknown_never_checked_button";
				}

			} elsif ( $hostname ne "---" && $ip[$k]->[8] == "-1") {
				if ( $cat eq "Router" || $cat eq "L3 device" ) {
					$button_class = "router_never_checked_button";
				} elsif ( $cat eq "Switch" || $cat eq "L2 device" ) {
					$button_class = "switch_never_checked_button";
				} elsif ( $cat eq "printer" ) {
					$button_class = "printer_never_checked_button";
				} elsif ( $cat eq "FW" ) {
					$button_class = "firewall_never_checked_button";
				} elsif ( $cat eq "workst" ) {
					$button_class = "workstation_never_checked_button";
				} elsif ( $cat eq "server" ) {
					$button_class = "server_never_checked_button";
				} elsif ( $cat eq "DB" ) {
					$button_class = "database_never_checked_button";
				} elsif ( $cat eq "wifi" ) {
					$button_class = "mobil_equipo_never_checked_button";
				} elsif ( $cat eq "other" ) {
					$button_class = "other_never_checked_button";
				} elsif ( $cat eq "VoIP" ) {
					$button_class = "phone_never_checked_button";
				} elsif ( $cat ne "---" ) {
					$button_class = "other_never_checked_button";
				} else {
					$button_class = "unknown_never_checked_button";
				}
			} else {
				$button_class = "none_button";
			}
			$k++;
		}
	} elsif ( $i != 1 && $i != $anz_ip ) {
		$ip_title = "$$lang_vars{unasigned_message}: $ip_show";
		if ( $view eq "short" ) {
			if ( exists $unasigned_alive_hosts{"$ip_int_count"} ) {
				if ( $range_address == "0" ) {
					$button_class = "net_overview_responds_unasigned_button";
					$l++;
				} elsif ( $range_address == "1" ) {
					$button_class = "net_overview_responds_unasigned_range_button";
					$l++;
				} elsif ( $range_address == "1" ) {
					$button_class = "net_overview_none_range_button";
				} else {
					$button_class = "net_overview_none_button";
				}
			} else {
				if ( $range_address == "1" ) {
					$button_class = "net_overview_none_range_button";
				} else {
					$button_class = "net_overview_none_button";
				}
			}
		} else {
			$button_class = "none_button";
		}
	}
	if ( $i == 1 ) {
		print "<td align=\"center\" valign=\"middle\"><img src=\"$server_proto://$base_uri/imagenes/net_broad.png\" title=\"NETWORK ADDRESS - $ip_show\" alt=\"x\"></td>\n"
	} elsif ( $i == $anz_ip ) {
		print "<td align=\"center\" valign=\"middle\"><img src=\"$server_proto://$base_uri/imagenes/net_broad.png\" title=\"BROADCAST ADDRESS - $ip_show\" alt=\"x\"></td>\n"
	} else {
		if ( $view eq "short" ) {
			if ( defined($hostname) ) {
				print "<td align=\"center\" valign=\"middle\" class=\"$button_class\" onClick=\"checkhost(\'$ip_show\',\'$hostname\',\'$client_id\',\'$ip_version\')\" title=\"$ip_title\"><span class=\"overview_table_text\">$fourth_oct</span></td>\n";
			} else {
				print "<td align=\"center\" valign=\"middle\" class=\"$button_class\" onClick=\"checkhost(\'$ip_show\',\'\',\'$client_id\',\'$ip_version\')\" title=\"$ip_title\"><span class=\"overview_table_text\">$fourth_oct</span></td>\n";
			}
		} else {
			print "<td bgcolor=\"$bgcolor\" align=\"center\" valign=\"middle\"><form method=\"POST\" action=\"$server_proto://$base_uri/res/ip_modip_form.cgi\" style=\"display:inline\"><input name=\"ip\" type=\"hidden\" value=\"$ip_int_count\"><input name=\"red_num\" type=\"hidden\" value=\"$red_num\"><input name=\"loc\" type=\"hidden\" value=\"$loc\"><input name=\"host_id\" type=\"hidden\" value=\"$host_id\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"hidden\" name=\"ip_version\" value=\"$ip_version\"><input type=\"submit\" value=\"$fourth_oct\" title=\"$ip_title\" name=\"B2\" class=\"$button_class\"></form></td>\n";
		}
		if ( $i == $j ) {
			print "</tr>\n<tr>";
			$j = $j + 25;
		}
	}
	$i++;
}
print "</tr></table>\n";

print "<p><br>\n";
print "<table border=\"0\">";
if ( $view eq "short" ) {
	print "<p>\n";
	print "<tr><td></td><td><img src=\"$server_proto://$base_uri/imagenes/ping_green.png\" alt=\"x\"></td><td>UP</td>\n";
	print "<td><img src=\"$server_proto://$base_uri/imagenes/ping_red.png\" alt=\"x\"></td><td>DOWN</td><td></td><td><img src=\"$server_proto://$base_uri/imagenes/ping_gray.png\" alt=\"x\"></td><td>$$lang_vars{never_checked_message}</td></tr>\n";
} else {
	print "<tr><td><img src=\"$server_proto://$base_uri/imagenes/switch.png\" alt=\"x\"></td><td>L2 device</td><td><img src=\"$server_proto://$base_uri/imagenes/router.png\" alt=\"L3 device\"></td><td>L3 device</td><td><img src=\"$server_proto://$base_uri/imagenes/firewall.png\" alt=\"Firewall\"></td><td>FW ($$lang_vars{firewall_message})</td></tr>\n";
	print "<tr><td><img src=\"$server_proto://$base_uri/imagenes/server.png\" alt=\"server\"></td><td>server</td><td><img src=\"$server_proto://$base_uri/imagenes/database.png\" alt=\"DB\"></td><td>DB ($$lang_vars{database_message})</td><td><img src=\"$server_proto://$base_uri/imagenes/workstation.png\" alt=\"workst\"></td><td>workstation</td></tr>\n";
	print "<tr><td><img src=\"$server_proto://$base_uri/imagenes/mobil_equipo.png\" alt=\"wifi\"></td><td>wifi</td><td><img src=\"$server_proto://$base_uri/imagenes/printer.png\" alt=\"printer\"></td><td>printer</td><td><img src=\"$server_proto://$base_uri/imagenes/phone.png\" alt=\"VoIP\"></td><td>VoIP</td></tr>";
	print "<tr><td><img src=\"$server_proto://$base_uri/imagenes/other.png\" alt=\"other\"></td><td>other</td><td><img src=\"$server_proto://$base_uri/imagenes/unknown_never_checked_show.png\" alt=\"never checked\"></td><td>$$lang_vars{desconocido_message}</td><td><td></td><td></td></tr>\n";
	print "</table>\n";
	print "<p>\n";
	print "<table border=\"0\">";
	print "<tr><td></td><td><img src=\"$server_proto://$base_uri/imagenes/ping_green.png\" alt=\"x\"></td><td>UP</td>\n";
	print "<td><img src=\"$server_proto://$base_uri/imagenes/ping_red.png\" alt=\"x\"></td><td>DOWN</td><td></td><td><img src=\"$server_proto://$base_uri/imagenes/ping_gray.png\" alt=\"x\"></td><td>$$lang_vars{never_checked_message}</td></tr>\n";
}
print "</table>";


if ( keys(%ranges) ne "0" ) {
	print "<p>\n";
	print "<table border=\"0\">";
	print "<tr><td bgcolor=\"#eaeaea\"><img src=\"$server_proto://$base_uri/imagenes/none.png\" alt=\"none\"></td><td>$$lang_vars{rango_reservado_message}</td></tr>";
	print "</table>";
}
print "<br>\n";

if ( $export_result[0] ) {
print <<EOF;
<p>
<form name="export" method="POST" action="$server_proto://$base_uri/res/ip_export_ping_result.cgi" style="display:inline"><input type="hidden" name="export_result" value="@export_result"><input type="hidden" name="client_id" value="$client_id"><input type="submit" class="input_link_w" value="$$lang_vars{export_networks_or_hosts_message}" name="B1"></form></li>
EOF
}

$gip->print_end("$client_id","$vars_file");
