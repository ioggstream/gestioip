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
use Socket;
use SNMP::Info;


my $daten=<STDIN>;
my $gip = GestioIP -> new();
my %daten=$gip->preparer($daten);

my $lang = $daten{'lang'} || "";
my ($lang_vars,$vars_file)=$gip->get_lang("","$lang");

my $client_id = $daten{'client_id'} || $gip->get_first_client_id();

$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{import_vlans_from_snmp_message}","$vars_file");


my $mibdirs_ref = $gip->check_mib_dir("$client_id","$vars_file");

my $align="align=\"right\"";
my $align1="";
my $ori="left";
my $rtl_helper="<font color=\"white\">x</font>";
if ( $vars_file =~ /vars_he$/ ) {
	$align="align=\"left\"";
	$align1="align=\"right\"";
	$ori="right";
}

$gip->print_error("$client_id","$$lang_vars{introduce_community_string_message}") if ( ! $daten{'community_string'} );
$gip->print_error("$client_id","$$lang_vars{community_string_too_long}") if length($daten{community_string}) > 35 ;
$gip->print_error("$client_id","$$lang_vars{select_device_to_query}") if ! $daten{import_device_type};
$gip->print_error("$client_id","$$lang_vars{formato_malo_message}") if $daten{import_device_type} !~ /^node|layer2|layer3$/;

my $debug=$daten{'debug'} || "0";
$gip->print_error("$client_id","$$lang_vars{formato_malo_message}") if $debug !~ /^[0,1]$/;

my $ip_version;

my $device_type=$daten{'import_device_type'};
my $node;
my @nodes;
my @nodes_new;
if ( $device_type eq "node" ) {
###### TEST HIER KOMMA SEPARIERTE LISTE ZULASSEN????
	$gip->print_error("$client_id","$$lang_vars{introduce_snmp_node_vlan_message}") if ! $daten{'snmp_node'};
	$gip->print_error("$client_id","$$lang_vars{node_string_too_long}") if length($daten{snmp_node}) > 75;
	my $valid_v6=$gip->check_valid_ipv6("$daten{snmp_node}") || "0";
	if ( $valid_v6 == 1 || $daten{snmp_node} =~ /\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}(,\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})*$/ ) {
		$nodes[0]=$daten{'snmp_node'};
	} else {
		$gip->print_error("$client_id","$$lang_vars{ip_invalido_message}") if ( $daten{snmp_node} !~ /\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}(,\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})*$/ );
	}
	if ( $valid_v6 == 1 ) {
		$ip_version = "v6";
	} else {
		$ip_version = "v4";
	}

} elsif ( $device_type eq "layer2" ) {
	$gip->print_error("$client_id","$$lang_vars{introduce_snmp_node_vlan_message}") if ! $daten{'l2devices'};
	$node=$daten{'l2devices'};
	@nodes=split("_",$node);
	my $i="0";
	foreach ( @nodes ) {
		$_ =~ /^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/;
		$nodes_new[$i++]=$1;
	}
	@nodes=@nodes_new;
	$ip_version = "v4";
} elsif ( $device_type eq "layer3" ) {
	$gip->print_error("$client_id","$$lang_vars{introduce_snmp_node_vlan_message}") if ! $daten{'l3devices'};
	$node=$daten{'l3devices'};
	@nodes=split("_",$node);
	my $i="0";
	foreach ( @nodes ) {
		$_ =~ /^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/;
		$nodes_new[$i++]=$1;
	}
	@nodes=@nodes_new;
	$ip_version = "v4";
} elsif ( $device_type eq "layer2_v6" ) {
	$gip->print_error("$client_id","$$lang_vars{introduce_snmp_node_vlan_message}") if ! $daten{'l2devices'};
	$node=$daten{'l2devices_v6'};
	@nodes=split("_",$node);
	my $i="0";
	foreach ( @nodes ) {
		$nodes_new[$i++]=$_ if $_;
	}
	@nodes=@nodes_new;
	$ip_version = "v6";
} elsif ( $device_type eq "layer3_v6" ) {
	$gip->print_error("$client_id","$$lang_vars{introduce_snmp_node_vlan_message}") if ! $daten{'l3devices'};
	$node=$daten{'l3devices_v6'};
	@nodes=split("_",$node);
	my $i="0";
	foreach ( @nodes ) {
		$nodes_new[$i++]=$_ if $_;
	}
	@nodes=@nodes_new;
	$ip_version = "v6";
}

my $community=$daten{'community_string'};
my $snmp_version=$daten{snmp_version};
my $add_comment;
$add_comment=$daten{'add_comment'} if $daten{'add_comment'};
$add_comment="n" if ! $add_comment;

my @config = $gip->get_config("$client_id");
my $smallest_bm = $config[0]->[0] || "22";
my $asso_vlan_reverse_hash=$gip->get_asso_vlan_reverse_hash_ref("$client_id");


my $community_type="Community";

my $new_vlan="0";

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


print "<span class=\"sinc_text\">";
foreach ( @nodes ) {

	$node=$_;
	my $node_name;
	my $node_int=$gip->ip_to_int("$client_id","$node","$ip_version") || "";	

	next if ! $node_int;

	my $node_id=$gip->get_host_id_from_ip_int("$client_id","$node_int") || "";

	if ( $device_type eq "layer2" || $device_type eq "layer3" ) {
		if ( ! $node_id ) {
			print "$$lang_vars{node_not_found_message} - $$lang_vars{ignorado_message}<br><p>\n";
			next;
		}
	}

	my $bridge=$gip->create_snmp_info_session("$client_id","$node","$community","$community_type","$snmp_version","$auth_pass","$auth_proto","$auth_is_key","$priv_proto","$priv_pass","$priv_is_key","$sec_level",$mibdirs_ref,"$vars_file","$debug");

	if ( ! $bridge ) {
		next;
	}

	my $err = $bridge->error();
	print "<span style=\"float: $ori\">SNMP Community or Version probably wrong connecting to $node. $err</span><br>\n" if defined $err;

	# it does not work with SNMPv3 when bulkwalk is turned on
###### TEST BULKWALK !!!
	$bridge->bulkwalk(0);

	my @vlans_with_assos=$gip->get_vlans_with_asso_vlans("$client_id");

	my $device_type_info=$bridge->model() || "";
	my $device_vendor=$bridge->vendor() || "";
	if ( $device_type_info ) {
		if ( $vars_file =~ /vars_he$/ ) {
			print "<p><span style=\"float: $ori\">$rtl_helper($device_type_info - $device_vendor) <b>$node</b></span><br><p>\n";
		} else {
			print "<p><b>$node</b> ($device_vendor - $device_type_info)<p>\n";
		}
	} else {
		if ( $vars_file =~ /vars_he$/ ) {
			print "<p><b style=\"float: $ori\">$node</b><p>\n";
		} else {
			print "<p><b>$node</b><p>\n";
		}
	}

	my $cisco_index = $bridge->cisco_comm_indexing();

	if ( $cisco_index == 0 ) {
#		print "NONE CISCO<br>\n";
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
					my $switches=$gip->get_vlan_switches("$client_id","$found_vlan_id") || "";
					if ( ! $switches && $node_id ) {
						$gip->update_vlan_switches("$client_id","$found_vlan_id","$node_id");
						$updated="1";
					} else {
						my @switches_array=split(",",$switches);
						foreach ( @switches_array ) {
							#UPDATE VLAN switch info
							if ( $node_id && $switches !~ /^$node_id$/ && $switches !~ /^$node_id,/ && $switches !~ /,$node_id$/ &&  $switches !~ /,$node_id,/ ) {
								$gip->update_vlan_switches("$client_id","$found_vlan_id","$switches,$node_id");
								$updated="1";
							}
							if ( $asso_vlan_reverse_hash->{"$found_vlan_id"}[0] ) {
#								my $asso_vlan_switches = $asso_vlan_reverse_hash->{"$found_vlan_id"}[0] || "";
								my $asso_vlan_id=$asso_vlan_reverse_hash->{"$found_vlan_id"}[1] || "";
								my $asso_vlan_switches = $gip->get_vlan_switches("$client_id","$asso_vlan_id");
								if ( $node_id && $asso_vlan_switches !~ /^$node_id$/ && $asso_vlan_switches !~ /^$node_id,/ && $asso_vlan_switches !~ /,$node_id$/ &&  $asso_vlan_switches !~ /,$node_id,/ ) {
									$asso_vlan_switches= $asso_vlan_switches . "," . $node_id;
									$gip->update_vlan_switches_by_id("$client_id","$asso_vlan_id","$asso_vlan_switches");
									$asso_vlan_reverse_hash->{"$found_vlan_id"}[0] = $asso_vlan_switches;
								}
							}
						}
					}
				}
				last if $found == 1;
			}
			if ( $found == "1" && $updated != "1" ) {
				if ( $vars_file =~ /vars_he$/ ) {
					print "<span style=\"float: $ori\">$$lang_vars{ignorado_message} - $$lang_vars{vlan_exists_message} : $vlan_name - $vlan_num</span><br>\n";
				} else {
					print "$vlan_num - $vlan_name: $$lang_vars{vlan_exists_message} - $$lang_vars{ignorado_message}<br>\n";
				}
				$new_vlan="1";
				next;
			} elsif ( $found == "1" && $updated == "1" ) {
				if ( $vars_file =~ /vars_he$/ ) {
					print "<span style=\"float: $ori\">$$lang_vars{switches_info_updated} - $$lang_vars{vlan_exists_message} : $vlan_name - $vlan_num</span><br>\n";
				} else {
					print "$vlan_num - $vlan_name: $$lang_vars{vlan_exists_message} - $$lang_vars{switches_info_updated}<br>\n";
				}
				$new_vlan="1";
			}
			next if $updated == "1";

			if ( $vlan_num && $vlan_name ) {
				$gip->insert_vlan("$client_id","$vlan_num","$vlan_name","$comment","-1","black","white","$node_id");
				if ( $vars_file =~ /vars_he$/ ) {
					print "<span style=\"float: $ori\">$$lang_vars{vlan_added_message} - $vlan_name - $vlan_num</span><br>\n";
				} else {
					print "$vlan_name - $vlan_num - $$lang_vars{vlan_added_message}<br>\n";
				}
				$new_vlan="1";

				my $audit_type="36";
				my $audit_class="7";
				my $update_type_audit="7";
				my $event="$vlan_num, $vlan_name";
				$event=$event . "," . $comment if $comment;
				$gip->insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");
			}

		}

	} else {
#		print "<span style=\"float: $ori\">CISCO</span><br>\n";
		my $interfaces = $bridge->interfaces();
		my $vlans      = $bridge->i_vlan_membership();
		my $vlan_name=$bridge->v_name();
		my $vlan_index=$bridge->v_index();

		foreach my $key(%$vlan_index) {
			my $found="0";
			my $updated="0";
			my $newkey = $key;
			next if ! $$vlan_name{$key};
#			if ( $$vlan_name{$key} ) {
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
					my $switches=$gip->get_vlan_switches("$client_id","$found_vlan_id") || "";
					if ( ! $switches ) {
						$gip->update_vlan_switches("$client_id","$found_vlan_id","$node_id");
						$updated="1";
						$new_vlan="1";
					} else {
						my @switches_array=split(",",$switches);
						foreach ( @switches_array ) {
							#UPDATE VLAN switch info
							if ( $switches !~ /^$node_id$/ && $switches !~ /^$node_id,/ && $switches !~ /,$node_id$/ &&  $switches !~ /,$node_id,/ ) {
								$gip->update_vlan_switches("$client_id","$found_vlan_id","$switches,$node_id");
								$updated="1";
							}
							if ( $asso_vlan_reverse_hash->{"$found_vlan_id"}[0] ) {
								my $asso_vlan_id=$asso_vlan_reverse_hash->{"$found_vlan_id"}[1] || "";
								my $asso_vlan_switches = "";
								$asso_vlan_switches = $gip->get_vlan_switches("$client_id","$asso_vlan_id") if $asso_vlan_id;
								if ( $node_id && $asso_vlan_switches !~ /^$node_id$/ && $asso_vlan_switches !~ /^$node_id,/ && $asso_vlan_switches !~ /,$node_id$/ &&  $asso_vlan_switches !~ /,$node_id,/ ) {
									$asso_vlan_switches= $asso_vlan_switches . "," . $node_id;
									$gip->update_vlan_switches_by_id("$client_id","$asso_vlan_id","$asso_vlan_switches");
									$asso_vlan_reverse_hash->{"$found_vlan_id"}[0] = $asso_vlan_switches;
								}
							}
						}
					}
				}
				last if $found == 1;
			}

			if ( $found == "1" && $updated != "1" ) {
				print "$vlan_num - $vlan_name: $$lang_vars{vlan_exists_message} - $$lang_vars{ignorado_message}<br>\n";
				$new_vlan="1";
				next;
			} elsif ( $found == "1" && $updated == "1" ) {
				print "$vlan_num - $vlan_name: $$lang_vars{vlan_exists_message} - $$lang_vars{switches_info_updated}<br>\n";
				$new_vlan="1";
			}
			next if $updated == "1";

			if ( $vlan_num && $vlan_name ) {
				$gip->insert_vlan("$client_id","$vlan_num","$vlan_name","$comment","-1","black","white","$node_id");
				print "$vlan_name - $vlan_num - $$lang_vars{vlan_added_message}<br>\n";
				$new_vlan="1";

				my $audit_type="36";
				my $audit_class="7";
				my $update_type_audit="7";
				my $event="$vlan_num, $vlan_name";
				$event=$event . "," . $comment if $comment;
				$gip->insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");
			}
#			}
		}
	}
	print "<span style=\"float: $ori\">$$lang_vars{no_vlan_found_message}</span><br>\n" if $new_vlan == "0";
}
print "</span>\n";

print "<p><br>\n";

#my $item;
#my @uniq;
#foreach $item(@vlans_found) {
#	next if ! $item;
#	push(@uniq, $item) unless $seen{$item}++;
#}
#@vlans_found = @uniq;


#while ( my ( $vlan_name, $vlan_num)=each(%vlans_found) ) {
#	my $vlan_name_found=$gip->check_vlan_name("$client_id","$vlan_name") || "";
#	if ( $vlan_name_found ) {
#		print "$vlan_num - $vlan_name: VLAN EXISTS - $$lang_vars{ignorado_message}<br>\n";
#		next;
#	}
#	$gip->insert_vlan("$client_id","$last_vlan_id", "$vlan_num", "$vlan_name", "$comment", "black", "white");
#	print "$vlan_name => $vlan_num - $$lang_vars{anadido_message}<br>\n";
#	$last_vlan_id++;
#}

print "<h3 style=\"float: $ori\">$$lang_vars{listo_message}</h3><br><p>\n";

$gip->print_end("$client_id");
