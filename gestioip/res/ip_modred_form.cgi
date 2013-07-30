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
use Net::IP;
use Net::IP qw(:PROC);

my $daten=<STDIN>;
my $gip = GestioIP -> new();
my %daten=$gip->preparer($daten);

my $base_uri = $gip->get_base_uri();
my $server_proto=$gip->get_server_proto();

my $lang = $daten{'lang'} || "";
my ($lang_vars,$vars_file)=$gip->get_lang("","$lang");

my $red_num = "";
$red_num=$daten{'red_num'} if $daten{'red_num'};
my $order_by=$daten{'order_by'} || "red_auf";


my $client_id = $daten{'client_id'} || $gip->get_first_client_id();
my $ip_version_ele = $daten{'ip_version_ele'} || $gip->get_ip_version_ele();

if ( $red_num !~ /^\d{1,5}$/ ) {
        $gip->print_init("gestioip","$$lang_vars{modificar_red_message}","$$lang_vars{modificar_red_message}","$vars_file","$client_id");
        $gip->print_error("$client_id",$$lang_vars{formato_red_malo_message}) ;
}

$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{modificar_red_message}","$vars_file");

$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (version_ele)") if $ip_version_ele !~ /^(v4|v6|46)$/ ;

my $start_entry=$daten{'start_entry'} || '0';
$gip->print_error("$client_id",$$lang_vars{formato_malo_message}) if $start_entry !~ /^\d{1,4}$/;

my $loc=$daten{'loc'} || "NULL";

my @values_redes = $gip->get_red("$client_id","$red_num");

my $red = "$values_redes[0]->[0]" || "";
my $BM = "$values_redes[0]->[1]" || "";
my $descr = "$values_redes[0]->[2]" || "";
$descr = "" if ( $descr eq "NULL" );
my $loc_val = $values_redes[0]->[3] || "-1";
my $vigilada = $values_redes[0]->[4] || "n";
my $comentario = $values_redes[0]->[5] || "";
my $cat_net = $values_redes[0]->[6] || "-1";
my $ip_version = $values_redes[0]->[7] || "";
$comentario = "" if ( $comentario eq "NULL" );
$red = ip_compress_address ($red, 6) if $ip_version eq "v6";

my $referer=$daten{'referer'} || "";
my ($bm_new);
if ( ! $referer ) {
	if ( $ENV{HTTP_REFERER} !~ /ip_modred_list/ ) {
		$referer="host_list_view";
	} else {
		$referer="red_view";
	}
}

$cat_net=$gip->get_cat_net_from_id("$client_id","$cat_net");
my @values_locations=$gip->get_loc("$client_id");
my @values_utype=$gip->get_utype();
my @values_cat_net=$gip->get_cat_net("$client_id");

my $color = "white";
print "<p>\n";
print "<form  method=\"POST\" action=\"$server_proto://$base_uri/res/ip_modred.cgi\">\n";
print "<table border=\"0\" cellpadding=\"1\">\n";
print "<tr><td><b>$$lang_vars{redes_message}</b></td><td><b>  BM</b></td><td><b>  $$lang_vars{description_message}</b></td><td><b>  $$lang_vars{loc_message}</b></td><td><b>$$lang_vars{cat_message}</b></td><td><b>$$lang_vars{comentario_message}</b></td><td><b>$$lang_vars{sinc_message}</b></td>\n";


print "<td></td></tr>\n";
print "<tr bgcolor=\"$color\" valign=\"top\"><td>$red</td><td><input type=\"text\" size=\"2\" name=\"BM_new\" value=\"$BM\" maxlength=\"3\"></td><td><i><input type=\"text\" size=\"25\" name=\"descr\" value=\"$descr\" maxlength=\"100\"></i></td><td><select name=\"loc\" size=\"1\">";
if ($loc eq "NULL" ) {
	print "<option></option>"; 
} else {
	print "<option>$loc</option>"; 
}
	
my $j=0;
foreach (@values_locations) {
	if ( $values_locations[$j]->[0] eq "NULL" && $loc ne "NULL") {
		$j++;
		next;
	}
        print "<option>$values_locations[$j]->[0]</option>" if ( $values_locations[$j]->[0] ne "$loc" );
        $j++;
}
print "</select>\n";
print "</td><td>";
print "<select name=\"cat_net\" size=\"1\">";
if ($cat_net eq "NULL" ) {
	print "<option></option>"; 
} else {
	print "<option>$cat_net</option>"; 
}
$j=0;
foreach (@values_cat_net) {
	if ( $values_cat_net[$j]->[0] eq "NULL" && $cat_net ne "NULL") {
		$j++;
		next;
	}
        print "<option>$values_cat_net[$j]->[0]</option>" if ( $values_cat_net[$j]->[0] ne "$cat_net" );
        $j++;
}

print "</select></td><input name=\"BM\" type=\"hidden\" value=\"$BM\"><input name=\"red\" type=\"hidden\" value=\"$red\"><input name=\"start_entry\" type=\"hidden\" value=\"$start_entry\"><input name=\"referer\" type=\"hidden\" value=\"$referer\"><input name=\"order_by\" type=\"hidden\" value=\"$order_by\">";
print "<td><textarea name=\"comentario\" cols=\"30\" rows=\"5\" wrap=\"physical\" maxlength=\"500\">$comentario</textarea>";
print "</td>";

my $vigilada_checked = "";
$vigilada_checked="checked" if ($vigilada eq "y" );
print "<td><input type=\"checkbox\" name=\"vigilada\" value=\"y\" $vigilada_checked></td></tr>\n";
print "</table>\n";


$gip->print_custom_net_colums_form("$client_id","$vars_file","$red_num");

print "<tr><td><p><br><input type=\"hidden\" name=\"red_num\" value=\"$red_num\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"hidden\" name=\"ip_version_ele\" value=\"$ip_version_ele\"><input type=\"submit\" value=\"$$lang_vars{cambiar_message}\" name=\"B1\" class=\"input_link_w_net\"></td><td></td></tr>\n";
print "</form>\n";
print "</table>\n";

$gip->print_end("$client_id","$vars_file");
