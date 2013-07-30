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


use DBI;
use strict;
use lib './modules';
use GestioIP;


my $daten=<STDIN>;
my $gip = GestioIP -> new();
my %daten=$gip->preparer("$daten") if $daten;

my $lang = $daten{'lang'} || "";
my ($lang_vars,$vars_file,$entries_per_page)=$gip->get_lang("","$lang");
my $server_proto=$gip->get_server_proto();
my $base_uri=$gip->get_base_uri();


my $client_id = $daten{'client_id'} || $gip->get_first_client_id();
my $match = $daten{'match'} || "";

$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{vlans_message}","$vars_file");

$gip->print_error("$client_id","$$lang_vars{no_search_string_message}") if ! $match;

my $align="align=\"right\"";
my $align1="";
my $ori="left";
my $rtl_helper="<font color=\"white\">x</font>";
if ( $vars_file =~ /vars_he$/ ) {
	$align="align=\"left\"";
	$align1="align=\"right\"";
	$ori="right";
}


my @vlans;
@vlans=$gip->get_vlans_match("$client_id","$match");

print <<EOF;
<script language="JavaScript" type="text/javascript" charset="utf-8">
<!--
function focus_search_vlan(){
   document.search_ll.match.focus();
}
-->
</script>


<form name="search_vlan" method="POST" action="$server_proto://$base_uri/ip_search_vlan.cgi" style="display:inline"><input type="hidden" name="client_id" value="$client_id">
EOF

print "<span style=\"float: right;\"><input type=\"text\" size=\"15\" name=\"match\" value=\"$match\"> <input type=\"submit\" value=\"\" class=\"button\" style=\"cursor:pointer;\"></span><br>";
print "</form>\n";

if ( $vlans[0] ) {
	$gip->PrintVLANTab("$client_id",\@vlans,"show_ip.cgi","detalles","$vars_file","");
} else {
	print "<p class=\"NotifyText\">$$lang_vars{no_resultado_message}</p><br>\n";
}


$gip->print_end("$client_id","$vars_file","go_to_top");

