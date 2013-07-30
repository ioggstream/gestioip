#!/usr/bin/perl -w -T

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
use lib '../modules';
use GestioIP;


my $gip = GestioIP -> new();
my $daten=<STDIN>;
my %daten=$gip->preparer($daten);

my ($lang_vars,$vars_file,$entries_per_page,$lang)=$gip->get_lang();
my $base_uri = $gip->get_base_uri();

my $client_id = $daten{'client_id'} || $gip->get_first_client_id();
if ( $client_id !~ /^\d{1,4}$/ ) {
        $gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{unify_vlan_message}","$vars_file");
        $gip->print_error("$client_id","$$lang_vars{client_id_invalid_message}","");
}


if ( ! $daten{'vlan_id'} ) {
        $gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{unify_vlan_message}","$vars_file");
	$gip->print_error("$client_id","$$lang_vars{select_unify_vlan_message}");
}
if ( $daten{'vlan_id'} !~ /^\d{1,6}$/ ) {
        $gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{unify_vlan_message}","$vars_file");
	$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (1)");
}
if ( $daten{'vlan_ids'} !~ /^(\d{1,6}_)*(\d{1,6})$/ ) {
        $gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{unify_vlan_message} $daten{'vlan_ids'}","$vars_file");
	$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (2)");
}
my $good_vlan_id=$daten{'vlan_id'};
my $vlan_ids=$daten{'vlan_ids'};


my @values_good_vlan=$gip->get_vlan("$client_id","$good_vlan_id");
my $good_vlan_num=$values_good_vlan[0]->[0];
my $good_vlan_name=$values_good_vlan[0]->[1];
my $good_comment=$values_good_vlan[0]->[2];
my $good_bg_color=$values_good_vlan[0]->[3];
my $good_font_color=$values_good_vlan[0]->[4];
my $good_vlan_provider_id=$values_good_vlan[0]->[5];
my $good_switches=$values_good_vlan[0]->[6];

$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{vlan_joined_message} \"$good_vlan_num - $good_vlan_name\"","$vars_file");
#print "<b>$$lang_vars{vlan_joined_message} \"$good_vlan_num - $good_vlan_name\"</b><p>\n";

my @vlan_id_array=split("_",$vlan_ids);
#my @switches_array;

foreach ( @vlan_id_array ) {
	my @switches_array = ();
	my $switches="";
	my $vlan_id = $_;
	next if $vlan_id eq $good_vlan_id;
	my @values_vlan=$gip->get_vlan("$client_id","$vlan_id");
	my $vlan_num=$values_vlan[0]->[0];
	my $vlan_name=$values_vlan[0]->[1];
	my $comment=$values_vlan[0]->[2];
	my $bg_color=$values_vlan[0]->[3];
	my $font_color=$values_vlan[0]->[4];
	my $vlan_provider_id=$values_vlan[0]->[5];
	$switches=$values_vlan[0]->[6];
	if ( $switches ) {
		@switches_array=split(",",$switches);
		foreach ( @switches_array ) {
			if ( $good_switches !~ /^$_$/ && $good_switches !~ /^$_,/ && $good_switches !~ /,$_$/ && $good_switches !~ /,$_,/ ) {
				$good_switches = $good_switches . "," . $_;
			}
		}
	}
#	$gip->update_vlan_switches_by_id("$client_id","$good_vlan_id","$good_switches");
#	$gip->insert_vlan_asso("$client_id","$good_vlan_id","$vlan_name");
	$gip->insert_vlan_asso_new("$client_id","$good_vlan_id","$vlan_id");
	$gip->update_cc_vlan_entry("$client_id","$vlan_num - $vlan_name","$good_vlan_num - $good_vlan_name");
#	$gip->delete_vlan_without_asso("$client_id","$vlan_id");
}
$gip->update_vlan_switches_by_id("$client_id","$good_vlan_id","$good_switches");

my $vlan_ids_without_asso_vlan=$vlan_ids;
$vlan_ids_without_asso_vlan =~ s/$good_vlan_id//;
$vlan_ids_without_asso_vlan =~ s/^,//;
$vlan_ids_without_asso_vlan =~ s/,,/,/;
$vlan_ids_without_asso_vlan =~ s/,$//;
$gip->update_vlan_assos("$client_id","$vlan_ids_without_asso_vlan","$good_vlan_id");


my @vlans=$gip->get_vlans("$client_id");

if ( $vlans[0] ) {
        $gip->PrintVLANTab("$client_id",\@vlans,"show_ip.cgi","detalles","$vars_file","unir");
} else {
        print "<p class=\"NotifyText\">$$lang_vars{no_resultado_message}</p><br>\n";
}

$gip->print_end("$client_id");
