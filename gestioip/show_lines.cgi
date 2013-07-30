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

$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{lls_message}","$vars_file");

my $align="align=\"right\"";
my $align1="";
my $ori="left";
my $rtl_helper="<font color=\"white\">x</font>";
if ( $vars_file =~ /vars_he$/ ) {
	$align="align=\"left\"";
	$align1="align=\"right\"";
	$ori="right";
}


my @ll;
@ll=$gip->get_ll("$client_id");

print <<EOF;

<script language="JavaScript" type="text/javascript" charset="utf-8">
<!--
function show_searchform(){

document.getElementById('search_text').innerHTML='<input type=\"text\" size=\"15\" name=\"match\" > <input type="submit" value="" class="button" style=\"cursor:pointer;\"><br><p>';
document.search_ll.match.focus();

}
-->
</script>

<form name="search_ll" method="POST" action="$server_proto://$base_uri/ip_search_ll.cgi" style="display:inline"><input type="hidden" name="client_id" value="$client_id">
EOF


print "<span style=\"float: right;\"><span id=\"search_text\"><img src=\"$server_proto://$base_uri/imagenes/lupe.png\" alt=\"search\" style=\"float: right; cursor:pointer;\" onclick=\"show_searchform('');\"></span></span><br>";
print "</form>\n";



if ( $ll[0] ) {
	$gip->PrintLLTab("$client_id",\@ll,"$vars_file");
} else {
	print "<p class=\"NotifyText\">$$lang_vars{no_resultado_message}</p><br>\n";
}

#print "<span style=\"float: $ori\"><FORM><INPUT TYPE=\"BUTTON\" VALUE=\"$$lang_vars{atras_message}\" ONCLICK=\"history.go(-1)\" class=\"error_back_link\"></FORM></span>\n";

$gip->print_end("$client_id","$vars_file","go_to_top");

