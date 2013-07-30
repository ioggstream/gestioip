#!/usr/bin/perl -w -T

# Script to kill GestioIP's initialization processes

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
use FindBin qw($Bin);
use Getopt::Long;
Getopt::Long::Configure ("no_ignore_case");

my ($client_id,$user);

GetOptions(
        "id_client=s"=>\$client_id,
	"user=s"=>\$user
) or die "Wrong arguments\n";

if ( ! $client_id ) {
        print STDERR "NOT ENOUGH ARGUMENTS\nEXITING\n";
        exit 1;
}

$client_id =~ /^(\d{1,5})$/;
$client_id = $1;

my $dir = $Bin;
$dir =~ /^(.*)\/bin/;
my $base_dir=$1;


my $pidfile_initialize = $base_dir . "/var/run/" . $client_id . "_web_initialize_gestioip.pid";
my $pidfile_import_vlans = $base_dir . "/var/run/" . $client_id . "_web_ip_import_vlans.pid";
my $pidfile_get_networks = $base_dir . "/var/run/" . $client_id . "_web_get_networks_snmp.pid";
my $pidfile_update_snmp = $base_dir . "/var/run/" . $client_id . "_web_ip_update_gestioip_snmp.pid";
my $pidfile_update_dns = $base_dir . "/var/run/" . $client_id . "_web_ip_update_gestioip_dns.pid";

my $pid;
if ( -e $pidfile_import_vlans ) {
	open(PID,"<$pidfile_import_vlans");
	while(<PID>) {
		$pid = $_ if $_ =~ /^\d+$/;
	}
	close PID;
	$pid =~ /^(\d{1,12})$/;
	$pid = $1;
	kill TERM => $pid if $pid;
}
if ( -e $pidfile_get_networks ) {
	open(PID,"<$pidfile_get_networks");
	while(<PID>) {
		$pid = $_ if $_ =~ /^\d+$/;
	}
	close PID;
	$pid =~ /^(\d{1,12})$/;
	$pid = $1;
	kill TERM => $pid if $pid;
}
if ( -e $pidfile_update_snmp ) {
	open(PID,"<$pidfile_update_snmp");
	while(<PID>) {
		$pid = $_ if $_ =~ /^\d+$/;
	}
	close PID;
	$pid =~ /^(\d{1,12})$/;
	$pid = $1;
	kill TERM => $pid if $pid;
}
if ( -e $pidfile_update_dns ) {
	open(PID,"<$pidfile_update_dns");
	while(<PID>) {
		$pid = $_ if $_ =~ /^\d+$/;
	}
	close PID;
	$pid =~ /^(\d{1,12})$/;
	$pid = $1;
	kill TERM => $pid if $pid;
}

sleep 10;
if ( -e $pidfile_initialize ) {
	open(PID,"<$pidfile_initialize");
	while(<PID>) {
		$pid = $_ if $_ =~ /^\d+$/;
	}
	close PID;
	$pid =~ /^(\d{1,12})$/;
	$pid = $1;
	kill TERM => $pid if $pid;
}
