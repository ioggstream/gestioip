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
	$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{ipv6_address_plan_message}","$vars_file");
	$gip->print_error("$client_id","$$lang_vars{formato_malo_message}");
}

my @config = $gip->get_config("$client_id");
my $confirmation = $config[0]->[7] || "no";

$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{ipv6_address_plan_message}","$vars_file");

my $align="align=\"right\"";
my $align1="";
my $ori="left";
my $rtl_helper="<font color=\"white\">x</font>";
if ( $vars_file =~ /vars_he$/ ) {
	$align="align=\"left\"";
	$align1="align=\"right\"";
	$ori="right";
}

#my $import_dir = getcwd;
#$import_dir =~ s/res.*/import/;

print <<EOF;
<p>
<b style=\"float: $ori\">$$lang_vars{direct_translation_message}</b>
<br>
<br><p>

<form action="$server_proto://$base_uri/ip_migrate_to_v6_block_form1.cgi" method="post">
<table border="0" cellpadding="7">
<tr><td $align>$$lang_vars{from_address_block_message}</td>
<td $align1><input type="hidden" name="client_id" value="$client_id"><input type="text" name="base_net" size="45">&nbsp;&nbsp;<i>$$lang_vars{ip_address_block_example_message}</i></td></tr>
</table>
<p><span style=\"float: $ori\"><input type="submit" name="Submit" value="$$lang_vars{submit_message}" class="input_link_w"></span></p><br>
</form> 

<p><br><p><br><p>
<b style=\"float: $ori\">$$lang_vars{hierarchical_plan_message}</b><br>
<p><br>
<form action="$server_proto://$base_uri/ip_migrate_to_v6_hierarchical_form1.cgi" method="post">
<table border="0" cellpadding="7">
<td $align><input type="hidden" name="client_id" value="$client_id">$$lang_vars{ip_address_block_to_build_from_message}</td>
<td $align1><input type="text" name="base_net" size="45">&nbsp;&nbsp;<i>$$lang_vars{ip_address_block_example_message}</i></td></tr>
</table>
<p><span style=\"float: $ori\"><input type="submit" name="Submit" value="$$lang_vars{submit_message}" class="input_link_w"></span></p>
</form> 

EOF

$gip->print_end("$client_id");
