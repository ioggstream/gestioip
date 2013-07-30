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
use SNMP;
use SNMP::Info;
use Net::DNS;
use Parallel::ForkManager;
use Math::BigInt;
use Net::IP qw(:PROC);
use POSIX;

my $start_time=time();

my $daten=<STDIN>;
my $gip = GestioIP -> new();
my %daten=$gip->preparer($daten);

my $lang = $daten{'lang'} || "";
my ($lang_vars,$vars_file)=$gip->get_lang("","$lang");
my $base_uri=$gip->get_base_uri();
my $server_proto=$gip->get_server_proto();

my $client_id = $daten{'client_id'} || $gip->get_first_client_id();

my $ip_version=$daten{'ip_version'} || "";

$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{discover_network_via_snmp_message}","$vars_file");

$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (2)") if $ip_version !~ /^(v4|v6)$/;

my $red_num = $daten{'red_num'} || $gip->$gip->print_error("$client_id","$$lang_vars{formato_malo_message} red_num");

my $align="align=\"right\"";
my $align1="";
my $ori="left";
my $ori1="right";
my $rtl_helper="<font color=\"white\">x</font>";
if ( $vars_file =~ /vars_he$/ ) {
	$align="align=\"left\"";
	my $align1="align=\"right\"";
	$ori="right";
	$ori1="left";
}



my @values_redes=$gip->get_red("$client_id","$red_num");
my $red = "$values_redes[0]->[0]" || "";
my $BM = "$values_redes[0]->[1]" || "";

my @client_entries=$gip->get_client_entries("$client_id");
my $default_resolver = $client_entries[0]->[20];
my @dns_servers =("$client_entries[0]->[21]","$client_entries[0]->[22]","$client_entries[0]->[23]");


my $mibdirs_ref = $gip->check_mib_dir("$client_id","$vars_file");
	

$gip->print_error("$client_id","$$lang_vars{introduce_community_string_message}") if ( ! $daten{'community_string'} );
$gip->print_error("$client_id","$$lang_vars{formato_malo_message}") if length($daten{community_string}) > 35 ;
$gip->print_error("$client_id","$$lang_vars{formato_malo_message}") if length($daten{community_string}) > 35 ;
$gip->print_error("$client_id","$$lang_vars{formato_malo_message}") if ($daten{snmp_version} !~ /^[123]$/ );


my $community=$daten{'community_string'};
my $snmp_version=$daten{snmp_version};
my $add_comment;
$add_comment=$daten{'add_comment'} if $daten{'add_comment'};
$add_comment="n" if ! $add_comment;

my @config = $gip->get_config("$client_id");
my $max_procs = $config[0]->[1] || "254";
my $smallest_bm = $config[0]->[0] || "22";
my $ignore_generic_auto = $config[0]->[3] || "yes";

my $audit_type="4";
my $audit_class="2";
my $update_type_audit="7";
my $event="${red}/${BM}";
$event=$event . " (community: public)" if $community eq "public";
$gip->insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");

my $community_type="Community";

my $auth_pass="";
my $auth_proto="";
my $auth_is_key="";
my $priv_proto="";
my $priv_pass="";
my $priv_is_key="";
my $sec_level="noAuthNoPriv";

if ( $snmp_version == "3" ) {
	$community_type = "SecName";
	$auth_proto=$daten{'auth_proto'} || "";
	$auth_pass=$daten{'auth_pass'} || "";
	$auth_is_key=$daten{'auth_is_key'} || "";
	$priv_proto=$daten{'priv_proto'} || "";
	$priv_pass=$daten{'priv_pass'} || "";
	$priv_is_key=$daten{'priv_is_key'} || "";
	$sec_level=$daten{'sec_level'} || "";
	$gip->print_error("$client_id","$$lang_vars{introduce_community_string_message}") if ! $community;
	$gip->print_error("$client_id","$$lang_vars{introduce_auth_pass_message}") if $auth_proto && ! $auth_pass;
	$gip->print_error("$client_id","$$lang_vars{introduce_auth_proto_message}") if $auth_pass && ! $auth_proto;
	$gip->print_error("$client_id","$$lang_vars{introduce_priv_pass_message}") if $priv_proto && ! $priv_pass;
	$gip->print_error("$client_id","$$lang_vars{introduce_priv_proto_message}") if $priv_pass && ! $priv_proto;
	$gip->print_error("$client_id","$$lang_vars{introduce_priv_auth_missing_message}") if $priv_proto && ( ! $auth_proto || ! $auth_pass );
}


print <<EOF;

<SCRIPT LANGUAGE="Javascript" TYPE="text/javascript">
<!--

function scrollToTop() {
  var x = '0';
  var y = '0';
  window.scrollTo(x, y);
  eraseCookie('net_scrollx')
  eraseCookie('net_scrolly')
}

// -->
</SCRIPT>

EOF


print "<span style=\"float:$ori1;\">\n";
print "<div id=\"SincButtons\">\n";
if ( $BM >= 20 ) {
        print "<table border=\"0\" width=\"100%\"><tr><td align=\"right\"><td align=\"right\"><form method=\"POST\" action=\"$server_proto://$base_uri/ip_show.cgi\" style=\"display:inline\"><input name=\"red_num\" type=\"hidden\" value=\"$red_num\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input name=\"ip_version\" type=\"hidden\" value=\"$ip_version\"><input type=\"submit\" class=\"detailed_view_button\" value=\"\" title=\"detailed network view\"name=\"B1\"></form><form method=\"POST\" action=\"$server_proto://$base_uri/ip_show_red_overview.cgi\" style=\"display:inline\"><input type=\"hidden\" name=\"view\" value=\"long\"><input name=\"red_num\" type=\"hidden\" value=\"$red_num\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input name=\"ip_version\" type=\"hidden\" value=\"$ip_version\"><input type=\"submit\" class=\"long_view_button\" value=\"\" title=\"network overview\" name=\"B1\"></form><form method=\"POST\" action=\"$server_proto://$base_uri/ip_show_red_overview.cgi\" style=\"display:inline\"><input type=\"hidden\" name=\"view\" value=\"short\"><input name=\"red_num\" type=\"hidden\" value=\"$red_num\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input name=\"ip_version\" type=\"hidden\" value=\"$ip_version\"><input type=\"submit\" class=\"short_view_button\" value=\"\" title=\"network status view\" name=\"B1\"></form></td></tr></table>\n";
} else {
        print "<table border=\"0\" width=\"100%\"><tr><td align=\"right\"><td align=\"right\"><form method=\"POST\" action=\"$server_proto://$base_uri/ip_show.cgi\" style=\"display:inline\"><input name=\"red_num\" type=\"hidden\" value=\"$red_num\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input name=\"ip_version\" type=\"hidden\" value=\"$ip_version\"><input type=\"submit\" class=\"detailed_view_button\" value=\"\" title=\"detailed network view\"name=\"B1\"></form></td></tr></table>\n";
}
print "</div>\n";
print "</span><br>\n";


my $redob = $red . "/" . $BM;
my $ipob = new Net::IP ($redob) or $gip->print_error("$client_id","$$lang_vars{formato_malo_message} <b>$redob</b>");



my ($first_ip_int,$last_ip_int);
my @zone_records;
my $zone_name;


if ( $ip_version eq "v4" ) {
	my $ipob = new Net::IP ($redob) or $gip->print_error("$client_id","$$lang_vars{comprueba_red_BM_message}: <b>$red/$BM</b>"); 
	my $redint=($ipob->intip());
	$redint = Math::BigInt->new("$redint");
	$first_ip_int = $redint + 1;
	$first_ip_int = Math::BigInt->new("$first_ip_int");
	$last_ip_int = ($ipob->last_int());
	$last_ip_int = Math::BigInt->new("$last_ip_int");
	$last_ip_int = $last_ip_int - 1;
} else {
	my ($nibbles, $rest);
	my $red_exp = ip_expand_address ($red,6) if $ip_version eq "v6";
        my $nibbles_pre=$red_exp;
        $nibbles_pre =~ s/://g;
        my @nibbles=split(//,$nibbles_pre);
        my @nibbles_reverse=reverse @nibbles;
        $nibbles="";
        $rest=128-$BM;
        my $red_part_helper = ($rest+1)/4;
        $red_part_helper = ceil($red_part_helper);
        my $n=1;
        foreach my $num (@nibbles_reverse ) {
		if ( $n<$red_part_helper ) {
			$n++;
			next;		
                } elsif ( $nibbles =~ /\w/) {
                        $nibbles .= "." . $num;
                } else {
                        $nibbles = $num;
                }
                $n++;
        }
        $nibbles .= ".ip6.arpa.";
	$zone_name=$nibbles;
	@zone_records=$gip->fetch_zone("$zone_name","$default_resolver",\@dns_servers);
}

if ( ! $zone_records[0] && $ip_version eq "v6" ) {
        if ( $vars_file =~ /vars_he$/ ) {
                print "<p><span style=\"float: $ori;\">$zone_name $$lang_vars{can_not_fetch_zone_message}<p>$$lang_vars{zone_transfer_allowed_message}</span><br><p><br>\n";
#                $gip->print_end("$client_id","$vars_file","go_to_top");
        } else {
#                $gip->print_error("$client_id","$$lang_vars{can_not_fetch_zone_message} $zone_name<p>$$lang_vars{zone_transfer_allowed_message}");
		print "<p>$$lang_vars{can_not_fetch_zone_message} $zone_name<p>$$lang_vars{zone_transfer_allowed_message}<br><p>";
        }
}


my @ip;
my @found_ip;
if ( $ip_version eq "v6" ) {
	@ip=$gip->get_host_from_red_num("$client_id","$red_num");
	my $p=0;
	foreach my $found_ips (@ip) { 
		if ( $found_ips->[0] ) {
			$found_ips->[0]=$gip->int_to_ip("$client_id","$found_ips->[0]","$ip_version");
			$found_ip[$p]=$found_ips->[0];
		}
		$p++;
	}
}
   

my @records;
if ( $ip_version eq "v4" ) {
	my $l=0;
	for (my $m = $first_ip_int; $m <= $last_ip_int; $m++) {
		push (@records,"$m");
	}
} else {
	@records=@zone_records;
	my @records_new=();
	my $n=0;
	foreach (@zone_records) {
		if ( $_ =~ /(IN.?SOA|IN.?NS)/ ) {
			next;
		}
		$_=/^(.*)\.ip6.arpa/;
		my $nibbles=$1;
		my @nibbles=split('\.',$nibbles);
		@nibbles=reverse(@nibbles);
		my $ip_nibbles="";
		my $o=0;
		foreach (@nibbles) {
			if ( $o == 4 || $o==8 || $o==12 || $o==16 || $o==20 || $o==24 || $o==28 ) {
				$ip_nibbles .= ":" . $_;
			} else {
				$ip_nibbles .= $_;
			}
			$o++;
		}
		$records_new[$n]=$ip_nibbles;
		$n++;
	}
	
	@records=@records_new;
	@records=(@records,@found_ip);
	my $anz_records=$#records || "";
	my %seen;
	if ( $anz_records ) {
		for ( my $q = 0; $q <= $#records; ) {
			splice @records, --$q, 1
			if $seen{$records[$q++]}++;
		}
		@records=sort(@records)
	}
}


my $j=0;
my ( $ip_int, $ip_bin, $pm, $res, $pid, $ip );
my ( %res_sub, %res, %result);
my %predef_host_columns=$gip->get_predef_host_column_all_hash("$client_id");

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

my $utype="snmp";
my $ip_hash = $gip->get_host_hash_id_key("$client_id","$red_num");

my $red_loc = $gip->get_loc_from_redid("$client_id","$red_num");
my $red_loc_id = $gip->get_loc_id("$client_id","$red_loc") || "-1";
my @vendors = $gip->get_vendor_array();

print "<span class=\"sinc_text\">";

my $i;
$i = $first_ip_int-1 if $ip_version eq "v4";
foreach ( @records ) {

	next if ! $_;

	my $exit=0;
	my $node;

	if ( $ip_version eq "v4" ) {
		$i++; 
		$node=$gip->int_to_ip("$client_id","$i","$ip_version");
	} else {
		$node=$_;
		$i=$gip->ip_to_int("$client_id","$node","$ip_version");
	}

	my $node_id=$gip->get_host_id_from_ip_int("$client_id","$i","$red_num") || "";

	
		##fork
		$pid = $pm->start("$node") and next;
			#child

#			print "<b>$node</b>: ";
			my $utype_db;
			my $device_name_db = "";
			$utype_db=$ip_hash->{$node_id}[7] if $node_id;
			$device_name_db=$ip_hash->{$node_id}[1] if $node_id;
			$device_name_db = "" if ! $device_name_db;
			my $range_id=$ip_hash->{"$node_id"}[10];
			$utype_db = "---" if ! $utype_db;
			if ( $utype_db eq "man" ) {
				if ( $vars_file =~ /vars_he$/ ) {
					print "<span style=\"float: $ori\">$$lang_vars{ignorado_message} - $utype_db :update type :<b>$node</b></span><br>\n";
				} else {
					print "<b>$node</b>: update type: $utype_db - $$lang_vars{ignorado_message}<br>\n";
				}
				$exit = 1;
				$pm->finish($exit); # Terminates the child process
			}

			my $device_type="";
			my $device_vendor="";
			my $device_serial="";
			my $device_contact="";
			my $device_name="";
			my $device_location="";
			my $device_descr="";
			my $device_forwarder="";
			my $device_os="";
			my $device_cat="-1";

			my $mydatetime = time();
			my $new_host = "0";
			my $snmp_info_connect = "1";
			my $snmp_connect = "1";

			my $bridge=$gip->create_snmp_info_session("$client_id","$node","$community","$community_type","$snmp_version","$auth_pass","$auth_proto","$auth_is_key","$priv_proto","$priv_pass","$priv_is_key","$sec_level",$mibdirs_ref,"$vars_file");

			# it does not work with SNMPv3 when bulkwalk is turned on

			if ( defined($bridge) ) {
				$bridge->bulkwalk(0);
				$snmp_info_connect ="0";
				$device_type=$bridge->model() || "";
				$device_type = "" if $device_type =~ /enterprises\.\d/;
				$device_vendor=$bridge->vendor() || "";
				$device_serial=$bridge->serial() || "";
				$device_contact=$bridge->contact() || "";
				$device_name=$bridge->name() || "";
				$device_location=$bridge->location() || "";
				$device_descr=$bridge->description() || "";
				$device_forwarder=$bridge->ipforwarding() || "";
				$device_os="";
			}


			my $session=$gip->create_snmp_session("$client_id","$node","$community","$community_type","$snmp_version","$auth_pass","$auth_proto","$auth_is_key","$priv_proto","$priv_pass","$priv_is_key","$sec_level","$vars_file");


			if ( defined $session ) {
				no strict 'subs';	
				my $vars = new SNMP::VarList([sysDescr,0],
							[sysName,0],
							[sysContact,0],
							[sysLocation,0]);
				use strict 'subs';

				my @values = $session->get($vars);

				if ( ! ($session->{ErrorStr}) ) {

					$snmp_connect = "0";

					$device_descr = $values[0];
					$device_name = $values[1];
					$device_contact = $values[2];
					$device_location = $values[3];
					
	
					
					if ( $device_descr =~ /ubuntu/i ) {
						$device_os = "ubuntu";
					} elsif ( $device_descr =~ /debian/i ) {
						$device_os = "debian";
					} elsif ( $device_descr =~ /suse/i ) {
						$device_os = "suse";
					} elsif ( $device_descr =~ /fedora/i ) {
						$device_os = "fedora";
					} elsif ( $device_descr =~ /redhat/i ) {
						$device_os = "redhat";
					} elsif ( $device_descr =~ /centos/i ) {
						$device_os = "centos";
					} elsif ( $device_descr =~ /turbolinux/i ) {
						$device_os = "turbolinux";
					} elsif ( $device_descr =~ /slackware/i ) {
						$device_os = "slackware";
					} elsif ( $device_descr =~ /linux/i ) {
						$device_os = "linux";
					} elsif ( $device_descr =~ /freebsd/i ) {
						$device_os = "freebsd";
					} elsif ( $device_descr =~ /netbsd/i ) {
						$device_os = "netbsd";
					} elsif ( $device_descr =~ /netware/i ) {
						$device_os = "netware";
					} elsif ( $device_descr =~ /openbsd/i ) {
						$device_os = "openbsd";
					} elsif ( $device_descr =~ /solaris/i || $device_descr =~ /sunos/i ) {
						$device_os = "solaris";
					} elsif ( $device_descr =~ /unix/i ) {
						$device_os = "unix";
					} elsif ( $device_descr =~ /windows/i ) {
						$device_os = "windows_server";
					}

					foreach ( @vendors ) {
						my $vendor=$_;
						if ( $device_descr =~ /(${vendor}\s)/i ) {
							if ( $device_descr =~ /(ibm.+aix)/i ) {
								$device_vendor = "ibm";
								$device_os = "aix";
							} elsif ( $device_descr =~ /(ibm.+os2)/i ) {
								$device_vendor = "ibm";
								$device_os = "os2";
							} elsif ( $device_descr =~ /(aficio|ricoh)/i ) {
								$device_vendor = $vendor;
								if ( $device_descr =~ /printer/i ) {
									my $new_cat=$gip->get_cat_id("$client_id","printer");
									$device_cat = "$new_cat" if $new_cat;
								}
							} elsif ( $device_descr =~ /(hp\s|hewlett.?packard)/i ) {
								$device_vendor = "hp";
								if ( $device_descr =~ /jet/i ) {
									my $new_cat=$gip->get_cat_id("$client_id","printer");
									$device_cat = "$new_cat" if $new_cat;
								}
							} elsif ( $device_descr =~ /(alcatel|lucent)/i ) {
								$device_vendor = "lucent-alcatel";
							} elsif ( $device_descr =~ /(palo.?alto)/i ) {
								$device_vendor = "paloalto";
							} elsif ( $device_descr =~ /(microsoft|windows)/i ) {
								$device_os = "windows";
							} elsif ( $device_descr =~ /cyclades/i ) {
								$device_vendor = "avocent";
							} elsif ( $device_descr =~ /orinoco/i ) {
								$device_vendor = "lucent-alcatel";
							} elsif ( $device_descr =~ /phaser/i ) {
								$device_vendor = "xerox";
							} elsif ( $device_descr =~ /minolta/i ) {
								$device_vendor = "konica";
							} elsif ( $device_descr =~ /check.?point/i ) {
								$device_vendor = "checkpoint";
							} elsif ( $device_descr =~ /top.?layer/i ) {
								$device_vendor = "toplayer";
							} elsif ( $device_descr =~ /silver.?peak/i ) {
								$device_vendor = "Silver Peak";
							} elsif ( $device_descr =~ /okilan/i ) {
								$device_vendor = "Oki Data";
							} elsif ( $device_descr =~ /(dlink|d-link)/i ) {
								$device_vendor = "dlink";
							} else {
								$device_vendor = $vendor;
							}
						} 
					}
				}
			} else {
#				print "<span style=\"float: $ori\">SNMP $$lang_vars{can_not_connect_message}</span><br>\n";
			}

			if ( ( $snmp_info_connect == "1" && $snmp_connect == "1" ) ) {
				if ( $vars_file =~ /vars_he$/ ) {
					print "<span style=\"float: $ori\">$$lang_vars{can_not_connect_message} :<b>$node</b></span><br>\n";
				} else {
					print "<b>$node</b>: $$lang_vars{can_not_connect_message}<br>\n";
				}
				$exit = "1";
				$pm->finish($exit); # Terminates the child process
			}

			$device_descr = "" if $device_descr =~ /(unknown|configure)/i;
			$device_descr =~ s/^"//;
			$device_descr =~ s/"$//;
			$device_contact = "" if $device_contact =~ /(unknown|configure)/i;
			$device_contact =~ s/^"//;
			$device_contact =~ s/"$//;
			$device_location = "" if $device_location =~ /(unknown|configure)/i;
			$device_location =~ s/^"//;
			$device_location =~ s/"$//;
			$device_name = "unknown" if $device_name =~ /(localhost|DEFAULT SYSTEM NAME|unknown|configure)/i;
			$device_name =~ s/^"//;
			$device_name =~ s/"$//;
			$device_vendor = "" if $device_vendor =~ /(unknown)/i;
			$device_vendor =~ s/^"//;
			$device_vendor =~ s/"$//;

			my $device_name_dns = "";
			if ( ! $node_id && ! $device_name ) {

				my $res_dns;

				if ( $default_resolver eq "yes" ) {
					$res_dns = Net::DNS::Resolver->new(
					retry       => 2,
					udp_timeout => 5,
					recurse     => 1,
					debug       => 0,
					);
				} else {
					$res_dns = Net::DNS::Resolver->new(
					retry       => 2,
					udp_timeout => 5,
					nameservers => [@dns_servers],
					recurse     => 1,
					debug       => 0,
					);
				}

				my $ptr_query;
				my $dns_error="";
				if ( $node =~ /\w+/ ) {
					$ptr_query = $res_dns->search("$node");

					if ($ptr_query) {
						foreach my $rr ($ptr_query->answer) {
							next unless $rr->type eq "PTR";
							$device_name_dns = $rr->ptrdname;
						}
					} else {
						$dns_error = $res_dns->errorstring;
					}
				}


				$node =~ /(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})/;
				my $generic_auto = "$2-$3-$4|$4-$3-$2|$1-$2-$3|$3-$2-$1";
				if ( $device_name_dns =~ /$generic_auto/ && $ignore_generic_auto eq "yes" ) {
					$device_name_dns = "unknown";
				}
				$device_name=$device_name_dns if $device_name_db eq "unknown";
			}

			if ( ! $device_name_dns ) {
				$device_name = "unknown" if $device_name =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/;
			} else {
				$device_name = "" if $device_name =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/;
			}

			my $hostname_update="0";

			if ( ! $node_id && $device_name ) {
				$device_name =~ s/\s/_/g;
				$gip->insert_ip_mod("$client_id","$i","$device_name","","$red_loc_id","n","$device_cat","","-1","$mydatetime","$red_num","-1","$ip_version");
				$new_host = "1";
				$node_id=$gip->get_last_host_id("$client_id");
				if ( $vars_file =~ /vars_he$/ ) {
					print "<span style=\"float: $ori\">$device_name : $$lang_vars{added_message} :<b>$node</b></span>";
				} else {
					print "<b>$node</b>: $$lang_vars{added_message}: $device_name";
				}
			} elsif ( ! $node_id && $device_name_dns ) {
				$gip->insert_ip_mod("$client_id","$i","$device_name_dns","","$red_loc_id","n","$device_cat","","-1","$mydatetime","$red_num","-1","$ip_version");
				$new_host = "1";
				$node_id=$gip->get_last_host_id("$client_id");
				if ( $vars_file =~ /vars_he$/ ) {
					print "<span style=\"float: $ori\">$device_name_dns : $$lang_vars{added_message} :<b>$node</b></span>";
				} else {
					print "<b>$node</b>: $$lang_vars{added_message}: $device_name_dns";
				}
			} elsif ( ! $node_id && $device_type ) {
				$device_type =~ /^(.+)\s*/;
				my $device_name = $1;
				$gip->insert_ip_mod("$client_id","$i","$device_name","","$red_loc_id","n","$device_cat","","-1","$mydatetime","$red_num","-1","$ip_version");
				$new_host = "1";
				if ( $vars_file =~ /vars_he$/ ) {
					print "<span style=\"float: $ori\">$device_name : $$lang_vars{added_message} :<b>$node</b></span>";
				} else {
					print "<b>$node</b>: $$lang_vars{added_message}: $device_name";
				}
				$node_id=$gip->get_last_host_id("$client_id");
			} elsif ( ! $node_id && $device_vendor ) {
				$device_vendor =~ /^(.+)\s*/;
				my $device_name = $1;
				$gip->insert_ip_mod("$client_id","$i","$device_name","","$red_loc_id","n","$device_cat","","-1","$mydatetime","$red_num","-1","$ip_version");
				$new_host = "1";
				if ( $vars_file =~ /vars_he$/ ) {
					print "<span style=\"float: $ori\">$device_name : $$lang_vars{added_message} :<b>$node</b></span>";
				} else {
					print "<b>$node</b>: $$lang_vars{added_message}: $device_name";
				}
				$node_id=$gip->get_last_host_id("$client_id");
			} elsif ( ! $node_id ) {
				$exit = 1;
				if ( $vars_file =~ /vars_he$/ ) {
					print "<span style=\"float: $ori\">$$lang_vars{ignorado_message} - $$lang_vars{no_device_name_message} :<b>$node</b></span>\n";
				} else {
					print "<b>$node</b>: $$lang_vars{no_device_name_message} - $$lang_vars{ignorado_message}\n";
				}
				$pm->finish($exit); # Terminates the child process
			} elsif ( $node_id  &&  $device_name_db eq "unknown" && $device_name && $device_name ne "unknown" ) {
					$gip->update_host_hostname("$client_id","$node_id","$device_name");
					$hostname_update="1";
			} elsif ( $node_id && $range_id != "-1" && ! $device_name_db ) {
				if ( $device_name ) {
					$gip->update_host_hostname("$client_id","$node_id","$device_name");
					if ( $vars_file =~ /vars_he$/ ) {
						print "<span style=\"float: $ori\">$device_name : $$lang_vars{added_message} :<b>$node</b></span>";
					} else {
						print "<b>$node</b>: $$lang_vars{added_message}: $device_name";
					}
					$new_host = "1";
				} elsif ( $device_name_dns ) {
					$gip->update_host_hostname("$client_id","$node_id","$device_name_dns");
					if ( $vars_file =~ /vars_he$/ ) {
						print "<span style=\"float: $ori\">$device_name_dns : $$lang_vars{added_message} :<b>$node</b></span>";
					} else {
						print "<b>$node</b>: $$lang_vars{added_message}: $device_name_dns";
					}
					$new_host = "1";
				} elsif ( $device_type ) {
					$device_type =~ /^(.+)\s*/;
					my $device_name = $1;
					$gip->update_host_hostname("$client_id","$node_id","$device_name");
					if ( $vars_file =~ /vars_he$/ ) {
						print "<span style=\"float: $ori\">$device_name : $$lang_vars{added_message} :<b>$node</b></span>";
					} else {
						print "<b>$node</b>: $$lang_vars{added_message}: $device_name";
					}
					$new_host = "1";
				} elsif ( $device_vendor ) {
					$device_vendor =~ /^(.+)\s*/;
					my $device_name = $1;
					if ( $vars_file =~ /vars_he$/ ) {
						print "<span style=\"float: $ori\">$device_name : $$lang_vars{added_message} :<b>$node</b></span>";
					} else {
						print "<b>$node</b>: $$lang_vars{added_message}: $device_name";
					}
					$gip->update_host_hostname("$client_id","$node_id","$device_name");
					$new_host = "1";
				} else {
					$gip->update_host_hostname("$client_id","$node_id","unknown");
					if ( $vars_file =~ /vars_he$/ ) {
						print "<span style=\"float: $ori\">unknown :$$lang_vars{added_message} :<b>$node</b></span>";
					} else {
						print "<b>$node</b>: $$lang_vars{added_message}: unknown";
					}
					$new_host = "1";
				}
			}

			my $entry;
			my $audit_entry = "";
			my $audit_entry_cc = "";
			my $audit_entry_cc_new = "";
			my $update = "0";

			while ( my ($key, $value) = each(%predef_host_columns) ) {
				my $pc_id;
				my $cc_id = $gip->get_custom_host_column_id_from_name_client("$client_id","$key") || "-1"; 
				next if $cc_id eq "-1";

				if ( $key eq "vendor" ) {
					$entry = $device_vendor;
				} elsif ( $key eq "model" ) {
					$entry = $device_type;
				} elsif ( $key eq "contact" ) {
					$entry = $device_contact;
				} elsif ( $key eq "serial" ) {
					$entry = $device_serial;
				} elsif ( $key eq "device_descr" ) {
					$entry = $device_descr;
				} elsif ( $key eq "device_name" ) {
					$entry = $device_name;
					$entry = "" if $device_name eq "unknown";
				} elsif ( $key eq "device_loc" ) {
					$entry = $device_location;
				} elsif ( $key eq "OS" ) {
					$entry = $device_os;
				} else {
					$entry = "";
				}


				if ( $entry ) {
					$pc_id=$predef_host_columns{$key}[0];

					my @cc_entry_host=();
					my $cc_entry_host=$gip->get_custom_host_column_entry_complete("$client_id","$node_id","$cc_id") || "";

					if ( @{$cc_entry_host}[0] ) {
						my $entry_db=@{$cc_entry_host}[0]->[0];
						$entry_db=~s/^\*//;
						$entry_db=~s/\*$//;
						if ( $entry_db ne $entry ) {
							$gip->update_custom_host_column_value_host("$client_id","$cc_id","$pc_id","$node_id","$entry");
							if ( $audit_entry_cc ) {
								$audit_entry_cc = $audit_entry_cc . "," . $entry;
							} else {
								$audit_entry_cc = $entry;
							}
							if ( $audit_entry_cc_new ) {
								$audit_entry_cc_new = $audit_entry_cc . "," . @{$cc_entry_host}[0]->[0];
							} else {
								$audit_entry_cc_new = @{$cc_entry_host}[0]->[0];
							}
							$update="2";
						} else {

							if ( $audit_entry_cc ) {
								$audit_entry_cc = $audit_entry_cc . "," . $entry;
							} else {
								$audit_entry_cc = $entry;
							}
							if ( $audit_entry_cc_new ) {
								$audit_entry_cc_new = $audit_entry_cc_new . "," . @{$cc_entry_host}[0]->[0];
							} else {
								$audit_entry_cc_new = @{$cc_entry_host}[0]->[0];
							}
							
						}
					} else {
						$gip->insert_custom_host_column_value_host("$client_id","$cc_id","$pc_id","$node_id","$entry");
						if ( $audit_entry_cc ) {
							$audit_entry_cc = $audit_entry_cc . ",---";
						} else {
							$audit_entry_cc = "---";
						}
						if ( $audit_entry_cc_new ) {
							$audit_entry_cc_new = $audit_entry_cc_new . "," . $entry;
						} else {
							$audit_entry_cc_new = $entry;
						}
						$update="1" if $update != "2";
					}
				}
			}

			if ( $hostname_update == "1" && $new_host == "0" ) { 
				if ( $vars_file =~ /vars_he$/ ) {
					print "<span style=\"float: $ori\">$device_name :$$lang_vars{host_updated_message} :<b>$node</b></span>\n";
				} else {
					print "<b>$node</b>: $$lang_vars{host_updated_message}: $device_name\n";
				}
			}
			if ( $update == "1" && $new_host == "0" ) {
				print ", " if $hostname_update == "1";
				if ( $vars_file =~ /vars_he$/ ) {
					print "<span style=\"float: $ori\">$$lang_vars{cc_updated_message} :<b>$node</b></span>\n";
				} else {
					print "<b>$node</b>: $$lang_vars{cc_updated_message}\n";
				}
			} elsif ( $update == "0" && $new_host != "1" && $hostname_update == "0" ) {
				if ( $vars_file =~ /vars_he$/ ) {
					print "<span style=\"float: $ori\">$$lang_vars{no_changes_message} :<b>$node</b></span>\n";
				} else {
					print "<b>$node</b>: $$lang_vars{no_changes_message}\n";
				}
			} elsif ( $update == "2" && $new_host != "1" ) {
				if ( $vars_file =~ /vars_he$/ ) {
					print "<span style=\"float: $ori\"> ,</span>" if $hostname_update == "1";
					print "<span style=\"float: $ori\">$$lang_vars{cc_updated_message}</span>\n";
				} else {
					print ", " if $hostname_update == "1";
					print "$$lang_vars{cc_updated_message}\n";
				}
			}

			print "<br>\n";
#			print " - DEVICE TYPE: $device_type - VENDOR: $device_vendor - SERIAL: $device_serial - CONTACT: $device_contact - NAME: $device_name - LOC: $device_location - DESCR: $device_descr - FORWARDER: $device_forwarder <br>";

			if ( $new_host == "1" ) {
				my $audit_type="15";
				my $audit_class="1";
				my $update_type_audit="7";
				$red_loc = "---" if $red_loc eq "NULL";
				my $event="$node: $device_name,---,$red_loc,n,---,---,$utype,$audit_entry";
				$event=$event . " (community: public)" if $community eq "public";
				$gip->insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");
			} elsif ( $update == "1" || $update == "2" ) {
				my $audit_type="1";
				my $audit_class="1";
				my $update_type_audit="7";
				my $hostname_audit=$ip_hash->{$node_id}[1] || "---";
				my $host_descr=$ip_hash->{$node_id}[2] || "---";
				my $loc=$ip_hash->{$node_id}[3] || "---";
				my $cat=$ip_hash->{$node_id}[4] || "---";
				my $int_admin=$ip_hash->{$node_id}[5] || "---";
				my $comentario=$ip_hash->{$node_id}[6] || "---";
				my $utype_audit=$ip_hash->{$node_id}[7] || "---";
				$host_descr = "---" if $host_descr eq "NULL";
				$cat = "---" if $cat eq "NULL";
				$loc = "---" if $loc eq "NULL";
				$comentario = "---" if $comentario eq "NULL";
				$utype_audit = "---" if ! $utype_audit;
				$utype_audit = "---" if $utype_audit eq "NULL";
				$hostname_audit = "---" if $hostname_audit eq "NULL";
				my $event="$node: $hostname_audit,$host_descr,$loc,$int_admin,$cat,$comentario,$utype_audit,$audit_entry_cc -> $hostname_audit,$host_descr,$loc,$int_admin,$cat,$comentario,$utype_audit";
				$event=$event . "," . $audit_entry_cc_new if $audit_entry_cc_new;
				$event=$event . " (community: public)" if $community eq "public";
				$gip->insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");
			}

			$exit=0;


		$pm->finish($exit); # Terminates the child process

}

$pm->wait_all_children;

print "</span><p><br>\n";

my $end_time=time();
my $duration=$end_time - $start_time;
my @parts = gmtime($duration);
my $duration_string = "";
$duration_string = $parts[2] . "h, " if $parts[2] != "0";
$duration_string = $duration_string . $parts[1] . "m";
$duration_string = $duration_string . " and " . $parts[0] . "s";

if ( $vars_file =~ /vars_he$/ ) {
        print "<br><p><span style=\"float: $ori\"><i>${duration_string} :$$lang_vars{execution_time_message}</i></style><br><p>\n";
} else {
        print "<br><p><i>$$lang_vars{execution_time_message}: ${duration_string}</i><p>\n";
}

print "<br><h3 style=\"float: $ori\">$$lang_vars{listo_message}</h3><br><p><br>\n";


$gip->print_end("$client_id","$vars_file","go_to_top");
