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
my %daten=$gip->preparer($daten);

my $base_uri=$gip->get_base_uri();

my $lang = $daten{'lang'} || "";
my ($lang_vars,$vars_file)=$gip->get_lang("","$lang");
my $server_proto=$gip->get_server_proto();

my $client_id = $daten{'client_id'} || $gip->get_first_client_id();

my @values_locations=$gip->get_loc("$client_id");
my @values_categorias=$gip->get_cat("$client_id");
my $anz_clients_all=$gip->count_clients("$client_id");

my @global_config = $gip->get_global_config("$client_id");
my $ipv4_only_mode=$global_config[0]->[5] || "yes";

$gip->print_init("$$lang_vars{buscar_host_message}","$$lang_vars{advanced_host_search_message}","$$lang_vars{advanced_host_search_message}","$vars_file","$client_id");

my @cc_values=$gip->get_custom_host_columns("$client_id");

my $align="align=\"right\"";
my $align1="";
my $ori="left";
if ( $vars_file =~ /vars_he$/ ) {
	$align="align=\"left\"";
	$align1="align=\"right\"";
	$ori="right";
}

print "<br><form method=\"POST\" name=\"searchip\" action=\"$server_proto://$base_uri/ip_searchip.cgi\">\n";
print "<table border=\"0\" cellpadding=\"5\" cellspacing=\"2\"><tr><td $align>";

if ( $anz_clients_all > 1 ) {
        print "$$lang_vars{client_independent_message}</td><td><input type=\"checkbox\" name=\"client_independent\" value=\"yes\">";
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
print "$$lang_vars{hostname_message}:</td><td $align1><input name=\"hostname\" type=\"text\"  size=\"10\" maxlength=\"75\">";
print " exact match: <input type=\"checkbox\" name=\"hostname_exact\" value=\"on\"></td></tr><tr><td $align>"; 
print "$$lang_vars{description_message}:</td><td $align1><input name=\"host_descr\" type=\"text\"  size=\"15\" maxlength=\"100\"></td><td>";
print "</td></tr><tr><td $align>";
print "$$lang_vars{comentario_message}:</td><td $align1><input name=\"comentario\" type=\"text\"  size=\"15\" maxlength=\"100\"><br>";
print "</td></tr><tr><td $align>";
print "IP:</td><td $align1><input name=\"ip\" type=\"text\"  size=\"15\" maxlength=\"15\"><br>";
print "</td></tr><tr><td $align>";
print "$$lang_vars{loc_message}:</td><td $align1><select name=\"loc\" size=\"1\">";
print "<option></option>";
my $j=0;
foreach (@values_locations) {
        $values_locations[$j]->[0] = "" if ( $values_locations[$j]->[0] eq "NULL" );
        print "<option>$values_locations[$j]->[0]</option>" if ( $values_locations[$j]->[0] );
        $j++;
}

print "</select>";
print "</td></tr><tr><td $align>";
print "$$lang_vars{cat_message}:</td><td $align1> <select name=\"cat\" size=\"1\">";
print "<option></option>";
$j=0;
foreach (@values_categorias) {
        $values_categorias[$j]->[0] = "" if ( $values_categorias[$j]->[0] eq "NULL" );
        print "<option>$values_categorias[$j]->[0]</option>" if ( $values_categorias[$j]->[0] );
        $j++;
}
print "</select></td></tr>";
print "<tr><td colspan=\"2\"><br></td></tr>";


for ( my $k = 0; $k < scalar(@cc_values); $k++ ) {
        print "<tr><td $align>$cc_values[$k]->[0]</td><td><input type=\"text\" name=\"cc_id_$cc_values[$k]->[1]\" size=\"15\"></td></tr>";
}

print "<tr><td colspan=\"2\"><br></td></tr>";
print "</tr><tr><td $align>$$lang_vars{ia_wrap_message}<td colspan=\"3\" $align1><input type=\"checkbox\" name=\"int_admin\" value=\"y\">\n";

print "</td></tr></table>";

print "<br><p><input name=\"search_index\" type=\"hidden\" value=\"true\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input type=\"submit\" value=\"$$lang_vars{buscar_message}\" name=\"B2\" class=\"input_link_w\" style=\"float: $ori\"></form>\n";

print "<script type=\"text/javascript\">\n";
print "document.searchip.hostname.focus();\n";
print "</script>\n";

$gip->print_end("$client_id");
