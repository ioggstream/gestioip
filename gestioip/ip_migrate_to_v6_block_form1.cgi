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
use Net::IP;
use Net::IP qw(:PROC);

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

if ( ! $daten{'base_net'} ) {
	$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{ipv6_address_plan_message}","$vars_file");
	$gip->print_error("$client_id","$$lang_vars{introduce_base_net_message}");
}

$daten{'base_net'} =~ /^(.*)\/(\d{1,3})$/; 
my $base_net=$1 || "XXX";
my $BM6=$2;
$base_net =~ s/^\+//;

my $valid_v6 = $gip->check_valid_ipv6("$base_net") || "0";
if ( $valid_v6 != 1 || ! $base_net || ! $BM6 ) {
	$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{ipv6_address_plan_message}","$vars_file");
	$gip->print_error("$client_id","$$lang_vars{no_valid_ipv6_address_message}");
}


my @config = $gip->get_config("$client_id");
my $confirmation = $config[0]->[7] || "no";
my $anz_locs=$gip->count_locs("$client_id");
my $anz_cats=$gip->count_cats("$client_id");
$anz_cats--;

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


my $binmask_in= "";
for (my $i = 1; $i <= $BM6; $i++) {
	$binmask_in = $binmask_in . "1";
}
my $BM6_rest=128-$BM6;
for (my $i=1;$i<=$BM6_rest;$i++) {
	$binmask_in = $binmask_in . "0";
}
my $base_net_exp=ip_expand_address ($base_net,6);
my $base_net_int=$gip->ip_to_int("$client_id","$base_net_exp","v6");
my $bin = ip_inttobin ($base_net_int,6);
my $red_in_bin = $binmask_in & $bin;
my $red_in=ip_bintoip ($red_in_bin,6);


print "<p>\n";
if ( $vars_file =~ /vars_he$/ ) {
	print "<span style=\"float: $ori\">$rtl_helper(${base_net}/${BM6} $$lang_vars{ip_address_block_message} $$lang_vars{from_message}) <b>$$lang_vars{from_address_block_message}</b></span><br>\n";
} else {
	print "<b>$$lang_vars{from_address_block_message}</b> ($$lang_vars{from_message} $$lang_vars{ip_address_block_message} ${base_net}/${BM6})\n";
}
print "<p><br>\n";
if ( $BM6 <= 32 ) {
	print "<span style=\"float: $ori\">$$lang_vars{direct_translation_mapped_explic_message}$rtl_helper</span>\n";
	print "<p>\n";
	print "<form name=\"mig_form1\"action=\"$server_proto://$base_uri/ip_migrate_to_v6_block.cgi\" method=\"post\">\n";
	print "<p><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"hidden\" name=\"base_net\" value=\"$base_net/$BM6\"></p><br>\n";
	print "<table border=\"0\">\n";
	print "<tr><td><input type=\"radio\" name=\"map_type\" value=\"all\" onclick=\"first_octs_first.value=''; first_octs_first.disabled=true; first_two_octs_first.value=''; first_two_octs_second.value=''; first_three_octs_first.value=''; first_three_octs_second.value=''; first_three_octs_third.value=''; first_two_octs_first.disabled=true; first_two_octs_second.disabled=true; first_three_octs_first.disabled=true; first_three_octs_second.disabled=true; first_three_octs_third.disabled=true;\" checked></td><td $align1>$$lang_vars{map_all_message}</td><tr>\n";

	print "<tr><td><input type=\"radio\" name=\"map_type\" value=\"map_first_oct\" onclick=\"first_octs_first.disabled=false;first_two_octs_first.value=''; first_two_octs_second.value=''; first_three_octs_first.value=''; first_three_octs_second.value=''; first_three_octs_third.value=''; first_two_octs_first.disabled=true; first_two_octs_second.disabled=true; first_three_octs_first.disabled=true; first_three_octs_second.disabled=true; first_three_octs_third.disabled=true;\"></td><td $align1>$$lang_vars{map_first_oct_message}</td><td $align1><input type=\"text\" name=\"first_octs_first\" id=\"first_octs_first\" size=\"3\" disabled></td></tr>\n";

	print "<tr valign=\"top\"><td><input type=\"radio\" name=\"map_type\" value=\"first_two_octs\" onclick=\"first_octs_first.value=''; first_three_octs_first.value=''; first_three_octs_second.value=''; first_three_octs_third.value='';first_octs_first.disabled=true; first_two_octs_first.disabled=false; first_two_octs_second.disabled=false; first_three_octs_first.disabled=true; first_three_octs_second.disabled=true; first_three_octs_third.disabled=true;\"></td><td $align1>$$lang_vars{map_first_two_oct_message}</td><td $align1><input type=\"text\" name=\"first_two_octs_first\" id=\"first_two_octs_first\" size=\"3\" disabled></td><td colspan=\"2\" $align1><input type=\"text\" name=\"first_two_octs_second\" id=\"first_two_octs_second\" size=\"3\" disabled></td></tr>\n";

	print "<tr valign=\"top\"><td><input type=\"radio\" name=\"map_type\" value=\"first_three_octs\"  onclick=\"first_octs_first.value=''; first_two_octs_first.value=''; first_two_octs_second.value=''; first_octs_first.disabled=true; first_two_octs_first.disabled=true; first_two_octs_second.disabled=true; first_three_octs_first.disabled=false; first_three_octs_second.disabled=false; first_three_octs_third.disabled=false;\"></td><td $align1>$$lang_vars{map_first_three_oct_message}</td><td $align1><input type=\"text\" name=\"first_three_octs_first\" id=\"first_three_octs_first\" size=\"3\" disabled></td><td $align1><input type=\"text\" name=\"first_three_octs_second\" size=\"3\" disabled></td><td $align1><input type=\"text\" name=\"first_three_octs_third\" id=\"first_three_octs_third\" size=\"3\" disabled>&nbsp;&nbsp;</td></tr>\n";



} elsif ( $BM6 <= 40 ) {
	my $message="";
	if ( $vars_file =~ /vars_he$/ ) {
		print "<span style=\"float: $ori\">$$lang_vars{direct_translation_block_explic_message} /${BM6} $$lang_vars{direct_translation_block_explic1_message}$rtl_helper</span></br>\n";
	} else {
		print "<br>$$lang_vars{direct_translation_block_explic1_message} /${BM6} $$lang_vars{direct_translation_block_explic_message}\n";
	}
	print "<br>\n";
	print "<form name=\"mig_form2\"action=\"$server_proto://$base_uri/ip_migrate_to_v6_block.cgi\" method=\"post\">\n";
	print "<p><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"hidden\" name=\"base_net\" value=\"$base_net/$BM6\"></p><br>\n";
	print "<table border=\"0\">\n";
	print "<tr><td><input type=\"radio\" name=\"map_type\" value=\"map_first_oct\" onclick=\"first_octs_first.disabled=false;first_two_octs_first.value=''; first_two_octs_second.value=''; first_three_octs_first.value=''; first_three_octs_second.value=''; first_three_octs_third.value=''; first_two_octs_first.disabled=true; first_two_octs_second.disabled=true; first_three_octs_first.disabled=true; first_three_octs_second.disabled=true; first_three_octs_third.disabled=true;\" checked></td><td $align1>$$lang_vars{map_first_oct_message}</td><td $align1><input type=\"text\" name=\"first_octs_first\" id=\"first_octs_first\" size=\"3\"></td></tr>\n";

	print "<tr valign=\"top\"><td><input type=\"radio\" name=\"map_type\" value=\"first_two_octs\" onclick=\"first_octs_first.value=''; first_three_octs_first.value=''; first_three_octs_second.value=''; first_three_octs_third.value='';first_octs_first.disabled=true; first_two_octs_first.disabled=false; first_two_octs_second.disabled=false; first_three_octs_first.disabled=true; first_three_octs_second.disabled=true; first_three_octs_third.disabled=true;\"></td><td $align1>$$lang_vars{map_first_two_oct_message}</td><td $align1><input type=\"text\" name=\"first_two_octs_first\" id=\"first_two_octs_first\" size=\"3\" disabled></td><td colspan=\"2\" $align1><input type=\"text\" name=\"first_two_octs_second\" id=\"first_two_octs_second\" size=\"3\" disabled></td></tr>\n";

	print "<tr valign=\"top\"><td><input type=\"radio\" name=\"map_type\" value=\"first_three_octs\"  onclick=\"first_octs_first.value=''; first_two_octs_first.value=''; first_two_octs_second.value=''; first_octs_first.disabled=true; first_two_octs_first.disabled=true; first_two_octs_second.disabled=true; first_three_octs_first.disabled=false; first_three_octs_second.disabled=false; first_three_octs_third.disabled=false;\"></td><td $align1>$$lang_vars{map_first_three_oct_message}</td><td $align1><input type=\"text\" name=\"first_three_octs_first\" id=\"first_three_octs_first\" size=\"3\" disabled></td><td $align1><input type=\"text\" name=\"first_three_octs_second\" size=\"3\" disabled></td><td $align1><input type=\"text\" name=\"first_three_octs_third\" id=\"first_three_octs_third\" size=\"3\" disabled>&nbsp;&nbsp;</td></tr>\n";


} elsif ( $BM6 <= 48 ) {
	if ( $vars_file =~ /vars_he$/ ) {
		print "<span style=\"float: left\">$$lang_vars{direct_translation_block_explic_message} /${BM6} $$lang_vars{direct_translation_block_explic1_message}</span>\n";
	} else {
		print "$$lang_vars{direct_translation_block_explic1_message} /${BM6} $$lang_vars{direct_translation_block_explic_message}\n";
	}
	print "<br>\n";
	print "<br><form name=\"mig_form\"action=\"$server_proto://$base_uri/ip_migrate_to_v6_block.cgi\" method=\"post\">\n";
	print "<p><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"hidden\" name=\"base_net\" value=\"$base_net/$BM6\"></p><br>\n";
	print "<table border=\"0\" cellspacing=\"5\">\n";

	print "<tr valign=\"top\"><td><input type=\"radio\" name=\"map_type\" value=\"first_two_octs\" onclick=\" first_three_octs_first.value=''; first_three_octs_second.value=''; first_three_octs_third.value='';first_two_octs_first.disabled=false; first_two_octs_second.disabled=false; first_three_octs_first.disabled=true; first_three_octs_second.disabled=true; first_three_octs_third.disabled=true;\" checked></td><td $align1>$$lang_vars{map_first_two_oct_message}</td><td $align1><input type=\"text\" name=\"first_two_octs_first\" id=\"first_two_octs_first\" size=\"3\"></td><td colspan=\"2\" $align1><input type=\"text\" name=\"first_two_octs_second\" id=\"first_two_octs_second\" size=\"3\"></td></tr>\n";

	print "<tr valign=\"top\"><td><input type=\"radio\" name=\"map_type\" value=\"first_three_octs\"  onclick=\"first_two_octs_first.value=''; first_two_octs_second.value=''; first_two_octs_first.disabled=true; first_two_octs_second.disabled=true; first_three_octs_first.disabled=false; first_three_octs_second.disabled=false; first_three_octs_third.disabled=false;\"></td><td>$$lang_vars{map_first_three_oct_message}</td><td><input type=\"text\" name=\"first_three_octs_first\" id=\"first_three_octs_first\" size=\"3\" disabled></td><td><input type=\"text\" name=\"first_three_octs_second\" size=\"3\" disabled></td><td><input type=\"text\" name=\"first_three_octs_third\" id=\"first_three_octs_third\" size=\"3\" disabled>&nbsp;&nbsp;</td></tr>\n";

} elsif ( $BM6 > 48  ) {
	$gip->print_error("$client_id","$$lang_vars{no_prefix_length_49_allowed}");
}

print "</table>\n";
print "<br><p>\n";
print "<p><span style=\"float: $ori\"><input type=\"submit\" name=\"Submit\" value=\"$$lang_vars{submit_message}\" class=\"input_link_w\"></span></p>\n";
print "</form>\n";


$gip->print_end("$client_id");
