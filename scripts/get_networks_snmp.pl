#!/usr/bin/perl -w

# Script for importing networks from the routing tables via SNMP
# into the database of GestioIP.

# you have to configure some parameters directly in this script.
# See documentation for more information

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
use Net::IP;
use DBI;
use Mail::Mailer;
use FindBin qw($Bin);


my $VERSION="3.0.0";

#########################################
### change from here... #################
#########################################


# Name of the configuration file in ../etc
my $config_name="ip_update_gestioip.conf";

# Change value of $mail to "1" if
# want to receive a summery via mail. Default: "0"
my $mail="0";

# Where to send the report - mail address.
# comma separated list.
my $mail_destinatarios = '';

# Change "your-domain.org to your domain
my $mail_from = 'GestioIP@your-domain.org';

# Directory to store the logfile
my $logdir=".";

# Configure here the smallest allowed bitmask
my $smallest_bitmask="16";

# set $add_comment to "0" if the script shouldn't
# add a comments like "Local route from 192.168.214.33"
# to the new network entries. Default: "1"
my $add_comment="1";

# set $set_sync_flag to "0" if you don't want that found networks
# are included within automatic update. Default: "1"
my $set_sync_flag="1";

# Set route_proto_other to "1" if you want that routes with ipRouteProto=other(1)
# be added to GestioIP's database. Default="0" 
my $route_proto_other="0";

# set $verbose to "0" if you want a silent run. Default="1"
my $verbose = "1";

my $ipv4="1";
my $ipv6="1";

my $local_routes=1;
my $static_routes=1;
my $other_routes=1;
my $ospf_routes=1;
my $rip_routes=1;
my $isis_routes=1;
my $eigrp_routes=1;


# Process only IPv4 networks starting with...
# coma separated list
# Strings to match IPv6 networks must be introduced in uncompressed format
# An empty list means that all found networks will be processed
# Default: ""
# e.g. a value of "192.168,172.16." causes that all networks 192.168.x.y and 172.16.y.z will 
# be imported; all other networks will be ignored
my $process_networks_v4="";

# Process only IPv6 networks starting with...
# coma separated list
# Strings to match IPv6 networks must be introduced in uncompressed format
# An empty list means that all found networks will be processed
# Default: ""
# e.g. a value of "2001::" causes that only networks starting with "2001::" will be imported
# be imported; all other networks will be ignored
my $process_networks_v6="";



#########################################
#### ...to here #########################
#########################################


# if the script doesn't find it's configuration file
# set it here the apsolute path to configuration file
# manually and commnet out the line
# 'my $dir = $Bin;'
my $dir = $Bin;

$dir =~ /^(.*)\/bin/;
my $base_dir=$1;


# my $dir = "/apsolute/path/to/$config_name";

if ( ! -r "${base_dir}/etc/${config_name}" ) {
        print "\nCan't find configuration file \"$config_name\"\n";
        print "\n\"${base_dir}/etc/${config_name}\" doesn't exists\n";
        exit 1;
}

my $conf = $base_dir . "/etc/" . $config_name;

my $nodes_file="$base_dir/etc/snmp_targets";

my %params;

open(VARS,"<$conf") or die "Can not open $conf: $!\n";
while (<VARS>) {
        chomp;
        s/#.*//;
        s/^\s+//;
        s/\s+$//;
        next unless length;
        my ($var, $value) = split(/\s*=\s*/, $_, 2);
        $params{$var} = $value;
}
close VARS;

my $gip_version=get_version();

if ( $VERSION !~ /$gip_version/ ) {
        print "\nScript and GestioIP version are not compatible\n\nGestioIP version: $gip_version - script version: $VERSION\n\n";
        exit 1;
}

my $lang=$params{lang} || "en";
my $vars_file="$base_dir/etc/vars/vars_update_gestioip_" . $lang;

my %lang_vars;

open(LANGVARS,"<$vars_file") or die "Can not open $vars_file: $!\n";
while (<LANGVARS>) {
        chomp;
        s/#.*//;
        s/^\s+//;
        s/\s+$//;
        next unless length;
        my ($var, $value) = split(/\s*=\s*/, $_, 2);
        $lang_vars{$var} = $value;
}
close LANGVARS;

my $client_name_conf = $params{client};
my $client_count = count_clients();
my $client_id;
if ( $client_count == "1" ) {
        my $one_client_name = check_one_client_name("$client_name_conf") || "";
        if ( $one_client_name eq $client_name_conf || $client_name_conf eq "DEFAULT" ) {
                $client_id=get_client_id_one() || "";
        }
} else {
        $client_id=get_client_id_from_name("$client_name_conf") || "";
}

if ( ! $client_id ) {
        print "$client_name_conf: $lang_vars{client_not_found_message} $conf\n";
        exit 1;
}


my $snmp_version=$params{'snmp_version'};
if ( ! $snmp_version ) {
        print "Please configure parameter \"snmp_version\" in the configuration file\n";
        exit 1;
}
my $community=$params{'snmp_community_string'} if $snmp_version ne "3";
$community=$params{'snmp_user_name'} if $snmp_version eq "3";
my $sec_level= "";
my $auth_proto= "";
my $auth_pass= "";
my $priv_proto= "";
my $priv_pass= "";
my $auth_is_key="";
my $priv_is_key="";

if ( $snmp_version eq "3" ) {
	$sec_level= $params{'sec_level'};
	$auth_proto= $params{'auth_proto'};
	$auth_pass= $params{'auth_pass'};
	$priv_proto= $params{'priv_proto'};
	$priv_pass= $params{'priv_pass'};
	if ( ! $sec_level ) {
		print "Please configure parameter \"sec_level\"\n";
		exit 1;
	}
	if ( $sec_level eq "noAuthNoPriv" ) {
		$auth_proto= "";
		$auth_pass= "";
		$priv_proto= "";
		$priv_pass= "";
		$auth_is_key="";
		$priv_is_key="";
	} elsif ( $sec_level eq "authNoPriv" ) {
		$priv_proto= "";
		$priv_pass= "";
		$auth_is_key="";
		$priv_is_key="";
	} elsif ( $sec_level eq "authPriv" ) {
		$auth_is_key="";
		$priv_is_key="";
	} else {
		print "\"sec_level\" must be either noAuthNoPriv, authNoPriv or authPriv\n";
		exit 1;
	}
	
	if ( $sec_level eq "authNoPriv" && ! $auth_proto ) {
		print "Please configure parameter \"auth_proto\"\n";
		exit 1;
	} elsif ( $sec_level eq "authNoPriv" && ! $auth_pass ) {
		print "Please configure parameter \"auth_pass\"\n";
		exit 1;
	} elsif ( $sec_level eq "authPriv" && ! $auth_proto ) {
		print "Please configure parameter \"auth_proto\"\n";
		exit 1;
	} elsif ( $sec_level eq "authPriv" && ! $auth_pass ) {
		print "Please configure parameter \"auth_pass\"\n";
		exit 1;
	} elsif ( $sec_level eq "authPriv" && ! $priv_proto ) {
		print "Please configure parameter \"priv_proto\"\n";
		exit 1;
	} elsif ( $sec_level eq "authPriv" && ! $priv_pass ) {
		print "Please configure parameter \"priv_pass\"\n";
		exit 1;
	}
	my $auth_pass_length=length($auth_pass);
	if ( $sec_level ne "noAuthNoPriv" && $auth_pass_length < 8 ) {
		print "auth_pass must contain at least 8 characters\n";
		exit 1;
	}
	my $priv_pass_length=length($auth_pass);
	if ( $sec_level ne "noAuthNoPriv" && $priv_pass_length < 8 ) {
		print "priv_pass must contain at least 8 characters\n";
		exit 1;
	}
}

		
if ( ! $community ) {
        print "Please configure parameter \"snmp_community_string\"\n" if $snmp_version ne "3";
        print "Please configure parameter \"snmp_user_name\"\n" if $snmp_version eq "3";
        exit 1;
}
my $community_type="Community";
if ( $snmp_version == "3" ) {
        $community_type = "SecName";
}

my ($s, $mm, $h, $d, $m, $y) = (localtime) [0,1,2,3,4,5];
$m++;
$y+=1900;
if ( $d =~ /^\d$/ ) { $d = "0$d"; }
if ( $s =~ /^\d$/ ) { $s = "0$s"; }
if ( $m =~ /^\d$/ ) { $m = "0$m"; }
if ( $mm =~ /^\d$/ ) { $mm = "0$mm"; }

my $log;
if ( ! $log ) { $log="$logdir/$y$m$d$h$mm$s.get_networks_snmp_gestioip.log"; }
open(LOG,">$log") or die "$log: $!\n";
print LOG "$y$m$d$h$mm$s get_networks_snmp.pl LOG\n\n";

my $mail_destinatarios_ref = \$mail_destinatarios;
my $mail_from_ref = \$mail_from;


my $red_num = get_last_red_num() || "1";

my @all_db_networks = get_all_networks("$client_id","v4") if $ipv4;
my @all_db_networks6 = get_all_networks("$client_id","v6") if $ipv6;

open(IN,"<$nodes_file") or die "Can't open $nodes_file: $!\n";

my $node;

my @nodes;
my $i="0";

while (<IN>) {
	$node = $_;
	next if $node =~ /^#/;
	next if $node !~ /.+/; 
	chomp ($node);
	$nodes[$i]=$node;
	$i++;
}

if ( ! $nodes[0] ) {
	print "\nNo nodes configured - please configure the nodes to query in $nodes_file\n\n";
	exit 1;
}

foreach ( @nodes ) {
	$node = $_;
	print "\n+++ Importing networks from $node +++\n\n" if $verbose == "1";
	print LOG "\n+++ Importing networks from $node +++\n\n";


	 my $session=create_snmp_session("$client_id","$node","$community","$community_type","$snmp_version","$auth_pass","$auth_proto","$auth_is_key","$priv_proto","$priv_pass","$priv_is_key","$sec_level");

	next if ! $session;

	my ($ipRouteProto,$route_dest_cidr,$route_dest_cidr_mask,$comment);
	my @route_dests_cidr;

	if ( $ipv4 ) {
		### ipCidrRouteDest
		my $first_query_ok = "0";

		my ($ipRouteProto,$route_dest_cidr,$route_dest_cidr_mask);

		my $vars = new SNMP::VarList(['ipCidrRouteDest'],
					['ipCidrRouteMask'],
					['ipCidrRouteProto']);

		# get first row
		($route_dest_cidr) = $session->getnext($vars);
		if ($session->{ErrorStr}) {
#			print LOG "Can't connect to $node\n";
#			print "Can't connect to $node (2)\n" if $verbose == "1";
#			next;
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
                                $comment = "Local route from $node" if $add_comment == "1";
                        } elsif ( $ipRouteProto =~ /netmgmt/ && $static_routes ) {
                                $comment = "Static route from $node" if $add_comment == "1";
                        } elsif ( $ipRouteProto =~ /other/ && $other_routes ) {
                                $comment = "route from $node (proto: other)" if $add_comment == "1";
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
                                if ( $add_comment == "1" ) {
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
				print LOG "$node: $lang_vars{nosuchname_snmp_error_message}\n";
				print "$lang_vars{nosuchname_snmp_error_message}\n" if $verbose == "1";
                        } else {
				print LOG "Can't connect to $node\n";
				print "Can't connect to $node (3)\n" if $verbose == "1";
			}
			next;
		}

	

		# and all subsequent rows

		while (!$session->{ErrorStr} and
                       $$vars[0]->tag eq "ipRouteDest"){
                        ($route_dest,$route_mask,$route_proto) = $session->getnext($vars);
                        $comment = "";
                        if ( $route_proto =~ /local/ && $local_routes ) {
                                $comment = "Local route from $node" if $add_comment == "1";
                        } elsif ( $route_proto =~ /netmgmt/ && $static_routes ) {
                                $comment = "Static route from $node" if $add_comment == "1";
                        } elsif ( $route_proto =~ /other/ && $other_routes == "1" ) {
                                $comment = "route from $node (proto: other)" if $add_comment == "1";
                        } elsif ( $route_proto =~ /ospf/ && $ospf_routes ) {
                                $comment = "OSPF route from $node" if $add_comment eq "y";
                        } elsif ( $route_proto =~ /^rip$/ && $rip_routes ) {
                                $comment = "RIP route from $node" if $add_comment eq "y";
                        } elsif ( $route_proto =~ /^isIs$/ && $isis_routes ) {
                                $comment = "Dual IS-IS route from $node" if $add_comment eq "y";
                        } elsif ( $route_proto =~ /ciscoEigrp/ && $eigrp_routes ) {
                                $comment = "Eigrp route from $node" if $add_comment eq "y";
                        }
			if (( $route_proto =~ /local/ && $local_routes ) || ( $route_proto =~ /netmgmt/ && $static_routes ) || ( $route_proto =~ /other/ && $other_routes ) || ( $route_proto =~ /ospf/ && $ospf_routes ) || ( $route_proto =~ /^rip$/ && $rip_routes ) || ( $route_proto =~ /isIs/ && $isis_routes ) || ( $route_proto =~ /ciscoEigrp/ && $eigrp_routes )) {
                                if ( $add_comment == "1" ) {
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

	if ( $ipv6 ) {
		my $l=0;

		my @ip_arr;
		my $vb = new SNMP::Varbind();
		do {
			my $val = $session->getnext($vb);
			if ( @{$vb}[0] =~ /inetCidrRouteProto/ && @{$vb}[1] =~ /^\d{1,3}\.\d{1,3}\.((\d{1,3}\.){16})(\d{1,3})(\.\d{1,3}){16}/ ) {
				@{$vb}[1] =~ /^\d{1,3}\.\d{1,3}\.((\d{1,3}\.){16})(\d{1,3})/;
				my $ip_dec=$1;
				my $ip_mask=$3;
				my $route_proto = @{$vb}[2];

				if ( $ip_mask ne "128" ) {

					$ip_dec =~ s/\./ /g;
					@ip_arr = split(" ",$ip_dec);

					my $m="0";
					my $ipv6_add="";
					foreach (@ip_arr) {
						my $hex=unpack("H*", pack("N", $ip_arr[$m]));
						$hex =~ s/^0{6}//;
						if ( $m == 1 || $m ==3 || $m == 5 || $m == 7 || $m == 9 || $m == 11 || $m == 13 ) {
							$ipv6_add .= $hex . ":";
						} else {
							$ipv6_add .= $hex;
						}
						$m++;
					}

					$comment = "";
					if ( $route_proto =~ /local/ && $local_routes ) {
						$comment = "Local route from $node" if $add_comment eq "y";
					} elsif ( $route_proto =~ /netmgmt/ && $static_routes ) {
						$comment = "Static route from $node" if $add_comment eq "y";
					} elsif ( $route_proto =~ /other/ && $other_routes == "1" ) {
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
							$route_dests_cidr_ipv6[$l] = "$ipv6_add/$ip_mask/$comment"; 
						} else {
							$route_dests_cidr_ipv6[$l] = "$ipv6_add/$ip_mask"; 
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
		if ($session->{ErrorStr} && ! $route_dests_cidr_ipv6[0] ) {
			if ( $session->{ErrorStr} =~ /nosuchname/i ) {
				print LOG "$node: $lang_vars{nosuchname_snmp_error_message}\n";
			} else {
				print LOG "Can't connect to $node (3)\n";
				next;
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

	# delete duplicated entries and networks with are not "process_networks_v4"
	my %seen = ();
	my $item;
	my @uniq;
	my $ignore_red;
	foreach $item(@route_dests_cidr) {
		next if ! $item;
		$ignore_red="0";
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
	@uniq=();
	$ignore_red="0";
	foreach $item(@route_dests_cidr_ipv6) {
		next if ! $item;
		$ignore_red="0";
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



	my ($network_cidr_mask, $network_no_cidr, $BM);

	foreach $network_cidr_mask(@route_dests_cidr) {
		next if ! $network_cidr_mask;
		next if $network_cidr_mask =~ /0.0.0.0/ || $network_cidr_mask =~ /169.254.0.0/;
		my ($network,$mask,$comment);
		if ( $add_comment == "1" ) {
			($network,$mask,$comment) = split("/",$network_cidr_mask);
		} else {
			($network,$mask) = split("/",$network_cidr_mask);
		}
		# Convert netmasks to bitmasks
		$BM=convert_mask("$network","$mask");
		next if ! $BM; 
		
		# check if bitmask is to small
		if ( $BM < $smallest_bitmask ) {
			print LOG "$network/$BM: Bitmask to small - IGNORED\n";
			print "$network/$BM: Bitmask to small - IGNORED\n" if $verbose == "1";
			next;
		} 

		# Check for overlapping networks
		my $overlap = check_overlap("$network","$BM",\@all_db_networks,"1");

		next if $overlap eq "1";
		my $rootnet_val="0";

		# add the network to @all_db_networks to include it in the overlap check
		# for the next network
		my $l = @all_db_networks;
		$all_db_networks[$l]->[0] = $network;
		$all_db_networks[$l]->[1] = $BM;
		$all_db_networks[$l]->[2] = $rootnet_val;

		if ( $overlap != "2" ) {
			# insert networks into the database
			print LOG "$network/$BM: ADDED\n";
			print "$network/$BM: ADDED\n" if $verbose == "1";
			$red_num++;


			if ( $add_comment == "1" ) {
				insert_networks("$network","$BM","$red_num","$comment","$client_id","$set_sync_flag","v4","$rootnet_val");
			} else {
				insert_networks("$network","$BM","$red_num","","$client_id","$set_sync_flag","v4","$rootnet_val");
			}

			my $audit_type="17";
			my $audit_class="2";
			my $update_type_audit="3";
			my $descr="---";
			$comment="---" if ! $comment;
			my $vigilada = "n";
			my $site_audit = "---";
			my $cat_audit = "---";

			my $event="$network/$BM,$descr,$site_audit,$cat_audit,$comment,$vigilada";
			insert_audit_auto("$audit_class","$audit_type","$event","$update_type_audit","$client_id");
		}

	}



	foreach $network_cidr_mask(@route_dests_cidr_ipv6) {
		
		$comment="";
		my ($network,$mask);
		if ( $add_comment eq "y" ) {
			($network,$BM,$comment) = split("/",$network_cidr_mask);
		} else {
			($network,$BM) = split("/",$network_cidr_mask);
		}

		my $rootnet_val="0";
		$rootnet_val=1 if $BM < 64;

		my $ignore_rootnet="1";
		if ( $rootnet_val == 1 ) {
			$ignore_rootnet="0";
		}


		my $red_exists=check_red_exists("$client_id","$network","$BM","$ignore_rootnet") || "";

		if ( $red_exists ) {
			print "$network/$BM $lang_vars{red_exists_message} - $lang_vars{ignorado_message}\n";
			next;
		}


		# Check for overlapping networks
		my $overlap=0;
		$overlap = check_overlap("$network","$BM",\@all_db_networks6,"1");

#		next if $overlap == "1" && $rootnet_val == 0;
		next if $overlap == "1";

		# add the network to @all_db_networks to include it in the overlap check
		# for the next network
		my $l = @all_db_networks;
		$all_db_networks[$l]->[0] = $network;
		$all_db_networks[$l]->[1] = $BM;
		$all_db_networks[$l]->[2] = $rootnet_val;

		if ( $overlap != "2" ) {
			# insert networks into the database
			print LOG "$network/$BM: ADDED\n";
			print "$network/$BM: ADDED\n" if $verbose == "1";
			$red_num++;
			if ( $add_comment == "1" ) {
				insert_networks("$network","$BM","$red_num","$comment","$client_id","$set_sync_flag","v6","$rootnet_val");
			} else {
				insert_networks("$network","$BM","$red_num","","$client_id","$set_sync_flag","v6","$rootnet_val");
			}

			my $audit_type="17";
			my $audit_class="2";
			my $update_type_audit="3";
			my $descr="---";
			$comment="---" if ! $comment;
			my $vigilada = "n";
			my $site_audit = "---";
			my $cat_audit = "---";

			my $event="$network/$BM,$descr,$site_audit,$cat_audit,$comment,$vigilada";
			insert_audit_auto("$audit_class","$audit_type","$event","$update_type_audit","$client_id");
		}
	}



	if ( $process_networks_v4 && ! $route_dests_cidr[0] ) {
		print "No matching IPv4 networks found\n" if $verbose == "1";
	}
	if (  $process_networks_v6 && ! $route_dests_cidr_ipv6[0] ) {
		print "No matching IPv6 networks found\n" if $verbose == "1";
	}

	print "\n" if $verbose == "1";
}

send_mail() if ( $mail ne 0 );

close LOG;

exit 0;

#################
## subroutines ##
#################


sub insert_networks {
        my ($network,$BM,$red_num,$comment,$client_id,$set_sync_flag,$ip_version,$rootnet) = @_;
	if ( $set_sync_flag eq "1" ) {
		$set_sync_flag = "y";
	} else {
		$set_sync_flag = "n";
	}
		 
	$comment = '' if ( ! $comment );
	my $dbh = mysql_connection() or die "$DBI::errstr\n";
        my $sth = $dbh->prepare("INSERT INTO net (red,bm,descr,red_num,loc,vigilada,comentario,categoria,client_id,ip_version,rootnet) VALUES ( \"$network\", \"$BM\", \"\",\"$red_num\",\"-1\",\"$set_sync_flag\",\"$comment\",\"-1\",\"$client_id\",\"$ip_version\",\"$rootnet\")"
                                ) or die "Fehler bei insert db: $DBI::errstr\n";
        $sth->execute() or die "Fehler bei execute db: $DBI::errstr\n";
        $sth->finish();
        $dbh->disconnect;
}

sub mysql_connection {
    my $dbh = DBI->connect("DBI:mysql:$params{sid_gestioip}:$params{bbdd_host_gestioip}:$params{bbdd_port_gestioip}",$params{user_gestioip},$params{pass_gestioip}) or
    die "Cannot connect: ". $DBI::errstr;
    return $dbh;
}

#sub mysql_connection {
#        my($sid,$database_host,$database_port,$user,$passwort)=@_;
#        my $dbh = DBI->connect("DBI:mysql:$sid:$database_host:$database_port",$user,$passwort, {
#                PrintError => 1,
#                RaiseError => 1
#        }) or die "Can not connect: ". $DBI::errstr;
#        return $dbh;
#}

sub get_last_red_num {
        my $red_num;
	my $dbh = mysql_connection() or die "$DBI::errstr\n";
        my $sth = $dbh->prepare("SELECT red_num FROM net ORDER BY (red_num+0) DESC LIMIT 1
                        ") or die "$dbh->errstr";
        $sth->execute() or die "Can not execute statement: $sth->errstr";
        $red_num = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $red_num;
}


sub get_all_networks {
        my ($client_id,$ip_version) = @_;
        my @overlap_redes;
        my $ip_ref;
	my $dbh = mysql_connection() or die "$DBI::errstr\n";
        my $sth;
        if ( $ip_version eq "v4" ) {
                $sth = $dbh->prepare("SELECT red, BM, rootnet FROM net WHERE client_id = \"$client_id\" AND ip_version = \"$ip_version\" ORDER BY INET_ATON(red)") or die "Can not execute statement: $dbh->errstr";
        } else {
                $sth = $dbh->prepare("SELECT red, BM, rootnet FROM net WHERE client_id = \"$client_id\" AND ip_version = \"$ip_version\"") or die "Can not execute statement: $dbh->errstr";
        }
        $sth->execute() or die "Can not execute statement:$sth->errstr";
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
        push @overlap_redes, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @overlap_redes;
}

sub check_overlap {
        my ( $red, $BM, $overlap_redes, $ignore_rootnet ) = @_;
        my $k="0";
        my $overlap = "0";
	$ignore_rootnet = 0 if ! $ignore_rootnet;
        my $ip = new Net::IP ("$red/$BM") or print LOG "$red/$BM network/bitmask INVALID - IGNORED\n";
        if ( $ip ) {
                foreach (@{$overlap_redes}) {
                        my $red2 = "@{$overlap_redes}[$k]->[0]";
                        my $BM2 = "@{$overlap_redes}[$k]->[1]";
			my $rootnet2 = "@{$overlap_redes}[$k]->[2]" || "0";
                        my $ip2 = new Net::IP ("$red2/$BM2") or print LOG "$red2/$BM2 INVALID network/bitmask - IGNORED\n";
                        if ( ! $ip2 ) {
				$k++;
				next;
			}
			if ( $ignore_rootnet == 1 && $rootnet2 == 1) {
				$k++;
				next;
			}
                        if ($ip->overlaps($ip2)==$IP_A_IN_B_OVERLAP) {
                                print "$red/$BM overlaps with $red2/$BM2 -  IGNORED\n" if $verbose == "1";
                                print LOG "$red/$BM overlaps with $red2/$BM2 -  IGNORED\n";
                                $overlap = "1";
                                last;
                        }
                        if ($ip->overlaps($ip2)==$IP_B_IN_A_OVERLAP) {
                                print "$red/$BM overlaps with $red2/$BM2 -  IGNORED\n" if $verbose == "1";
                                print LOG "$red/$BM overlaps with $red2/$BM2 -  IGNORED\n";
                                $overlap = "1";
                                last;
                        }
                        if ($ip->overlaps($ip2)==$IP_PARTIAL_OVERLAP) {
                                print "$red/$BM overlaps with $red2/$BM2 -  IGNORED\n" if $verbose == "1";
                                print LOG "$red/$BM overlaps with $red2/$BM2 -  IGNORED\n";
                                $overlap = "1";
                                last;
                        }
                        if ($ip->overlaps($ip2)==$IP_IDENTICAL) {
                                print "$red/$BM overlaps with $red2/$BM2 -  IGNORED\n" if $verbose == "1";
                                print LOG "$red/$BM overlaps with $red2/$BM2 -  IGNORED\n";
                                $overlap = "2";
                                last;
                        }
                        $k++;
                }
        } else {
                $overlap = "1";
        }
        return $overlap;
}

sub convert_mask {
	my ($network,$mask) = @_;
	my $BM;
	if ( $mask =~ /\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/ ) {
		$mask =~ /(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})/;
		my $fi_oc = $1;
		my $se_oc = $2;
		my $th_oc = $3;
		my $fo_oc = $4;
 		if ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "255.255.255.252" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "255.255.255.252") { $BM = "30"; }
                elsif ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "255.255.255.248" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "255.255.255.248" ) { $BM = "29"; }
                elsif ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "255.255.255.240" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "255.255.255.240" ) { $BM = "28"; }
                elsif ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "255.255.255.224" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "255.255.255.224" ) { $BM = "27"; }
                elsif ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "255.255.255.192" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "255.255.255.192" ) { $BM = "26"; }
                elsif ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "255.255.255.128" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "255.255.255.128" ) { $BM = "25"; }
                elsif ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "255.255.255.0" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "255.255.255.0" ) { $BM = "24"; }
                elsif ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "255.255.254.0" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "255.255.254.0" ) { $BM = "23"; }
                elsif ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "255.255.252.0" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "255.255.252.0" ) { $BM = "22"; }
                elsif ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "255.255.248.0" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "255.255.248.0" ) { $BM = "21"; }
                elsif ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "255.255.240.0" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "255.255.240.0" ) { $BM = "20"; }
                elsif ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "255.255.224.0" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "255.255.224.0" ) { $BM = "19"; }
                elsif ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "255.255.192.0" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "255.255.192.0" ) { $BM = "18"; }
                elsif ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "255.255.128.0" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "255.255.128.0" ) { $BM = "17"; }
                elsif ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "255.255.0.0" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "255.255.0.0" ) { $BM = "16"; }
                elsif ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "255.254.0.0" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "255.254.0.0" ) { $BM = "15"; }
                elsif ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "255.252.0.0" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "255.252.0.0" ) { $BM = "14"; }
                elsif ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "255.248.0.0" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "255.248.0.0" ) { $BM = "13"; }
                elsif ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "255.240.0.0" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "255.240.0.0" ) { $BM = "12"; }
                elsif ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "255.224.0.0" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "255.224.0.0" ) { $BM = "11"; }
                elsif ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "255.192.0.0" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "255.192.0.0" ) { $BM = "10"; }
                elsif ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "255.128.0.0" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "255.128.0.0" ) { $BM = "9"; }
                elsif ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "255.0.0.0" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "255.0.0.0" ) { $BM = "8"; }
                elsif ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "254.0.0.0" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "254.0.0.0" ) { $BM = "7"; }
                elsif ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "252.0.0.0" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "252.0.0.0" ) { $BM = "6"; }
                elsif ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "248.0.0.0" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "248.0.0.0" ) { $BM = "5"; }
                elsif ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "240.0.0.0" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "240.0.0.0" ) { $BM = "4"; }
                elsif ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "224.0.0.0" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "224.0.0.0" ) { $BM = "3"; }
                elsif ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "192.0.0.0" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "192.0.0.0" ) { $BM = "2"; }
                elsif ( "$fi_oc.$se_oc.$th_oc.$fo_oc" eq "128.0.0.0" || "$fo_oc.$th_oc.$se_oc.$fi_oc" eq "128.0.0.0" ) { $BM = "1"; }
		elsif ( $mask eq "255.255.255.255" ) {
			print "$network/$mask: HOSTROUTE - IGNORED\n" if $verbose == "1";
			print LOG "$network/$mask: HOSTROUTE - IGNORED\n";
		} else {
			print "$network/$mask: Bad Netmask - IGNORED\n" if $verbose == "1";
			print LOG "$network/$mask: Bad Netmask - IGNORED\n";
		}
	}
	return $BM;
}

sub send_mail {
        my $mailer = Mail::Mailer->new("");
        $mailer->open({ From    => "$$mail_from_ref",
                        To      => "$$mail_destinatarios_ref",
                        Subject => "Result get_networks_snmp.pl"
                     }) or die "error while sending mail: $!\n";
        open (LOG_MAIL,"<$log") or die "can not open log file: $!\n";
        while (<LOG_MAIL>) {
                print $mailer $_;
        }
        print $mailer "\n\n\n\n\n\n\n\n\n--------------------------------\n\n";
        print $mailer "This mail is automatically generated by GestioIP's get_networks_snmp.pl\n";
        print $mailer "GestioIP (get_networks_snmp.pl)\n";
        $mailer->close;
        close LOG;
}


sub insert_audit_auto {
	my ($event_class,$event_type,$event,$update_type_audit,$client_id) = @_;
	my $audit_user=$ENV{'USER'};
	#my $user=getlogin();
	my $mydatetime=time();
	my $dbh = mysql_connection() or die "$DBI::errstr\n";
	my $qevent_class = $dbh->quote( $event_class );
	my $qevent_type = $dbh->quote( $event_type );
	my $qevent = $dbh->quote( $event );
	my $qupdate_type_audit = $dbh->quote( $update_type_audit );
	my $qaudit_user = $dbh->quote( $audit_user );
	my $qmydatetime = $dbh->quote( $mydatetime );
	my $qclient_id = $dbh->quote( $client_id );
	my $sth = $dbh->prepare("INSERT INTO audit_auto (event,user,event_class,event_type,update_type_audit,date,client_id) VALUES ($qevent,$qaudit_user,$qevent_class,$event_type,$qupdate_type_audit,$qmydatetime,$qclient_id)") or die "Can not execute statement: $dbh->errstr";
        $sth->execute() or die "Can not execute statement:$sth->errstr";
	$sth->finish();
}

#sub get_last_audit_id {
#	my $last_audit_id;
#	my $dbh = mysql_connection() or die "$DBI::errstr\n";
#	my $sth = $dbh->prepare("SELECT id FROM audit ORDER BY (id+0) DESC LIMIT 1
#		") or die "Can not execute statement: $dbh->errstr";
#        $sth->execute() or die "Can not execute statement:$sth->errstr";
#	$last_audit_id = $sth->fetchrow_array;
#	$sth->finish();
#	$dbh->disconnect;
#	$last_audit_id || 1;
#$last_audit_id;
#}

sub get_client_id_from_name {
        my ( $client_name ) = @_;
        my $val;
	my $dbh = mysql_connection() or die "$DBI::errstr\n";
        my $qclient_name = $dbh->quote( $client_name );
        my $sth = $dbh->prepare("SELECT id FROM clients WHERE client=$qclient_name");
        $sth->execute() or  die "Can not execute statement:$sth->errstr";
        $val = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $val;
}

sub get_version {
        my $val;
        my $dbh = mysql_connection();
        my $sth = $dbh->prepare("SELECT version FROM global_config");
        $sth->execute() or die "Can not execute statement:$sth->errstr";
        $val = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $val;
}

sub count_clients {
        my $val;
        my $dbh = mysql_connection();
        my $sth = $dbh->prepare("SELECT count(*) FROM clients
                        ") or die "Can not execute statement: $dbh->errstr";
        $sth->execute() or die "Can not execute statement: $dbh->errstr";
        $val = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $val;
}

sub check_one_client_name {
        my ($client_name) = @_;
        my $val;
        my $dbh = mysql_connection();
        my $sth = $dbh->prepare("SELECT client FROM clients WHERE client=\"$client_name\"
                        ") or die "Can not execute statement: $dbh->errstr";
        $sth->execute() or die "Can not execute statement: $dbh->errstr";
        $val = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $val;
}

sub get_client_id_one {
        my ($client_name) = @_;
        my $val;
        my $dbh = mysql_connection();
        my $sth = $dbh->prepare("SELECT id FROM clients
                        ") or die "Can not execute statement: $dbh->errstr";
        $sth->execute() or die "Can not execute statement: $dbh->errstr";
        $val = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $val;
}


sub create_snmp_session {
	my ($client_id,$node,$community,$community_type,$snmp_version,$auth_pass,$auth_proto,$auth_is_key,$priv_proto,$priv_pass,$priv_is_key,$sec_level) = @_;

	my $session;
	my $error;

	if ( $snmp_version == "1" || $snmp_version == "2" ) {
		$session = new SNMP::Session(DestHost => $node,
						$community_type => $community,
						Version => $snmp_version,
						UseSprintValue => 1,
						Verbose => 1
						);
	} elsif ( $snmp_version == "3" && $community && ! $auth_proto && ! $priv_proto ) {
		$session = new SNMP::Session(DestHost => $node,
						$community_type => $community,
						Version => $snmp_version,
						SecLevel => $sec_level,
						UseSprintValue => 1
						);
	} elsif ( $snmp_version == "3" && $auth_proto && ! $auth_is_key && ! $priv_proto ) {
		$session = new SNMP::Session(DestHost => $node,
						Debug=>1,
						$community_type => $community,
						Version => $snmp_version,
						SecLevel => $sec_level,
						AuthPass => $auth_pass,
						AuthProto => $auth_proto,
						UseSprintValue => 1
						);
	} elsif ( $snmp_version == "3" && $auth_proto && $auth_is_key && ! $priv_proto ) {
		$session = new SNMP::Session(DestHost => $node,
						$community_type => $community,
						Version => $snmp_version,
						SecLevel => $sec_level,
						AuthMasterKey => $auth_pass,
						AuthProto => $auth_proto,
						UseSprintValue => 1
						);
	} elsif ( $snmp_version == "3" && $auth_proto && $priv_proto && ! $auth_is_key && ! $priv_is_key ) {
		$session = new SNMP::Session(DestHost => $node,
						$community_type => $community,
						Version => $snmp_version,
						SecLevel => $sec_level,
						AuthPass => $auth_pass,
						AuthProto => $auth_proto,
						PrivPass => $priv_pass,
						PrivProto => $priv_proto,
						UseSprintValue => 1
						);
	} elsif ( $snmp_version == "3" && $auth_proto && $priv_proto && $auth_is_key && ! $priv_is_key ) {
		$session = new SNMP::Session(DestHost => $node,
						$community_type => $community,
						Version => $snmp_version,
						SecLevel => $sec_level,
						AuthMasterKey => $auth_pass,
						AuthProto => $auth_proto,
						PrivPass => $priv_pass,
						PrivProto => $priv_proto,
						UseSprintValue => 1
						);
	} elsif ( $snmp_version == "3" && $auth_proto && $priv_proto && ! $auth_is_key && $priv_is_key ) {
		$session = new SNMP::Session(DestHost => $node,
						$community_type => $community,
						Version => $snmp_version,
						SecLevel => $sec_level,
						AuthPass => $auth_pass,
						AuthProto => $auth_proto,
						PrivMasterKey => $priv_pass,
						PrivProto => $priv_proto,
						UseSprintValue => 1
						);
	} elsif ( $snmp_version == "3" && $auth_proto && $priv_proto && $auth_is_key && $priv_is_key ) {
		$session = new SNMP::Session(DestHost => $node,
						$community_type => $community,
						Version => $snmp_version,
						SecLevel => $sec_level,
						AuthMasterKey => $auth_pass,
						AuthProto => $auth_proto,
						PrivMasterKey => $priv_pass,
						PrivProto => $priv_proto,
						UseSprintValue => 1
						);
	} else {
		print "Can not determine SecLevel\n";
		exit 1;
	}

	
	print "$node: CAN NOT CONNECT\n" unless
  (defined $session);

	return $session;
}

sub check_red_exists {
        my ( $client_id, $net, $BM, $ignore_rootnet ) = @_;
        my $red_check="";
        $ignore_rootnet=1 if $ignore_rootnet eq "";
        my $ignore_rootnet_expr="AND rootnet='0'";
        if ( $ignore_rootnet == 0 ) {
                $ignore_rootnet_expr="AND rootnet='1'";
        }
        my $dbh = mysql_connection();
        my $qnet = $dbh->quote( $net );
        my $qBM = $dbh->quote( $BM );
        my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("SELECT red_num FROM net WHERE red=$qnet AND BM=$qBM AND client_id = $qclient_id $ignore_rootnet_expr
                        ") or die "$DBI::errstr";
        $sth->execute() or die "Can not execute statement: $DBI::errstr";
        $red_check = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $red_check;
}

