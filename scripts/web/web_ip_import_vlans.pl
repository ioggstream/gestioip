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


use lib '/var/www/gestioip/modules';
use GestioIP;
use strict;
use Getopt::Long;
Getopt::Long::Configure ("no_ignore_case");
use Socket;
use SNMP::Info;
use FindBin qw($Bin);
use Fcntl qw(:flock);



my $gip = GestioIP -> new();

my $VERSION="3.0.0";

my ( $test, $mail, $help, $version_arg, $community_arg,$community,$client_id,$snmp_version,$lang,$gip_config_file,$ini_devices,$user,$max_sync_procs);
my $auth_proto="";
my $auth_pass="";
my $priv_proto="";
my $priv_pass="";
my $sec_level="";

GetOptions(
        "community=s"=>\$community,
        "id_client=s"=>\$client_id,
        "snmp_version=s"=>\$snmp_version,
        "lang=s"=>\$lang,
        "user=s"=>\$user,
        "devices=s"=>\$ini_devices,
        "Version!"=>\$version_arg,
        "procs=s"=>\$max_sync_procs,
        "gestioip_config=s"=>\$gip_config_file,
        "mail!"=>\$mail,
        "help!"=>\$help,
	"n=s"=>\$auth_proto,
	"o=s"=>\$auth_pass,
	"t=s"=>\$priv_proto,
	"q=s"=>\$priv_pass,
	"r=s"=>\$sec_level
) or print_help();

my $enable_audit = "1";

if ( $help ) { print_help(); }
if ( $version_arg ) { print_version(); }

$lang = "en" if ! $lang;

if ( ! $client_id ) {
        print STDERR "Parameter \"client_id\" missing\n\nexiting\n";
        exit 1;
}
if ( ! $gip_config_file ) {
        print STDERR "Parameter \"gip_config_file\" missing\n\nexiting\n";
        exit 1;
}

$client_id =~ /^(\d{1,5})$/;
$client_id = $1;

my $dir = $Bin;
$dir =~ /^(.*\/bin\/web)$/;
$dir = $1;
$dir =~ /^(.*)\/bin/;
my $base_dir=$1;


my $lockfile = $base_dir . "/var/run/" . $client_id . "_web_ip_import_vlans.lock";

no strict 'refs';
open($lockfile, '<', $0) or die("Unable to create lock file: $!\n");
use strict;

unless (flock($lockfile, LOCK_EX|LOCK_NB)) {
        print STDERR "$0 is already running. Exiting.\n";
        exit(1);
}

my $pidfile = $base_dir . "/var/run/" . $client_id . "_web_ip_import_vlans.pid";
$pidfile =~ /^(.*_web_ip_import_vlans.pid)$/;
$pidfile = $1;
open(PID,">$pidfile") or die("Unable to create pid file $pidfile: $! (1)\n");
print PID $$;
close PID;

$SIG{'TERM'} = $SIG{'INT'} = \&do_term;


$gip_config_file =~ /^(.*)\/priv/;
my $gestioip_root=$1;

my $ini_stat=$gestioip_root . "/status/ini_stat.html";
my $log=$gestioip_root . "/status/" . $client_id . "_initialize_gestioip.log";
$log =~ /^(.*_initialize_gestioip.log)$/;
$log = $1;

if ( ! -d "${gestioip_root}/status" ) {
        print STDERR "Log directory does not exists: ${gestioip_root}/status\n\exiting\n";
        exit 1;
}
open(LOG,">>$log") or die "$log: $!\n";
*STDERR = *LOG;

if ( ! -r $gip_config_file ) {
        print STDERR "config_file $gip_config_file not readable\n\nexiting\n";
        exit 1;
}
if ( ! $user ) {
        print STDERR "Warning: Parameter \"user\" missing\n";
}
if ( ! $max_sync_procs ) {
        print STDERR "Warning: Parameter \"max_sync_procs\" missing\n";
	$max_sync_procs = "128";
}

my @config = get_config("$client_id");
my $ignorar = $config[0]->[2] || "";
my $ignore_generic_auto = $config[0]->[3] || "yes";
my $generic_dyn_host_name = $config[0]->[4] || "";
my $dyn_ranges_only = $config[0]->[5] || "n";
my $ping_timeout = $config[0]->[6] || "2";


my $vars_file=$gestioip_root . "/vars/vars_" . "$lang";
if ( ! -r $vars_file ) {
        print STDERR "vars_file not found: $vars_file\n\exiting\n";
        exit 1;
}

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

$generic_dyn_host_name =~ s/,/|/g;


my ($s, $mm, $h, $d, $m, $y) = (localtime) [0,1,2,3,4,5];
$m++;
$y+=1900;
if ( $d =~ /^\d$/ ) { $d = "0$d"; }
if ( $s =~ /^\d$/ ) { $s = "0$s"; }
if ( $m =~ /^\d$/ ) { $m = "0$m"; }
if ( $mm =~ /^\d$/ ) { $mm = "0$mm"; }
my $mydatetime = "$y-$m-$d $h:$mm:$s";


my $new_vlan_count = "0";
my $all_vlan_count = "0";

my $gip_version=get_version();

if ( $VERSION !~ /$gip_version/ ) {
        print LOG "\nScript and GestioIP version are not compatible\n\nGestioIP version: $gip_version - script version: $VERSION\n\n";
	mod_ini_stat("$new_vlan_count");
        exit 1;
}

my @global_config = get_global_config("$client_id");
my $mib_dir=$global_config[0]->[3] || "";
my $vendor_mib_dirs=$global_config[0]->[4] || "";

my @vendor_mib_dirs = split(",",$vendor_mib_dirs);
my @mibdirs_array;
foreach ( @vendor_mib_dirs ) {
        my $mib_vendor_dir = $mib_dir . "/" . $_;
        if ( ! -e $mib_vendor_dir ) {
                print LOG "$lang_vars{mib_dir_not_exists}: $mib_vendor_dir\nexiting\n";
		mod_ini_stat("$new_vlan_count");
                exit(1);
                if ( ! -r $mib_vendor_dir ) {
                        print LOG "$lang_vars{mib_dir_not_readable}: $mib_vendor_dir\nexiting\n";
			mod_ini_stat("$new_vlan_count");
                        exit(1);
                }
        }
        push (@mibdirs_array,$mib_vendor_dir);

}

my $mibdirs_ref = \@mibdirs_array;

if ( ! $community ) {
        print LOG "No SNMP Community string found\nexiting\n";
	close LOG;
        exit 1;
}
if ( ! $snmp_version ) {
        print LOG "No \"SNMP_community\" string found\nexiting\n";
	close LOG;
        exit 1;
}
my $community_type="Community";
my $auth_is_key="";
my $priv_is_key="";
if ( $snmp_version == "3" ) {
	$community_type = "SecName";
	if ( ! $community ) {
		print LOG "No Username\n";
		close LOG;
		exit(1);
	}
	if ( $auth_proto && ! $auth_pass ) {
		print LOG "No auth password\n";
		close LOG;
		exit(1);
	}
	if ( $auth_pass && ! $auth_proto ) {
		print LOG "No auth protocol\n";
		close LOG;
		exit(1);
	}
	if ( $priv_proto && ! $priv_pass ) {
		print LOG "No privacy password\n";
		close LOG;
		exit(1);
	}
	if ( $priv_pass && ! $priv_proto ) {
		print LOG "No privacy protocol\n";
		close LOG;
		exit(1);
	}
	if ( $priv_proto && ( ! $auth_proto || ! $auth_pass ) ) {
		print LOG "No \"auth algorithm\" and \"auth password/auth key\"\n";
		close LOG;
		exit(1);
	}
}

$ini_devices =~ s/^\s*//;
$ini_devices =~ s/[\s\n\t]*$//;
my @nodes = split(",",$ini_devices);
my $i="0";

if ( ! $nodes[0] ) {
        print LOG "\nNo nodes to query found\n\n";
	mod_ini_stat("$new_vlan_count");
        exit 1;
}

my $new_net_count="0";
#my @found_networks = ();

my $node;

my $smallest_bm = $config[0]->[0] || "22";
my $asso_vlan_reverse_hash=get_asso_vlan_reverse_hash_ref("$client_id");


my $new_vlan="0";

my $ip_version="";

foreach ( @nodes ) {

	$node=$_;

	my $valid_v6=$gip->check_valid_ipv6("$node") || "0";
	if ( $valid_v6 == "1" ) {
		$ip_version="v6";
	} elsif ( $node =~ /^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})$/ ) {
		$ip_version="v4";
	} else {
		print LOG "$node: $lang_vars{ip_invalido_message}\n";
		mod_ini_stat("$new_vlan_count");
		next;
	}

	$new_vlan_count="0";

	$node=$_;
#	my $node_name;
#	if ( $node !~ /^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})$/ ) {
#		$node_name=$node; 
#		my @dns_result_name=$gip->resolve_name("$client_id","$node");
#		$node = inet_ntoa($dns_result_name[4]) if ($dns_result_name[0]) || "";
#		print LOG "$node_name: $lang_vars{ip_invalido_message}\n";
#		mod_ini_stat("$new_vlan_count");
#		next;
#	}

	my $node_int=$gip->ip_to_int("$client_id","$node","$ip_version") || "";
	my $node_id=get_host_id_from_ip_int("$client_id","$node") || "";


	my $gip_vars_file=${gestioip_root} . "/vars/vars_" . $lang;
	if ( ! -r $gip_vars_file ) {
		print LOG "Can not open gip_vars_file ($gip_vars_file): $!\n";
		close LOG;
		exit(1);
	}

	my $bridge=$gip->create_snmp_info_session("$client_id","$node","$community","$community_type","$snmp_version","$auth_pass","$auth_proto","$auth_is_key","$priv_proto","$priv_pass","$priv_is_key","$sec_level",$mibdirs_ref,"$gip_vars_file");

	if ( ! $bridge ) {
		print LOG "\n+++ Importing VLANs from $node +++\n";
		print LOG "\n$node: Can't connect or device doesn't support required OIDs\n";
		mod_ini_stat("$new_vlan_count");
		next;
	}

	my @vlans_with_assos=get_vlans_with_asso_vlans("$client_id");

	my $device_type_info=$bridge->model() || "";
	my $device_vendor=$bridge->vendor() || "";
	if ( $device_type_info && $device_vendor ) {
		print LOG "\n+++ Importing VLANs from $node ($device_vendor - $device_type_info) +++\n\n";
	} else {
		print LOG "\n+++ Importing VLANs from $node +++\n\n";
	}

	my $cisco_index = $bridge->cisco_comm_indexing();

	if ( $cisco_index == 0 ) {
#		print "NONE CISCO\n";
		my $vlan_name=$bridge->qb_v_name();
		my $interfaces = $bridge->interfaces();
		my $vlans = $bridge->i_vlan_membership();
		my $vlan_numbers=$bridge->v_index();
		
		foreach my $v_num(keys %$vlan_numbers) {
			my $updated="0";
			my $found="0";
			my $vlan_descr = $vlan_name->{"$v_num"};
			my $vlan_num=$v_num;
			my $vlan_name=$vlan_descr;
			next if ! $vlan_num || ! $vlan_name;
			my $comment = "";
			foreach ( @vlans_with_assos ) {
				my $found_vlan_id=$_->[0];
				my $found_vlan_num=$_->[1];
				my $found_vlan_name=$_->[2];
				next if ! $found_vlan_num || ! $found_vlan_name;
				if ( $vlan_num eq $found_vlan_num && $vlan_name eq $found_vlan_name ) {
					$found='1';
					my $switches=get_vlan_switches("$client_id","$found_vlan_id") || "";
					if ( ! $switches && $node_id ) {
						update_vlan_switches("$client_id","$found_vlan_id","$node_id");
						$updated="1";
					} else {
						my @switches_array=split(",",$switches);
						foreach ( @switches_array ) {
							#UPDATE VLAN switch info
							if ( $node_id && $switches !~ /^$node_id$/ && $switches !~ /^$node_id,/ && $switches !~ /,$node_id$/ &&  $switches !~ /,$node_id,/ ) {
								update_vlan_switches("$client_id","$found_vlan_id","$switches,$node_id");
								$updated="1";
							}
							if ( $asso_vlan_reverse_hash->{"$found_vlan_id"}[0] ) {
								my $asso_vlan_id=$asso_vlan_reverse_hash->{"$found_vlan_id"}[1] || "";
								my $asso_vlan_switches = get_vlan_switches("$client_id","$asso_vlan_id");
								if ( $node_id && $asso_vlan_switches !~ /^$node_id$/ && $asso_vlan_switches !~ /^$node_id,/ && $asso_vlan_switches !~ /,$node_id$/ &&  $asso_vlan_switches !~ /,$node_id,/ ) {
									$asso_vlan_switches= $asso_vlan_switches . "," . $node_id;
									update_vlan_switches_by_id("$client_id","$asso_vlan_id","$asso_vlan_switches");
									$asso_vlan_reverse_hash->{"$found_vlan_id"}[0] = $asso_vlan_switches;
								}
							}
						}
					}
				}
				last if $found == 1;
			}
			if ( $found == "1" && $updated != "1" ) {
				print LOG "$vlan_num - $vlan_name: $lang_vars{vlan_exists_message} - $lang_vars{ignorado_message}\n";
				$new_vlan="1";
				next;
			} elsif ( $found == "1" && $updated == "1" ) {
				print LOG "$vlan_num - $vlan_name: $lang_vars{vlan_exists_message} - $lang_vars{switches_info_updated}\n";
				$new_vlan="1";
			}
			next if $updated == "1";

			if ( $vlan_num && $vlan_name ) {
				insert_vlan("$client_id","$vlan_num","$vlan_name","$comment","-1","black","white","$node_id");
				print LOG "$vlan_name - $vlan_num - $lang_vars{vlan_added_log_message}\n";
				$new_vlan="1";
				$new_vlan_count++;

				my $audit_type="36";
				my $audit_class="7";
				my $update_type_audit="7";
				my $event="$vlan_num, $vlan_name";
				$event=$event . "," . $comment if $comment;
				$event=$event . " (community: public)" if $community eq "public";
#				insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file","$user");
			        insert_audit_auto("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file","$user");

			}

		}

	} else {
#		print "CISCO\n";
		my $interfaces = $bridge->interfaces();
		my $vlans      = $bridge->i_vlan_membership();
		my $vlan_name=$bridge->v_name();
		my $vlan_index=$bridge->v_index();

		foreach my $key(%$vlan_index) {
			my $found="0";
			my $updated="0";
			my $newkey = $key;
			next if ! $$vlan_name{$key};
			if ( $newkey =~ /^\d\.\d+/ ) {
				$newkey =~ s/^\d\.//;
			}
			my $vlan_num=$newkey;
			my $vlan_name=$$vlan_name{$key};
			next if ! $vlan_num || ! $vlan_name;
			my $comment = "";

			foreach ( @vlans_with_assos ) {
				my $found_vlan_id=$_->[0];
				my $found_vlan_num=$_->[1];
				my $found_vlan_name=$_->[2];
				next if ! $found_vlan_num || ! $found_vlan_name;
				if ( $vlan_num eq $found_vlan_num && $vlan_name eq $found_vlan_name ) {
					$found='1';
					my $switches=get_vlan_switches("$client_id","$found_vlan_id") || "";
					if ( ! $switches ) {
						update_vlan_switches("$client_id","$found_vlan_id","$node_id");
						$updated="1";
						$new_vlan="1";
					} else {
						my @switches_array=split(",",$switches);
						foreach ( @switches_array ) {
							#UPDATE VLAN switch info
							if ( $switches !~ /^$node_id$/ && $switches !~ /^$node_id,/ && $switches !~ /,$node_id$/ &&  $switches !~ /,$node_id,/ ) {
								update_vlan_switches("$client_id","$found_vlan_id","$switches,$node_id");
								$updated="1";
							}
							if ( $asso_vlan_reverse_hash->{"$found_vlan_id"}[0] ) {
								my $asso_vlan_id=$asso_vlan_reverse_hash->{"$found_vlan_id"}[1] || "";
								my $asso_vlan_switches = "";
								$asso_vlan_switches = get_vlan_switches("$client_id","$asso_vlan_id") if $asso_vlan_id;
								if ( $node_id && $asso_vlan_switches !~ /^$node_id$/ && $asso_vlan_switches !~ /^$node_id,/ && $asso_vlan_switches !~ /,$node_id$/ &&  $asso_vlan_switches !~ /,$node_id,/ ) {
									$asso_vlan_switches= $asso_vlan_switches . "," . $node_id;
									update_vlan_switches_by_id("$client_id","$asso_vlan_id","$asso_vlan_switches");
									$asso_vlan_reverse_hash->{"$found_vlan_id"}[0] = $asso_vlan_switches;
								}
							}
						}
					}
				}
				last if $found == 1;
			}

			if ( $found == "1" && $updated != "1" ) {
				print LOG "$vlan_num - $vlan_name: $lang_vars{vlan_exists_message} - $lang_vars{ignorado_message}\n";
				$new_vlan="1";
				next;
			} elsif ( $found == "1" && $updated == "1" ) {
				print LOG "$vlan_num - $vlan_name: $lang_vars{vlan_exists_message} - $lang_vars{switches_info_updated}\n";
				$new_vlan="1";
			}
			next if $updated == "1";

			if ( $vlan_num && $vlan_name ) {
				insert_vlan("$client_id","$vlan_num","$vlan_name","$comment","-1","black","white","$node_id");
				print LOG "$vlan_name - $vlan_num - $lang_vars{vlan_added_log_message}\n";
				$new_vlan="1";
				$new_vlan_count++;

				my $audit_type="36";
				my $audit_class="7";
				my $update_type_audit="7";
				my $event="$vlan_num, $vlan_name";
				$event=$event . "," . $comment if $comment;
				$event=$event . " (community: public)" if $community eq "public";
#				insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file","$user");
			        insert_audit_auto("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file","$user");
			}
		}
	}

	#system("$dir/mod_ini_stat.pl -g $gip_config_file -b $new_net_count -a 0");

	#change ini_stat.html
	mod_ini_stat("$new_vlan_count");
	print LOG "\nFound $new_vlan_count new VLANs\n";
	$all_vlan_count= $all_vlan_count + $new_vlan_count

}

print LOG "\nFound a total of $all_vlan_count new VLANs\n\n";

unlink("$pidfile");


####################
### subroutines ####
####################

sub print_help {}

sub get_config {
        my ( $client_id ) = @_;
        my @values_config;
        my $ip_ref;
        my $dbh = $gip->_mysql_connection("$gip_config_file");
        my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("SELECT smallest_bm,max_sinc_procs,ignorar,ignore_generic_auto,generic_dyn_host_name,dyn_ranges_only,ping_timeout FROM config WHERE client_id = $qclient_id") or die ("Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or die ("Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
        push @values_config, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @values_config;
}

sub get_version {
        my $val;
        my $dbh = $gip->_mysql_connection("$gip_config_file");
        my $sth = $dbh->prepare("SELECT version FROM global_config");
        $sth->execute() or die "Can not execute statement:$sth->errstr";
        $val = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $val;
}

sub get_global_config {
        my ( $client_id ) = @_;
        my @values_config;
        my $ip_ref;
        my $dbh = $gip->_mysql_connection("$gip_config_file");
        my $sth = $dbh->prepare("SELECT version, default_client_id, confirmation, mib_dir, vendor_mib_dirs FROM global_config") or die "Can not execute statement:<p>$DBI::errstr";
        $sth->execute() or die "Can not execute statement:<p>$DBI::errstr";
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
        push @values_config, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @values_config;
}

sub get_asso_vlan_reverse_hash_ref {
        my ( $client_id ) = @_;
        my (@values_vlans,$ip_ref);
        my $dbh = $gip->_mysql_connection("$gip_config_file");
        my $qclient_id = $dbh->quote( $client_id );
        my %vlans;
        my $sth = $dbh->prepare("SELECT v.id, v.vlan_num, v.vlan_name, v.comment, vp.name, v.switches, v.asso_vlan FROM vlans v, vlan_providers vp WHERE v.asso_vlan IS NOT NULL AND ( v.client_id=$qclient_id || v.client_id='9999' ) order by (vlan_num+0)");
        $sth->execute() or die "Can not execute statement:<p>$DBI::errstr";
        while ( $ip_ref = $sth->fetchrow_hashref ) {
                my $vlan_id = $ip_ref->{'id'};
                my $switches = $ip_ref->{'switches'};
                my $asso_vlan_id = $ip_ref->{'asso_vlan'};
                push @{$vlans{"$vlan_id"}},"$switches","$asso_vlan_id";

        }
        $dbh->disconnect;
        $sth->finish();
        return \%vlans;
}

sub get_host_id_from_ip_int {
        my ( $client_id,$ip_int,$red_num ) = @_;
        my $val;
        my $dbh = $gip->_mysql_connection("$gip_config_file");
        my $qip_int = $dbh->quote( $ip_int );
        my $qclient_id = $dbh->quote( $client_id );
        my $qred_num = $dbh->quote( $red_num );
        my $red_num_expr="";
        $red_num_expr="AND red_num = $qred_num" if $red_num;
        my $sth = $dbh->prepare("SELECT id FROM host WHERE ip=$qip_int AND client_id=$qclient_id $red_num_expr");
        $sth->execute() or die "Can not execute statement: $DBI::errstr";
        $val = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $val;
}

sub get_vlans_with_asso_vlans {
        my ( $client_id ) = @_;
        my (@values_vlans,$ip_ref);
        my $dbh = $gip->_mysql_connection("$gip_config_file");
        my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("SELECT id,vlan_num,vlan_name FROM vlans WHERE client_id=$qclient_id || client_id='9999'");
        $sth->execute() or die "Can not execute statement:<p>$DBI::errstr";
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
                push @values_vlans, [ @$ip_ref ];
        }
        $dbh->disconnect;
        $sth->finish(  );
        return @values_vlans;
}

sub get_vlan_switches {
        my ( $client_id,$vlan_id ) = @_;
        my $switches;
        my $ip_ref;
        my $dbh = $gip->_mysql_connection("$gip_config_file");
        my $qvlan_id = $dbh->quote( $vlan_id );
        my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("SELECT switches FROM vlans WHERE id=$qvlan_id AND client_id=$qclient_id
                ") or die "Can not execute statement:<p>$DBI::errstr";
        $sth->execute();
        $switches = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $switches;
}

sub update_vlan_switches {
        my ( $client_id,$vlan_id,$switches ) = @_;
        my ($id);
        my $dbh = $gip->_mysql_connection("$gip_config_file");
        my $qvlan_id = $dbh->quote( $vlan_id );
        my $qswitches = $dbh->quote( $switches );
        my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("UPDATE vlans SET switches=$qswitches WHERE id=$qvlan_id AND client_id=$qclient_id
                ") or die "$client_id","Can not execute statement:<p>$DBI::errstr";
        $sth->execute();
        $sth->finish();
        $dbh->disconnect;
}

sub insert_vlan {
        my ( $client_id, $vlan_num, $vlan_name, $comment, $vlan_provider_id, $font_color, $bg_color, $switches ) = @_;
        my $dbh = $gip->_mysql_connection("$gip_config_file");
        my $qvlan_num = $dbh->quote( $vlan_num );
        my $qvlan_name = $dbh->quote( $vlan_name );
        my $qcomment = $dbh->quote( $comment );
        my $qvlan_provider_id = $dbh->quote( $vlan_provider_id );
        my $qfont_color = $dbh->quote( $font_color );
        my $qbg_color = $dbh->quote( $bg_color );
        my $qswitches = $dbh->quote( $switches );
        my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("INSERT INTO vlans (vlan_num,vlan_name,comment,provider_id,bg_color,font_color,switches,client_id) VALUES ( $qvlan_num,$qvlan_name,$qcomment,$qvlan_provider_id,$qbg_color,$qfont_color,$qswitches,$qclient_id)"
                ) or die "$client_id","Can not execute statement:<p>$DBI::errstr";
        $sth->execute() or die "Can not execute statement:<p>$DBI::errstr";
        $sth->finish();
        $dbh->disconnect;
}

#sub insert_audit {
#        my ($client_id,$event_class,$event_type,$event,$update_type_audit,$vars_file,$user) = @_;
#        my %lang_vars = $gip->_get_vars("$vars_file");
#        my $mydatetime=time();
#        my $audit_id=get_last_audit_id("$client_id");
#        $audit_id++;
#        my $dbh = $gip->_mysql_connection("$gip_config_file");
#        my $qaudit_id = $dbh->quote( $audit_id );
#        my $qevent_class = $dbh->quote( $event_class );
#        my $qevent_type = $dbh->quote( $event_type );
#        my $qevent = $dbh->quote( $event );
#        my $quser = $dbh->quote( $user );
#        my $qupdate_type_audit = $dbh->quote( $update_type_audit );
#        my $qmydatetime = $dbh->quote( $mydatetime );
#        my $qclient_id = $dbh->quote( $client_id );
#        my $sth = $dbh->prepare("INSERT IGNORE audit (id,event,user,event_class,event_type,update_type_audit,date,client_id) VALUES ($qaudit_id,$qevent,$quser,$qevent_class,$event_type,$qupdate_type_audit,$qmydatetime,$qclient_id)") or die "Can not execute statement:<p>$DBI::errstr";
#        $sth->execute() or die "Can not execute statement:<p>$DBI::errstr";
#        $sth->finish();
#}

sub insert_audit_auto {
        my ($client_id,$event_class,$event_type,$event,$update_type_audit,$vars_file,$user) = @_;
        my $mydatetime=time();
        my $dbh = $gip->_mysql_connection("$gip_config_file");
        my $qevent_class = $dbh->quote( $event_class );
        my $qevent_type = $dbh->quote( $event_type );
        my $qevent = $dbh->quote( $event );
        my $quser = $dbh->quote( $user );
        my $qupdate_type_audit = $dbh->quote( $update_type_audit );
        my $qmydatetime = $dbh->quote( $mydatetime );
        my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("INSERT IGNORE audit_auto (event,user,event_class,event_type,update_type_audit,date,client_id) VALUES ($qevent,$quser,$qevent_class,$event_type,$qupdate_type_audit,$qmydatetime,$qclient_id)") or die "Can not execute statement: $dbh->errstr";
        $sth->execute() or die "Can not execute statement: $dbh->errstr";
        $sth->finish();
}


sub get_last_audit_id {
        my ($client_id) = @_;
        my $last_audit_id;
        my $dbh = $gip->_mysql_connection("$gip_config_file");
        my $sth = $dbh->prepare("SELECT id FROM audit ORDER BY (id+0) DESC LIMIT 1
                        ") or die "select: $DBI::errstr";
        $sth->execute() or die "Can not execute statement: $DBI::errstr";
        $last_audit_id = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        $last_audit_id || 1;
        return $last_audit_id;
}

sub mod_ini_stat {
	my ($new_vlan_count) = @_;
	my $new = "./ini_stat.html.tmp.$$";
	open(OLD, "< $ini_stat") or die "can't open $ini_stat: $!";
	open(NEW, "> $new") or die "can't open $new: $!";

	while (<OLD>) {
                if ( $_ =~ /$lang_vars{vlans_found_message}: .{0,3}\d+/ ) {
                        $_ =~ /$lang_vars{vlans_found_message}: .{0,3}(\d+)/;
                        my $old_vlan_count = $1;
                        my $vlan_count = $old_vlan_count + $new_vlan_count;
                        s/$lang_vars{vlans_found_message}: .{0,3}\d+(<\/b>)*/$lang_vars{vlans_found_message}: <b>${vlan_count}<\/b>/;
                }
		(print NEW $_) or die "can't write to $new: $!";
	}

	close(OLD) or die "can't close $ini_stat: $!";
	close(NEW) or die "can't close $new: $!";

	rename($new, $ini_stat) or die "can't rename $new to $ini_stat: $!";
}

sub do_term {
	mod_ini_stat("0");
        print LOG "Got TERM Signal - exiting\n";
        close LOG;
        unlink("$pidfile");
        exit 3;
}


__DATA__
