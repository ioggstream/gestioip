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


my $daten=<STDIN>;
my $gip = GestioIP -> new();
my %daten=$gip->preparer($daten);

my $base_uri = $gip->get_base_uri();
my $server_proto=$gip->get_server_proto();

my $lang = $daten{'lang'} || "";
my ($lang_vars,$vars_file)=$gip->get_lang("","$lang");

my $admin_type=$daten{'admin_type'} || "";

my $client_id = $daten{'client_id'} || $gip->get_first_client_id();


my $provider_name=$daten{'provider_name'};
my $comment=$daten{'comment'} || "";
my $vlan_provider_id=$gip->check_vlan_provider_exists("$client_id","$provider_name");
if ( $vlan_provider_id ) {
	$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{insert_vlanprovider_message}","$vars_file");
	$gip->print_error("$client_id","$$lang_vars{vlan_provider_exists_message}: $provider_name");
}

$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{vlan_provider_added_message}: $provider_name","$vars_file");

my $last_vlan_provider_id=$gip->get_last_vlan_provider_id("$client_id");
$last_vlan_provider_id="0" if $last_vlan_provider_id == "-1";
$last_vlan_provider_id++;
$gip->insert_vlan_provider("$client_id","$last_vlan_provider_id","$provider_name","$comment");

my $audit_type="39";
my $audit_class="5";
my $update_type_audit="1";
my $event="$provider_name";
$event = $event . " - " . $comment if $comment;
$gip->insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");


my @values_vlan_providers=$gip->get_vlan_providers("$client_id");


#print "<table border=\"0\" cellpadding=\"25\" cellspacing=\"1\" width=\"100%\"><tr><td>\n\n";

print "<br><p>\n";

$gip->PrintVLANproviderTab("$client_id","$vars_file");

$gip->print_end("$client_id");
