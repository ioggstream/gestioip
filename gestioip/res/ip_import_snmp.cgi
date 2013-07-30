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

# VERSION 3.0.0


use strict;
use SNMP;
use lib '../modules';
use GestioIP;
use Net::IP qw(:PROC);

my $daten=<STDIN>;
my $gip = GestioIP -> new();
my %daten=$gip->preparer($daten);

my $lang = $daten{'lang'} || "";
my ($lang_vars,$vars_file)=$gip->get_lang("","$lang");

my $client_id = $daten{'client_id'} || $gip->get_first_client_id();

my $ip_version = $daten{'ip_version'} || "v4";
my $import_ipv4=$daten{'ipv4'} || "";
my $import_ipv6=$daten{'ipv6'} || "";

my $local_routes=$daten{'local_routes'} || "";
my $static_routes=$daten{'static_routes'} || "";
my $other_routes=$daten{'other_routes'} || "";
my $ospf_routes=$daten{'ospf_routes'} || "";
my $rip_routes=$daten{'rip_routes'} || "";
my $isis_routes=$daten{'isis_routes'} || "";
my $eigrp_routes=$daten{'eigrp_routes'} || "";

my $process_networks_v4=$daten{'process_networks_v4'} || "";
my $process_networks_v6=$daten{'process_networks_v6'} || "";


$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{import_routes_message}","$vars_file");

$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (1)") if $ip_version !~ /^(v4|v6)$/;

$gip->print_error("$client_id","$$lang_vars{introduce_snmp_node_message}") if ( ! $daten{'snmp_node'} );
$gip->print_error("$client_id","$$lang_vars{node_string_too_long}") if length($daten{snmp_node}) > 75;
$gip->print_error("$client_id","$$lang_vars{introduce_community_string_message}") if ( ! $daten{'community_string'} );
$gip->print_error("$client_id","$$lang_vars{community_string_too_long}") if length($daten{community_string}) > 35 ;
$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (1)") if ($daten{snmp_version} !~ /^[123]$/ );
if ( $process_networks_v4 ) {
	$process_networks_v4 =~ s/\s//g;
	$gip->print_error("$client_id","$$lang_vars{process_only_net_v4_format_message} $daten{process_networks_v4}") if ( $daten{process_networks_v4} =~ m/[^0123456789.]/ );
}
if ( $process_networks_v6 ) {
	$process_networks_v6 =~ s/\s//g;
#	$gip->print_error("$client_id","$$lang_vars{process_only_net_v6_format_message} $process_networks_v6") if ( $daten{process_networks_v6} !~ m/[0-9a-fA-F:]/ );
	$gip->print_error("$client_id","$$lang_vars{process_only_net_v6_format_message} $process_networks_v6") if ( $daten{process_networks_v6} =~ m/[^0123456789abcdefABCDEF:]/ );
}

my $align="align=\"right\"";
my $align1="";
my $ori="left";
my $rtl_helper="<font color=\"white\">x</font>";
if ( $vars_file =~ /vars_he$/ ) {
	$align="align=\"left\"";
	$align1="align=\"right\"";
	$ori="right";
}

my $node=$daten{'snmp_node'};
my $community=$daten{'community_string'};

my $snmp_version=$daten{snmp_version};
my $add_comment;
$add_comment=$daten{'add_comment'} if $daten{'add_comment'};
$add_comment="n" if ! $add_comment;
my $sync=$daten{'mark_sync'} || "n";

my @config = $gip->get_config("$client_id");
my $smallest_bm = $config[0]->[0] || "16";
my $smallest_bm6 = $config[0]->[7] || "64";

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
#	$auth_is_key=$daten{'auth_is_key'} || "";
	$priv_proto=$daten{'priv_proto'} || "";
	$priv_pass=$daten{'priv_pass'} || "";
#	$priv_is_key=$daten{'priv_is_key'} || "";
	$sec_level=$daten{'sec_level'} || "";
	$gip->print_error("$client_id","$$lang_vars{introduce_community_string_message}") if ! $community;
	$gip->print_error("$client_id","$$lang_vars{introduce_auth_pass_message}") if $auth_proto && ! $auth_pass;
	$gip->print_error("$client_id","$$lang_vars{introduce_auth_proto_message}") if $auth_pass && ! $auth_proto;
	$gip->print_error("$client_id","$$lang_vars{introduce_priv_pass_message}") if $priv_proto && ! $priv_pass;
	$gip->print_error("$client_id","$$lang_vars{introduce_priv_proto_message}") if $priv_pass && ! $priv_proto;
	$gip->print_error("$client_id","$$lang_vars{introduce_priv_auth_missing_message}") if $priv_proto && ( ! $auth_proto || ! $auth_pass );
	if ( $auth_pass ) {
		$gip->print_error("$client_id","$$lang_vars{auth_pass_characters_message} $auth_pass") if $auth_pass !~ /^.{8,50}$/;
	}
	if ( $priv_pass ) {
		$gip->print_error("$client_id","$$lang_vars{priv_pass_characters_message}") if $priv_pass !~ /^.{8,50}$/;
	}
}


if ( $ip_version eq "v4" ) {
	if ( $node !~ /^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})$/ ) {
		$gip->print_error("$client_id","$$lang_vars{ip_invalido_message} <b>$node</b>");
	}
} else {
	my $valid_v6 = $gip->check_valid_ipv6("$node") || "0";
	$gip->print_error("$client_id","$$lang_vars{no_valid_ipv6_address_message} <b>$node</b>") if $valid_v6 != "1";
}

my $session=$gip->create_snmp_session("$client_id","$node","$community","$community_type","$snmp_version","$auth_pass","$auth_proto","$auth_is_key","$priv_proto","$priv_pass","$priv_is_key","$sec_level","$vars_file") || $gip->print_end("$client_id");;

print "<br><span style=\"float: $ori;\">$$lang_vars{importing_networks_message}${rtl_helper}</span><br>\n";

my ($ipRouteProto,$route_dest_cidr,$route_dest_cidr_mask,$comment);
my @route_dests_cidr;
if ( $import_ipv4 eq "ipv4" ) {

	### ipCidrRouteDest


	my $vars = new SNMP::VarList(['ipCidrRouteDest'],
				['ipCidrRouteMask'],
				['ipCidrRouteProto']);

	# get first row
	($route_dest_cidr) = $session->getnext($vars);
	my $first_query_ok = "0";
	if ($session->{ErrorStr}) {
		if ( $session->{ErrorStr} =~ /nosuchname/i ) {
	#		print "<p><br><b>$node</b>: $$lang_vars{nosuchname_snmp_error_message}\n";
		} elsif ( $session->{ErrorStr} =~ /authentication failure/i ) {
			print "<p><b>$node</b>: $$lang_vars{snmp_authentication_error}<br>\n";
			print "<p><br><p><FORM><INPUT TYPE=\"BUTTON\" VALUE=\"$$lang_vars{atras_message}\" ONCLICK=\"history.go(-1)\" class=\"error_back_link\"></FORM>\n";
			$gip->print_end("$client_id");
		} else {
			print "<p><b>$node</b>: $$lang_vars{snmp_connect_error_message}<br>\n";
			print "<p>$session->{ErrorStr}<p><br>$$lang_vars{comprobar_host_and_community_message}<br>" if $snmp_version == 1 || $snmp_version == 2;
			print "<p><br><p><FORM><INPUT TYPE=\"BUTTON\" VALUE=\"$$lang_vars{atras_message}\" ONCLICK=\"history.go(-1)\" class=\"error_back_link\"></FORM>\n";
			$gip->print_end("$client_id");
		}
	} else {
		$first_query_ok = "1";
	}

	# and all subsequent rows
	my $l = "0";
	while (!$session->{ErrorStr} and 
	       $$vars[0]->tag eq "ipCidrRouteDest"){
		($route_dest_cidr,$route_dest_cidr_mask,$ipRouteProto) = $session->getnext($vars);
		$comment = "";
		if ( $ipRouteProto =~ /local/ && $local_routes ) {
			$comment = "Local route from $node" if $add_comment eq "y";
		} elsif ( $ipRouteProto =~ /netmgmt/ && $static_routes ) {
			$comment = "Static route from $node" if $add_comment eq "y";
		} elsif ( $ipRouteProto =~ /other/ && $other_routes ) {
			$comment = "route from $node (proto: other)" if $add_comment eq "y";
		} elsif ( $ipRouteProto =~ /ospf/ && $ospf_routes ) {
			$comment = "OSPF route from $node" if $add_comment eq "y";
		} elsif ( $ipRouteProto =~ /^rip$/ && $rip_routes ) {
			$comment = "RIP route from $node" if $add_comment eq "y";
		} elsif ( $ipRouteProto =~ /^isIs$/ && $isis_routes ) {
			$comment = "Dual IS-IS route from $node" if $add_comment eq "y";
		} elsif ( $ipRouteProto =~ /ciscoEigrp/ && $eigrp_routes ) {
			$comment = "Eigrp route from $node" if $add_comment eq "y";
		}
		if (( $ipRouteProto =~ /local/ && $local_routes ) || ( $ipRouteProto =~ /netmgmt/ && $static_routes ) || ( $ipRouteProto =~ /other/ && $other_routes ) || ( $ipRouteProto =~ /ospf/ && $ospf_routes ) || ( $ipRouteProto =~ /^rip$/ && $rip_routes ) || ( $ipRouteProto =~ /isIs/ && $isis_routes ) || ( $ipRouteProto =~ /ciscoEigrp/ && $eigrp_routes )) {
			if ( $route_dest_cidr_mask =~ /\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/ ) {
				$route_dest_cidr_mask =~ /(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})/;
				my ($first_oct,$second_oct,$third_oct,$fourth_oct);
				$first_oct=$1;
				$second_oct=$2;
				$third_oct=$3;
				$fourth_oct=$4;
				if ( $fourth_oct > $first_oct ) {
					$route_dest_cidr_mask = $fourth_oct . "." . $third_oct . "." . $second_oct . "." . $first_oct;
				} else {
					$route_dest_cidr_mask = $first_oct . "." . $second_oct . "." . $third_oct . "." . $fourth_oct;
				}
			}
			if ( $add_comment eq "y" ) {
				$route_dests_cidr[$l] = "$route_dest_cidr/$route_dest_cidr_mask/$comment"; 
			} else {
				$route_dests_cidr[$l] = "$route_dest_cidr/$route_dest_cidr_mask"; 
			}
		}
		$l++;
	};


	### ipRouteDest

	my ($route_dest,$route_mask,$route_proto);

	$vars = new SNMP::VarList(['ipRouteDest'],
				['ipRouteMask'],
				['ipRouteProto']);

	# get first row
	($route_dest) = $session->getnext($vars);
	if ($session->{ErrorStr} && $first_query_ok ne "1" ) {
		if ( $session->{ErrorStr} =~ /nosuchname/i ) {
			print "<p><br><b>$node</b>: $$lang_vars{nosuchname_snmp_error_message}\n";
			print "<p><br><p><FORM><INPUT TYPE=\"BUTTON\" VALUE=\"$$lang_vars{atras_message}\" ONCLICK=\"history.go(-1)\" class=\"error_back_link\"></FORM>\n";
			$gip->print_end("$client_id");
		} else {
			print "<p><b>$node</b>: $$lang_vars{snmp_connect_error_message}<br>\n";
			print "<p>$session->{ErrorStr}<p><br>$$lang_vars{comprobar_host_and_community_message}<br>" if $snmp_version == 1 || $snmp_version == 2;
			print "<p><br><p><FORM><INPUT TYPE=\"BUTTON\" VALUE=\"$$lang_vars{atras_message}\" ONCLICK=\"history.go(-1)\" class=\"error_back_link\"></FORM>\n";
			$gip->print_end("$client_id");
		}
	}

	# and all subsequent rows
	while (!$session->{ErrorStr} and 
	       $$vars[0]->tag eq "ipRouteDest"){
		($route_dest,$route_mask,$route_proto) = $session->getnext($vars);
		$comment = "";
		if ( $route_proto =~ /local/ && $local_routes ) {
			$comment = "Local route from $node" if $add_comment eq "y";
		} elsif ( $route_proto =~ /netmgmt/ && $static_routes ) {
			$comment = "Static route from $node" if $add_comment eq "y";
		} elsif ( $route_proto =~ /other/ && $other_routes ) {
			$comment = "route from $node (proto: other)" if $add_comment eq "y";
		} elsif ( $route_proto =~ /ospf/ && $ospf_routes ) {
			$comment = "OSPF route from $node" if $add_comment eq "y";
		} elsif ( $route_proto =~ /^rip$/ && $rip_routes ) {
			$comment = "RIP route from $node" if $add_comment eq "y";
		} elsif ( $route_proto =~ /^isIs$/ && $isis_routes ) {
			$comment = "Dual IS-IS route from $node" if $add_comment eq "y";
		} elsif ( $route_proto =~ /ciscoEigrp/ && $eigrp_routes ) {
			$comment = "Eigrp route from $node" if $add_comment eq "y";
		}
		if (( $route_proto =~ /local/ && $local_routes ) || ( $route_proto =~ /netmgmt/ && $local_routes ) || ( $route_proto =~ /other/ && $other_routes ) || ( $route_proto =~ /ospf/ && $ospf_routes ) || ( $route_proto =~ /^rip$/ && $rip_routes ) || ( $route_proto =~ /isIs/ && $isis_routes ) || ( $route_proto =~ /ciscoEigrp/ && $eigrp_routes )) {
			if ( $add_comment eq "y" ) {
				$route_dests_cidr[$l] = "$route_dest/$route_mask/$comment"; 
			} else {
				$route_dests_cidr[$l] = "$route_dest/$route_mask"; 
			}
		}
		$l++;
	};
}


##### IPv6 Routes

my @route_dests_cidr_ipv6;

if ( $import_ipv6 eq "ipv6" ) {
	my $l=0;

	my @ip_arr;
	my $vb = new SNMP::Varbind();
	do {
		my $val = $session->getnext($vb);
		if (( @{$vb}[0] =~ /inetCidrRouteProto/ ) && @{$vb}[1] =~ /^\d{1,3}\.\d{1,3}\.((\d{1,3}\.){16})(\d{1,3})(\.\d{1,3}){16}/ ) {
			@{$vb}[1] =~ /^\d{1,3}\.\d{1,3}\.((\d{1,3}\.){16})(\d{1,3})/;
			my $ip_dec=$1;
			my $ip_mask=$3;
			my $route_proto = @{$vb}[2];

			if ( $ip_mask ne "128" ) {

				$ip_dec =~ s/\./ /g;
				@ip_arr = split(" ",$ip_dec);

				my $m="0";
				my $ipv6="";
				foreach (@ip_arr) {
					my $hex=unpack("H*", pack("N", $ip_arr[$m]));
					$hex =~ s/^0{6}//;
					if ( $m == 1 || $m ==3 || $m == 5 || $m == 7 || $m == 9 || $m == 11 || $m == 13 ) {
						$ipv6 .= $hex . ":";
					} else {
						$ipv6 .= $hex;
					}
					$m++;
				}

				$comment = "";
				if ( $route_proto =~ /local/ && $local_routes ) {
					$comment = "Local route from $node" if $add_comment eq "y";
				} elsif ( $route_proto =~ /netmgmt/ && $static_routes ) {
					$comment = "Static route from $node" if $add_comment eq "y";
				} elsif ( $route_proto =~ /other/ && $other_routes ) {
					$comment = "route from $node (proto: other)" if $add_comment eq "y";
				} elsif ( $route_proto =~ /ospf/ && $ospf_routes ) {
					$comment = "OSPF route from $node" if $add_comment eq "y";
				} elsif ( $route_proto =~ /^rip$/ && $rip_routes ) {
					$comment = "RIP route from $node" if $add_comment eq "y";
				} elsif ( $route_proto =~ /^isIs$/ && $isis_routes ) {
					$comment = "Dual IS-IS route from $node" if $add_comment eq "y";
				} elsif ( $route_proto =~ /ciscoEigrp/ && $eigrp_routes ) {
					$comment = "Eigrp route from $node" if $add_comment eq "y";
				}
				if (( $route_proto =~ /local/ && $local_routes ) || ( $route_proto =~ /netmgmt/ && $local_routes ) || ( $route_proto =~ /other/ && $other_routes ) || ( $route_proto =~ /ospf/ && $ospf_routes ) || ( $route_proto =~ /^rip$/ && $rip_routes ) || ( $route_proto =~ /isIs/ && $isis_routes ) || ( $route_proto =~ /ciscoEigrp/ && $eigrp_routes )) {
					if ( $add_comment eq "y" ) {
						$route_dests_cidr_ipv6[$l] = "$ipv6/$ip_mask/$comment"; 
					} else {
						$route_dests_cidr_ipv6[$l] = "$ipv6/$ip_mask"; 
					}
				}
				$l++;
			}
		}
	} until ($session->{ErrorNum});



	### ipv6RouteProtocol

	my ($route_dest,$route_mask,$route_proto);

	my $vars = new SNMP::VarList(['ipv6RouteProtocol']
				);

	# get first row
	($route_dest) = $session->getnext($vars);
	if ($session->{ErrorStr} ) {
		if ( $session->{ErrorStr} =~ /nosuchname/i ) {
			print "<p><br><b>$node</b>: $$lang_vars{nosuchname_snmp_error_message}\n";
			print "<p><br><p><FORM><INPUT TYPE=\"BUTTON\" VALUE=\"$$lang_vars{atras_message}\" ONCLICK=\"history.go(-1)\" class=\"error_back_link\"></FORM>\n";
			$gip->print_end("$client_id");
		} else {
			print "<p><b>$node</b>: $$lang_vars{snmp_connect_error_message}<br>\n";
			print "<p>$session->{ErrorStr}<p><br>$$lang_vars{comprobar_host_and_community_message}<br>" if $snmp_version == 1 || $snmp_version == 2;
			print "<p><br><p><FORM><INPUT TYPE=\"BUTTON\" VALUE=\"$$lang_vars{atras_message}\" ONCLICK=\"history.go(-1)\" class=\"error_back_link\"></FORM>\n";
			$gip->print_end("$client_id");
		}
	}


	# and all subsequent rows


	while (!$session->{ErrorStr} and 
	       $$vars[0]->tag eq "ipv6RouteProtocol"){
		($route_dest) = $session->getnext($vars);

		my $iid=$$vars[0]->iid;
		$iid =~ /^((\d{1,3}\.){16})(.+).*$/;
		my $ip_dec=$1;
		$ip_dec =~ s/\.$//;
		$iid =~ /(\d{1,3})\.\d{1,3}$/;
		my $ip_mask=$1;
		my $route_proto = $$vars[0]->val;

		next if $ip_mask eq "128";

		$ip_dec =~ s/\./ /g;
		@ip_arr = split(" ",$ip_dec);

		my $m="0";
		my $ipv6="";
		foreach (@ip_arr) {
			my $hex=unpack("H*", pack("N", $ip_arr[$m]));
			$hex =~ s/^0{6}//;
			if ( $m == 1 || $m ==3 || $m == 5 || $m == 7 || $m == 9 || $m == 11 || $m == 13 ) {
				$ipv6 .= $hex . ":";
			} else {
				$ipv6 .= $hex;
			}
			$m++;
		}
		$route_dest=$ipv6;

		$route_mask=$ip_mask;
		$comment = "";
		if ( $route_proto =~ /local/ && $local_routes ) {
			$comment = "Local route from $node" if $add_comment eq "y";
		} elsif ( $route_proto =~ /netmgmt/ && $static_routes ) {
			$comment = "Static route from $node" if $add_comment eq "y";
		} elsif ( $route_proto =~ /other/ && $other_routes ) {
			$comment = "route from $node (proto: other)" if $add_comment eq "y";
		} elsif ( $route_proto =~ /ospf/ && $ospf_routes ) {
			$comment = "OSPF route from $node" if $add_comment eq "y";
		} elsif ( $route_proto =~ /^rip$/ && $rip_routes ) {
			$comment = "RIP route from $node" if $add_comment eq "y";
		} elsif ( $route_proto =~ /^isIs$/ && $isis_routes ) {
			$comment = "Dual IS-IS route from $node" if $add_comment eq "y";
		} elsif ( $route_proto =~ /ciscoEigrp/ && $eigrp_routes ) {
			$comment = "Eigrp route from $node" if $add_comment eq "y";
		}
		if (( $route_proto =~ /local/ && $local_routes ) || ( $route_proto =~ /netmgmt/ && $local_routes ) || ( $route_proto =~ /other/ && $other_routes ) || ( $route_proto =~ /ospf/ && $ospf_routes ) || ( $route_proto =~ /^rip$/ && $rip_routes ) || ( $route_proto =~ /isIs/ && $isis_routes ) || ( $route_proto =~ /ciscoEigrp/ && $eigrp_routes )) {
			if ( $add_comment eq "y" ) {
				$route_dests_cidr_ipv6[$l] = "$route_dest/$route_mask/$comment"; 
			} else {
				$route_dests_cidr_ipv6[$l] = "$route_dest/$route_mask"; 
			}
		}
		$l++;
	};
}

my @process_networks_v4=();
if ( $process_networks_v4 ) {
	@process_networks_v4=split(",",$process_networks_v4);
}

# delete duplicated entries
my %seen = ();
my $item;
my @uniq;
my $ignore_red;
foreach $item(@route_dests_cidr) {
	next if ! $item;
	my $ignore_red=0;
	if ( $process_networks_v4[0] ) {
		$ignore_red="1" ;
		foreach ( @process_networks_v4 ) {
			my $pnet=$_;
			$pnet =~ s/\./\\./;
			$pnet =~ s/\*/.\*/;
			if ( $item =~ m/^$pnet/ ) {
				$ignore_red="0";
				last;
			}
		}
	}
	if ( $ignore_red==0 ) {
		push(@uniq, $item) unless $seen{$item}++;
	}
}
@route_dests_cidr = @uniq;


my @process_networks_v6=();
if ( $process_networks_v6 ) {
	@process_networks_v6=split(",",$process_networks_v6);
}

%seen = ();
@uniq = ();
foreach $item(@route_dests_cidr_ipv6) {
	next if ! $item;
	my $ignore_red=0;
	if ( $process_networks_v6[0] ) {
		$ignore_red="1" ;
		foreach ( @process_networks_v6 ) {
			my $pnet=$_;
			$pnet =~ s/\./\\./;
			$pnet =~ s/\*/.\*/;
			if ( $item =~ m/^$pnet/ ) {
				$ignore_red="0";
				last;
			}
		}
	}
	if ( $ignore_red==0 ) {
		push(@uniq, $item) unless $seen{$item}++;
	}
}
@route_dests_cidr_ipv6 = @uniq;

my $red_num=$gip->get_last_red_num();
$red_num++;

my @overlap_redes=$gip->get_overlap_red("v4","$client_id");
my @overlap_redes6=$gip->get_overlap_red("v6","$client_id");


my ($network_cidr_mask, $network_no_cidr, $BM);

print "<span class=\"sinc_text\"><p>";

foreach $network_cidr_mask(@route_dests_cidr) {
	$ip_version = "v4";

	next if ! $network_cidr_mask;
	next if $network_cidr_mask =~ /0.0.0.0/ || $network_cidr_mask =~ /169.254.0.0/;
	$comment="";
	my ($network,$mask);
	if ( $add_comment eq "y" ) {
		($network,$mask,$comment) = split("/",$network_cidr_mask);
	} else {
		($network,$mask) = split("/",$network_cidr_mask);
	}
	# Convert netmasks to bitmasks
	$BM=$gip->convert_mask("$client_id","$network","$mask","$vars_file");
	next if ! $BM; 

	# Check if network is valid
	my $check_redob = $network . "/" . $BM;
	my $check_ipob = new Net::IP ($check_redob);
	if ( ! $check_ipob ) {
		print "<b>$network/$BM</b> - $$lang_vars{red_invalido_message} - $$lang_vars{ignorado_message}<br>\n";
		next;
	}
	
	# check if bitmask is to small
	if ( $BM < $smallest_bm ) {
		if ( $vars_file =~ /vars_he$/ ) {
			print "<span style=\"float: $ori\">$$lang_vars{ignorado_message} - $smallest_bm - $$lang_vars{bm_not_allowed_message} :<b>$network/$BM</b></span><br>\n";
		} else {
			print "<b>$network/$BM</b>: $$lang_vars{bm_not_allowed_message} $smallest_bm - $$lang_vars{ignorado_message}<br>\n";
		}
		next;
	} 

	# Check for overlapping networks
	if ( $overlap_redes[0]->[0] ) {
		my @overlap_found = $gip->find_overlap_redes("$client_id","$network","$BM",\@overlap_redes,"$ip_version","$vars_file","","","1");
		if ( $overlap_found[0] ) {
			if ( $vars_file =~ /vars_he$/ ) {
				print "<span style=\"float: $ori\">$$lang_vars{ignorado_message} -  $$lang_vars{overlaps_con_message} <b>$network/$BM</b></span><br>\n"; 
			} else {
				print "<b>$network/$BM</b> $$lang_vars{overlaps_con_message} $overlap_found[0] - $$lang_vars{ignorado_message}<br>\n"; 
			}
			next;
		}
	}

	# insert networks into the database
	if ( $vars_file =~ /vars_he$/ ) {
		print "<span style=\"float: $ori\">$$lang_vars{host_anadido_message} :<b>$network/$BM</b></span><br>\n";
	} else {
		print "<b>$network/$BM</b>: $$lang_vars{host_anadido_message}<br>\n";
	}
	$red_num++;
	if ( $add_comment eq "y" ) {
		$gip->insert_net("$client_id","$red_num","$network","$BM",'','-1',"$sync","$comment",'-1',"$ip_version");
	} else {
		$gip->insert_net("$client_id","$red_num","$network","$BM",'','-1',"$sync",'','-1',"$ip_version");
	}

	my $audit_type="17";
	my $audit_class="2";
	my $update_type_audit="7";
	my $descr="---";
	$comment="---" if ! $comment;
	my $vigilada = "n";
	my $site_audit = "---";
	my $cat_audit = "---";

	my $event="$network/$BM,$descr,$site_audit,$cat_audit,$comment,$vigilada";
	$gip->insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");
}

foreach $network_cidr_mask(@route_dests_cidr_ipv6) {
	$ip_version = "v6";
	
	$comment="";
	my ($network,$mask);
	if ( $add_comment eq "y" ) {
		($network,$BM,$comment) = split("/",$network_cidr_mask);
	} else {
		($network,$BM) = split("/",$network_cidr_mask);
	}

#	# check if bitmask is to small
#	if ( $BM < $smallest_bm6 ) {
#		print "<b>$network/$BM</b>: $$lang_vars{bm_not_allowed_message} $smallest_bm6 - $$lang_vars{ignorado_message}<br>\n";
#		next;
#	} 

	my $rootnet_val="0";
	$rootnet_val=1 if $BM < 64;

	my $ignore_rootnet="1";
	if ( $rootnet_val == 1 ) {
		$ignore_rootnet="0";
	}

	my $red_exists=$gip->check_red_exists("$client_id","$network","$BM","$ignore_rootnet") if $rootnet_val == 1;

	if ( $red_exists ) {
		if ( $vars_file =~ /vars_he$/ ) {
			print "<span style=\"float: $ori\">$$lang_vars{ignorado_message} - $$lang_vars{red_exists_message} <b>$network/$BM</b><br>\n";
		} else {
			print "<b>$network/$BM</b> $$lang_vars{red_exists_message} - $$lang_vars{ignorado_message}<br>\n";
		}
		next;
	}

	# Check for overlapping networks
	if ( $overlap_redes[0]->[0] && $rootnet_val == 0 ) {
		my @overlap_found = $gip->find_overlap_redes("$client_id","$network","$BM",\@overlap_redes6,"$ip_version","$vars_file","","","1");
		if ( $overlap_found[0] ) {
			if ( $vars_file =~ /vars_he$/ ) {
				print "<span style=\"float: $ori\">$$lang_vars{ignorado_message} - $$lang_vars{overlaps_con_message} <b>$network/$BM</b></span><br>\n"; 
			} else {
				print "<b>$network/$BM</b> $$lang_vars{overlaps_con_message} $overlap_found[0] - $$lang_vars{ignorado_message}<br>\n"; 
			}
			next;
		}
	}

	# insert networks into the database
	if ( $vars_file =~ /vars_he$/ ) {
		print "<span style=\"float: $ori\">$$lang_vars{host_anadido_message} :<b>$network/$BM</b></span><br>\n";
	} else {
		print "<b>$network/$BM</b>: $$lang_vars{host_anadido_message}<br>\n";
	}
	$red_num++;
	if ( $add_comment eq "y" ) {
		$gip->insert_net("$client_id","$red_num","$network","$BM",'','-1',"$sync","$comment",'-1',"$ip_version","$rootnet_val");
	} else {
		$gip->insert_net("$client_id","$red_num","$network","$BM",'','-1',"$sync",'','-1',"$ip_version","$rootnet_val");
	}

	my $audit_type="17";
	my $audit_class="2";
	my $update_type_audit="7";
	my $descr="---";
	$comment="---" if ! $comment;
	my $vigilada = "n";
	my $site_audit = "---";
	my $cat_audit = "---";

	my $event="$network/$BM,$descr,$site_audit,$cat_audit,$comment,$vigilada";
	$gip->insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");
}

print "</span>\n";

if ( $import_ipv4 eq "ipv4" && ! $route_dests_cidr[0] ) {
	print "<span style=\"float: $ori\">${rtl_helper}$$lang_vars{no_matching_networks_v4_found_message}</span><br>\n";
}
if (  $import_ipv6 eq "ipv6" && ! $route_dests_cidr_ipv6[0] ) {
	print "<span style=\"float: $ori\">${rtl_helper}$$lang_vars{no_matching_networks_v6_found_message}</span><br>\n";
}

print "<br><h3 style=\"float: $ori\">$$lang_vars{listo_message}</h3>\n";


$gip->print_end("$client_id");
