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

my $server_proto=$gip->get_server_proto();

my $lang = $daten{'lang'} || "";
my ($lang_vars,$vars_file)=$gip->get_lang("","$lang");
my $base_uri = $gip->get_base_uri();


my $client_id = $daten{'client_id'} || $gip->get_first_client_id();
$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{add_vlan_message}","$vars_file");

my $align="align=\"right\"";
my $align1="";
my $ori="left";
my $rtl_helper="<font color=\"white\">x</font>";
if ( $vars_file =~ /vars_he$/ ) {
	$align="align=\"left\"";
	$align1="align=\"right\"";
	$ori="right";
}


my @values_clientes=$gip->get_vlan_providers("$client_id");
my $anz_vlan_providers=$gip->count_vlan_providers("$client_id");


print "<p>\n";
print "<form name=\"insertvlan_form\" method=\"POST\" action=\"$server_proto://$base_uri/res/ip_insertvlan.cgi\"><br>\n";
print "<table border=\"0\" cellpadding=\"5\" cellspacing=\"2\">\n";

print "<tr><td $align>$$lang_vars{vlan_number_message}</td><td $align1><input name=\"vlan_num\" type=\"text\"  size=\"10\" maxlength=\"10\"></td></tr>\n";
print "<tr><td $align>$$lang_vars{vlan_name_message}</td><td $align1><input name=\"vlan_name\" type=\"text\"  size=\"15\" maxlength=\"50\"></td></tr>\n";
print "<tr><td $align>$$lang_vars{vlan_comment_message}</td><td $align1><input name=\"comment\" type=\"text\"  size=\"30\" maxlength=\"500\"></td></tr>\n";
print "<tr><td $align>$$lang_vars{vlan_provider_message}</td><td $align1>";
my $j=0;
#if ( $values_clientes[0] ) {
if ( $anz_vlan_providers >= "1" ) {

	print "<select name=\"vlan_provider_id\" size=\"1\">";
	#print "<option></option>\n";
	my $opt;
	foreach $opt(@values_clientes) {
	
		if ( $values_clientes[$j]->[1] eq "-1" ) {
			print "<option value=\"$values_clientes[$j]->[1]\"></option>";
		} else {
			print "<option value=\"$values_clientes[$j]->[1]\">$values_clientes[$j]->[0]</option>";
		}
		$j++;
	}
	print "</select></td></tr>\n";
} else {
	print "<font color=\"gray\"><i>$$lang_vars{no_vlan_providers_message}</i></font>\n";
}
print "</table>";
print "<p>\n";
print "<table><tr><td><b>$$lang_vars{bg_message}</b></td><td><b>$$lang_vars{font_message}</b></td></tr><tr><td $align1>";

print "<select name=\"bg_color\" size=\"5\">";
print "<OPTION class=\"gold\" value=\"amar\">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</OPTION>\n";
print "<OPTION class=\"DarkOrange\" value=\"orano\"></OPTION>\n";
print "<OPTION class=\"brown\" value=\"maro\"></OPTION>\n";
print "<OPTION class=\"red\" value=\"rojo\"></OPTION>\n";
print "<OPTION class=\"pink\" value=\"pink\"></OPTION>\n";
print "<OPTION class=\"LightCyan\" value=\"azulcc\"></OPTION>\n";
print "<OPTION class=\"LightBlue\" value=\"azulc\"></OPTION>\n";
#print "<OPTION class=\"dodgerblue\" value=\"azulo\"></OPTION>\n";
print "<OPTION class=\"LimeGreen\" value=\"verc\"></OPTION>\n";
#print "<OPTION class=\"DarkSeaGreen\" value=\"vero\"></OPTION>\n";
#print "<OPTION class=\"SeaGreen\" value=\"vero\"></OPTION>\n";
print "<OPTION class=\"white\" value=\"blan\"></OPTION>\n";
print "<OPTION class=\"black\" value=\"negr\"></OPTION>\n";
print "</SELECT>\n";

print "</td><td $align1>";

print "<select name=\"font_color\" size=\"5\">";
print "<OPTION class=\"gold\" value=\"amar\">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</OPTION>\n";
print "<OPTION class=\"DarkOrange\" value=\"orano\"></OPTION>\n";
print "<OPTION class=\"brown\" value=\"maro\"></OPTION>\n";
print "<OPTION class=\"red\" value=\"rojo\"></OPTION>\n";
print "<OPTION class=\"LightCyan\" value=\"azulcc\"></OPTION>\n";
print "<OPTION class=\"LightBlue\" value=\"azulc\"></OPTION>\n";
#print "<OPTION class=\"dodgerblue\" value=\"azulo\"></OPTION>\n";
#print "<OPTION class=\"LimeGreen\" value=\"verc\"></OPTION>\n";
print "<OPTION class=\"SeaGreen\" value=\"vero\"></OPTION>\n";
#print "<OPTION class=\"DarkSeaGreen\" value=\"vero\"></OPTION>\n";
print "<OPTION class=\"white\" value=\"blan\"></OPTION>\n";
print "<OPTION class=\"black\" value=\"negr\"></OPTION>\n";
print "</SELECT>\n";

print "</td></tr></table>\n";

print "<script type=\"text/javascript\">\n";
	print "document.insertvlan_form.vlan_num.focus();\n";
print "</script>\n";

print "<span style=\"float: $ori\"><br><p><input type=\"hidden\" value=\"$client_id\" name=\"client_id\"><input type=\"submit\" value=\"$$lang_vars{add_message}\" name=\"B2\" class=\"input_link_w_net\"></form></span><br><p>\n";

$gip->print_end("$client_id");
