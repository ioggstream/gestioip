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

my $base_uri = $gip->get_base_uri();
my $server_proto=$gip->get_server_proto();

#my $lang = $daten{'lang'} || "";
#my ($lang_vars,$vars_file,$entries_per_page,$lang)=$gip->get_lang("","$lang");
my ($lang_vars,$vars_file,$entries_per_page,$lang)=$gip->get_lang();

my $client_id = $daten{'client_id'} || $gip->get_first_client_id();
if ( $client_id !~ /^\d{1,4}$/ ) {
        $gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{unify_vlan_message}","$vars_file");
	$client_id=$gip->get_first_client_id();
        $gip->print_error("$client_id","$$lang_vars{client_id_invalid_message}","");
}

$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{unify_vlan_message}","$vars_file");

my $align="align=\"right\"";
my $align1="";
my $ori="left";
my $rtl_helper="<font color=\"white\">x</font>";
if ( $vars_file =~ /vars_he$/ ) {
	$align="align=\"left\"";
	$align1="align=\"right\"";
	$ori="right";
}



my $vlan_ids=$daten{'unir_vlans'} || "";
if ( ! $vlan_ids ) {
        $gip->print_error("$client_id","$$lang_vars{select_unify_vlans}","");
}
if ( $vlan_ids !~ /^\d+_\d+/ ) {
        $gip->print_error("$client_id","$$lang_vars{select_unify_vlans}","");
}

my %vlans=$gip->get_vlans_from_multiple_id_hash("$client_id","$vlan_ids");
my %assos=$gip->get_asso_vlan_reverse_hash("$client_id","$vlan_ids");


my ($unique_val,$first_vlan_name);
my $asso_exists ="0";
my $i="0";
while ( my ($key, @value) = each(%vlans) ) {
	$unique_val= $value[0]->[0] if $i == "0";
	$first_vlan_name= $value[0]->[1] if $i == "0";

	if ( $unique_val ne $value[0]->[0] ) {
		$gip->print_error("$client_id","$$lang_vars{unir_vlan_different_vlan_num_message1}<p> <span class=\"RedBold\">$unique_val</span> ($first_vlan_name) - <span class=\"RedBold\">$value[0]->[0]</span> ($value[0]->[1])<p><br>$$lang_vars{unir_vlan_different_vlan_num_message2} ") if $unique_val ne $value[0]->[0];
	}
	$asso_exists="1" if $assos{$key};
	$i++;
}

print "<span style=\"float: $ori\"><p>$$lang_vars{new_vlan_name_message}<p></span><br><p><br>\n";
print "<form method=\"POST\" action=\"$server_proto://$base_uri/res/ip_unirvlan.cgi\">\n";


print "<span style=\"float: $ori\">\n";
my $all_vlan_ids="";
while ( my ($key, @value) = each(%vlans) ) {

	if ( ! defined($assos{"$key"}) && $asso_exists eq "1" ) {
		next;
	}
	print "$rtl_helper<input type=\"radio\" name=\"vlan_id\" value=\"$key\"> $value[0]->[1]<br>\n";
}

print "</span><br><p>";
print "<br><p><span style=\"float: $ori\"><input type=\"hidden\" value=\"$vlan_ids\" name=\"vlan_ids\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input type=\"submit\" value=\"$$lang_vars{submit_message}\" name=\"B2\" class=\"input_link_w\"></span>\n";
print "</form>\n";


$gip->print_end("$client_id");

