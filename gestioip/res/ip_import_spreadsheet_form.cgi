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
use Cwd;

my $daten=<STDIN>;
my $gip = GestioIP -> new();
my %daten=$gip->preparer($daten);

my $base_uri = $gip->get_base_uri();
my $server_proto=$gip->get_server_proto();

my $lang = $daten{'lang'} || "";
my ($lang_vars,$vars_file)=$gip->get_lang("","$lang");


my $client_id = $daten{'client_id'} || $gip->get_first_client_id();
if ( $client_id !~ /^\d{1,4}$/ ) {
	$client_id = 1;
	$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{import_from_sheet_message}","$vars_file");
	$gip->print_error("$client_id","$$lang_vars{formato_malo_message}");
}

my @config = $gip->get_config("$client_id");
my $confirmation = $config[0]->[7] || "no";

$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{import_from_sheet_message}","$vars_file");


print <<EOF;

<script type="text/javascript">
<!--
function check_import_type(TYPE) {

        if ( TYPE == 'networks' ) {
		document.send_spreadsheet.action = "$server_proto://$base_uri/res/ip_import_spreadsheet_form1.cgi";
        } else if ( TYPE == 'hosts' ) {
		document.send_spreadsheet.action = "$server_proto://$base_uri/res/ip_import_host_spreadsheet_form1.cgi";
        } else if ( TYPE == 'vlans' ) {
		document.send_spreadsheet.action = "$server_proto://$base_uri/res/ip_import_vlans_spreadsheet_form1.cgi";
        }
}
-->
</script>

EOF

my $align="align=\"right\"";
my $align1="";
my $ori="left";
my $rtl_helper="<font color=\"white\">x</font>";
if ( $vars_file =~ /vars_he$/ ) {
	$align="align=\"left\"";
	$align1="align=\"right\"";
	$ori="right";
}



my $module = "Spreadsheet::ParseExcel";
my $module_check=$gip->check_module("$module") || "0";
$gip->print_error("$client_id","$$lang_vars{no_spreadsheet_support}") if $module_check != "1";

my $import_dir = getcwd;
$import_dir =~ s/res.*/import/;

print <<EOF;
<p>
<b style=\"float:$ori;\">$$lang_vars{step_one_message}</b>
<br><p>
<span style=\"float:$ori;\">
$$lang_vars{upload_spreadsheet_message}
</span>
<br><p>
<table border="0"><tr><td $align1>
$$lang_vars{redes1_message}<input type="radio" name="import_type" value="networks" onchange="check_import_type('networks');" checked>&nbsp;&nbsp;&nbsp;&nbsp;$$lang_vars{hosts1_message}<input type="radio" name="import_type" value="hosts" onchange="check_import_type('hosts');">&nbsp;&nbsp;&nbsp;&nbsp;$$lang_vars{vlans_message}<input type="radio" name="import_type" value="vlans" onchange="check_import_type('vlans');"> 
<font color=\"white\">x</font>
</td></tr>
<tr><td $align1>
<form id="send_spreadsheet" name="send_spreadsheet" action="$server_proto://$base_uri/res/ip_import_spreadsheet_form1.cgi" method="post" enctype="multipart/form-data">
<p><input type="hidden" name="client_id" value="$client_id"><input type="file" name="spreadsheet" style="margin: 1em;"></p>
</td></tr>
<tr><td $align1>
<input type="submit" name="Submit" value="$$lang_vars{upload_message}" class="input_link_w">
</td></tr></table>
</form>
</span>
EOF

$gip->print_end("$client_id");
