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

my $provider_id = "";
$provider_id=$daten{'provider_id'} if $daten{'provider_id'};
my $comment=$daten{'comment'} || "";

my $client_id = $daten{'client_id'} || $gip->get_first_client_id();
my $name=$daten{'name'} || $gip->print_error("$client_id","$$lang_vars{insert_vlanprovider_name_message}");

$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{show_vlan_providers_message}","$vars_file");

my @values_vlan_provider=$gip->get_vlan_provider("$client_id","$provider_id");

my $old_provider_name = $values_vlan_provider[0]->[0] || "";
my $old_provider_comment = $values_vlan_provider[0]->[1] || "";

if ( $old_provider_name ne $name || $old_provider_comment ne $comment ) {
	$gip->update_vlanprovider("$client_id","$provider_id","$comment","$name");

	my $audit_type="41";
	my $audit_class="5";
	my $update_type_audit="1";
	my $event="$old_provider_name,$old_provider_comment -> $name,$comment";
	$gip->insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");
}


$gip->PrintVLANproviderTab("$client_id","$vars_file");

$gip->print_end("$client_id");
