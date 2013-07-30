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

my $daten=<STDIN>;
my $gip = GestioIP -> new();
my %daten=$gip->preparer($daten);

my $base_uri = $gip->get_base_uri();

my $lang = $daten{'lang'} || "";
my ($lang_vars,$vars_file)=$gip->get_lang("","$lang");
my $server_proto=$gip->get_server_proto();

my $client_id = $daten{'client_id'} || $gip->get_first_client_id();

$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{borrar_vlanprovider_message}","$vars_file");

my $align="align=\"right\"";
my $align1="";
my $ori="left";
my $rtl_helper="<font color=\"white\">x</font>";
if ( $vars_file =~ /vars_he$/ ) {
	$align="align=\"left\"";
	$align1="align=\"right\"";
	$ori="right";
}

my $provider_id=$daten{'provider_id'} || $gip->print_error("$client_id","$$lang_vars{mal_signo_error_message}");
my $provider_name=$daten{'provider_name'} || "";

$gip->update_vlans_vlan_provider("$client_id","$provider_id");
$gip->delete_vlan_provider("$client_id","$provider_id");

my $audit_type="40";
my $audit_class="5";
my $update_type_audit="1";
my $event="$provider_name";
$gip->insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");


if ( $vars_file =~ /vars_he$/ ) {
	print "<p><span style=\"float: $ori\"><b><i>$provider_name</i> :$$lang_vars{borrar_vlanprovider_done_message}</b></span><br><p>\n";
} else {
	print "<p><b>$$lang_vars{borrar_vlanprovider_done_message}: <i>$provider_name</i></b><p>\n";
}

$gip->PrintVLANproviderTab("$client_id","$vars_file");

$gip->print_end("$client_id");
