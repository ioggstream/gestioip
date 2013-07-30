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
use DBI;
use lib './modules';
use GestioIP;

my $daten=<STDIN>;
my $gip = GestioIP -> new();
my %daten=$gip->preparer("$daten") if $daten;

my $lang = $daten{'lang'} || "";
my ($lang_vars,$vars_file)=$gip->get_lang("","$lang");

my $client_id = $daten{'client_id'} || $gip->get_first_client_id();

$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{about_message}","$vars_file");

my $align="align=\"right\"";
my $align1="";
my $ori="left";
my $rtl_helper="<font color=\"white\">x</font>";
if ( $vars_file =~ /vars_he$/ ) {
        $align="align=\"left\"";
        $align1="align=\"right\"";
        $ori="right";
}


my $version=$gip->get_version();
my $anz_clients_all=$gip->count_clients("$client_id") || "0";
my $anz_red_all=$gip->count_red_entries_all("$client_id","NULL","NULL","all") || "0";
my $anz_host_all=$gip->count_all_host_entries("$client_id","all") || "0";
my $anz_vlans=$gip->count_all_vlan_entries("$client_id","all") || "0";
my $patch_version=$gip->get_patch_version();

print "<p>";
print "<span class=\"AboutTextGestio\">$$lang_vars{gestioip_message}</span> <span class=\"AboutTextGestioVersion\">$$lang_vars{v_message}$version</span> ($$lang_vars{patch_version_message} $patch_version)<br>\n";
print "<span class=\"AboutTextGestioIPAM\">&nbsp;&nbsp;$$lang_vars{ip_address_management_message}</span><p>\n";
print "<p><br>$$lang_vars{copyright_message}";
print "<p><br><p><br><p>";



#print <<EOF;
#<p>
#<table border="1">
#
#<tr><td $align><span class=\"AboutTextGestio\">$$lang_vars{gestioip_message}</span></td>
#<td $align valign="bottom"><span class=\"AboutTextGestioVersion\">$$lang_vars{v_message}$version $rtl_helper</span></td>
#<td $align valign="bottom"> $rtl_helper($$lang_vars{patch_version_message} $patch_version)$rtl_helper</td></tr>
#</table>
#<tr><td $align><span class=\"AboutTextGestioIPAM\" style=\"float: $ori\">$$lang_vars{ip_address_management_message}</span><br>
#<br><span style=\"float: $ori\">$$lang_vars{copyright_message}$rtl_helper</span>$rtl_helper
#<p><br><p>
#<table border=\"0\"><tr><td>
#$$lang_vars{redes_total_messages}</td></tr>
#EOF

print "$$lang_vars{redes_total_messages}</td></tr>\n";
print "<table border=\"0\">";
if ( $anz_clients_all > 1 ) {
	print "<tr><td><span class=\"table_text_about\"><b>$anz_clients_all</b> $$lang_vars{clients_message}</span></td></tr>\n";
	print "<tr><td></b>$$lang_vars{con_message}</td></tr><tr>\n";
	if ( $anz_red_all == 1 ) {
		print "<tr><td><span class=\"table_text_about\"><b>$anz_red_all</b> $$lang_vars{network_message}</span></td></tr>\n";
	} else {
		print "<tr><td><span class=\"table_text_about\"><b>$anz_red_all</b> $$lang_vars{about_redes_dispo_message}</span></td></tr>\n";
	}
	print "<tr><td></b>$$lang_vars{y_message}</td></tr><tr>\n";
	print "<tr><td><span class=\"table_text_about\"><b>$anz_vlans</b> $$lang_vars{vlans_message}</span></td></tr>\n";
	print "<tr><td></b>$$lang_vars{y_message}</td></tr>\n";
	print "<tr><td><span class=\"table_text_about\"><b>$anz_host_all</b> $$lang_vars{entradas_host_message}</span></td></tr>";
	print "</table>\n";
} else {
	print "<br><p>";
	if ( $anz_red_all == 1 ) {
		print "<tr><td nowrap><span class=\"table_text_about\"><b>$anz_red_all</b> $$lang_vars{network_message}, <b>$anz_vlans</b> $$lang_vars{vlans_message} $$lang_vars{y_message} <b>$anz_host_all</b> $$lang_vars{entradas_host_message}</span></td></tr>\n";
	} else {
		print "<tr><td nowrap><span class=\"table_text_about\"><b>$anz_red_all</b> $$lang_vars{about_redes_dispo_message}, <b>$anz_vlans</b> $$lang_vars{vlans_message} $$lang_vars{y_message} <b>$anz_host_all</b> $$lang_vars{entradas_host_message}</span></td></tr>\n";
	}
	print "</table>\n";
	print "<p><br><p><br><p><br><p>";
}
print "<br><p><br>";
print "<p><br><p><br><p><br><p><br>";
print "$$lang_vars{visita_gestioip_message}\n";
print "<br><p><br>";

$gip->print_end("$client_id","$vars_file");
