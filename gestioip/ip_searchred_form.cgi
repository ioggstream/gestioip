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
use lib './modules';
use DBI;
use GestioIP;

my $daten=<STDIN>;
my $gip = GestioIP -> new();
my %daten=$gip->preparer("$daten") if $daten;

my $base_uri=$gip->get_base_uri();

my $lang = $daten{'lang'} || "";
my ($lang_vars,$vars_file)=$gip->get_lang("","$lang");
my $server_proto=$gip->get_server_proto();

my $client_id = $daten{'client_id'} || $gip->get_first_client_id();

my @values_locations=$gip->get_loc("$client_id");
my @values_cat_red=$gip->get_cat_net("$client_id");
my $anz_clients_all=$gip->count_clients("$client_id");

my @cc_values=$gip->get_custom_columns("$client_id");

my @global_config = $gip->get_global_config("$client_id");
my $ipv4_only_mode=$global_config[0]->[5] || "yes";

my $align="align=\"right\"";
my $align1="";
my $ori="left";
if ( $vars_file =~ /vars_he$/ ) {
	$align="align=\"left\"";
	$align1="align=\"right\"";
	$ori="right";
}

$gip->print_init("$$lang_vars{buscar_red_message}","$$lang_vars{advanced_network_search_message}","$$lang_vars{advanced_network_search_message}","$vars_file","$client_id");
print "<br><form method=\"POST\" name=\"searchread\" action=\"$server_proto://$base_uri/ip_searchred.cgi\">\n";
print "<table border=\"0\" cellpadding=\"5\" cellspacing=\"2\"><tr><td $align>";

if ( $anz_clients_all > 1 ) {
	print "$$lang_vars{client_independent_message}</td><td colspan=\"3\"><input type=\"checkbox\" name=\"client_independent\" value=\"yes\">";
	print "</td></tr>";
}

if ( $ipv4_only_mode ne "yes" ) {
print <<EOF;
<tr><td $align> $$lang_vars{ip_version_message}</td>
        <td colspan="3" $align1>&nbsp;&nbsp;&nbsp;v4<input type="checkbox" name="ipv4" value="ipv4" checked>&nbsp;&nbsp;&nbsp;v6<input type="checkbox" name="ipv6" value="ipv6" checked><font color=\"white\">x</font></td></tr>
EOF
}

print "<tr><td colspan=\"4\"><br></td></tr>\n";
print "<tr><td $align>";
print "$$lang_vars{redes_message} ID:</td><td colspan=\"3\" $align1><input name=\"red\" type=\"text\"  size=\"15\" maxlength=\"15\">";
print "</td></tr><tr><td $align>";
print "$$lang_vars{description_message}:</td><td colspan=\"3\" $align1><input name=\"descr\" type=\"text\"  size=\"15\" maxlength=\"30\">";
print "</td></tr><tr><td $align>";
print "$$lang_vars{comentario_message}:</td><td colspan=\"3\" $align1><input name=\"comentario\" type=\"text\"  size=\"15\" maxlength=\"30\">";
print "</td></tr><tr><td $align>";
print "$$lang_vars{loc_message}: </td><td colspan=\"3\" $align1><select name=\"loc\" size=\"1\">";
print "<option></option>";
my $j=0;
foreach (@values_locations) {
        print "<option>$values_locations[$j]->[0]</option>" if ( $values_locations[$j]->[0] ne "NULL" );
        $j++;
}
print "</select></td><tr><td $align>\n";
print "$$lang_vars{cat_message}: </td><td colspan=\"3\" $align1><select name=\"cat_red\" size=\"1\">";
print "<option></option>";
$j=0;
foreach (@values_cat_red) {
        print "<option>$values_cat_red[$j]->[0]</option>" if ( $values_cat_red[$j]->[0] ne "NULL" );
        $j++;
}
print "</select>\n";
print "</td></tr>\n";
print "<tr><td colspan=\"4\"><br></td></tr>\n";
#print "</td></tr><tr></tr><td colspan=\"4\"><br></td><tr><td>";

for ( my $k = 0; $k < scalar(@cc_values); $k++ ) {
        print "<tr><td $align>$cc_values[$k]->[0]</td><td colspan=\"3\"><input type=\"text\" name=\"cc_id_$cc_values[$k]->[1]\" size=\"15\"></td></tr>";
}

print "<tr><td colspan=\"4\"><br></td></tr>\n";
print "<tr><td $align>";
print "$$lang_vars{sincronizado_message}: </td><td><input type=\"radio\" name=\"vigilada\" value=\"\" checked> $$lang_vars{todos_message}&nbsp;&nbsp;&nbsp;&nbsp;</td><td><input type=\"radio\" name=\"vigilada\" value=\"y\"> $$lang_vars{solo_sinc_message}&nbsp;&nbsp;&nbsp;&nbsp;</td><td><input type=\"radio\" name=\"vigilada\" value=\"n\">$$lang_vars{solo_no_sinc_message}\n";
print "</td></tr></table><br>";
print "<p><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input type=\"submit\" value=\"$$lang_vars{buscar_message}\" name=\"B2\" class=\"input_link_w\" style=\"float: $ori\">&nbsp;&nbsp;&nbsp;&nbsp;";
print "<input type=\"checkbox\" name=\"modred\" value=\"y\" style=\"float: $ori\"> <span class=\"HintText\" style=\"float: $ori\">$$lang_vars{para_modificar_message}</span>\n";
print "</form>\n";

print "<script type=\"text/javascript\">\n";
print "document.searchread.red.focus();\n";
print "</script>\n";

$gip->print_end("$client_id");

