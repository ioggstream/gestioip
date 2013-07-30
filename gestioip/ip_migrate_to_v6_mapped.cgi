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


my @config = $gip->get_config("$client_id");
my $confirmation = $config[0]->[7] || "no";

$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{ipv6_address_plan_message}","$vars_file");


#my $import_dir = getcwd;
#$import_dir =~ s/res.*/import/;

print "<p><b>$$lang_vars{create_mapped_ipv6_message}</b><p><br>\n";

my @ip;
my $map_type="";
my $first_oct_match="";
my $second_oct_match="";
my $third_oct_match="";
my $match="";

$first_oct_match=$daten{first_oct} if $daten{first_oct};
$second_oct_match=$daten{second_oct} if $daten{second_oct};
$third_oct_match=$daten{third_oct} if $daten{third_oct};

$gip->print_error("$client_id","$$lang_vars{formato_octet_malo_message}") if (( $first_oct_match && $first_oct_match !~ /^\d{1,3}$/ ) || ( $second_oct_match && $second_oct_match !~ /^\d{1,3}$/ ) || ( $third_oct_match && $third_oct_match !~ /^\d{1,3}$/ ));

$match=$first_oct_match if $first_oct_match;
$match.="." . $second_oct_match if $second_oct_match;
$match.="." . $third_oct_match if $third_oct_match;


@ip=$gip->get_redes_mig("$client_id","$match","$map_type");

if ( ! $ip[0] ) {
	print "<p>$$lang_vars{no_matching_networks_message}<p><br><FORM><INPUT TYPE=\"BUTTON\" VALUE=\"$$lang_vars{atras_message}\" ONCLICK=\"history.go(-1)\" class=\"error_back_link\"></FORM><br>\n";
	$gip->print_end("$client_id");
}


my $i=0;
my ($first_oct,$second_oct,$third_oct,$fourth_oct,$first_oct_hex,$second_oct_hex,$third_oct_hex,$fourth_oct_hex,$replace_1,$replace_2,$replace_3,$replace_4,$replace_5,$replace_6,$replace_7,$replace_8);
print "<form name=\"ip_insert_v6_networks\" method=\"POST\" action=\"$server_proto://$base_uri/res/ip_migrate_to_v6_mapped_insertred.cgi\">\n";
print "<table border=\"0\" style=\"border-collapse:collapse\">\n";
print "<tr height=\"24px\"><td><b>$$lang_vars{ipv4_network_message}</b>&nbsp;&nbsp;&nbsp;</td><td><b>$$lang_vars{ipv4_mapped_ipv6_address_message}</b>&nbsp;&nbsp;&nbsp;</td><td width=\"30px\" align=\"center\"><b> BM </b></td><td><b> description</b></td><td align=\"center\"><b>$$lang_vars{loc_message}</b>&nbsp;&nbsp;&nbsp;</td><td align=\"center\"><b>$$lang_vars{cat_message}</b>&nbsp;&nbsp;&nbsp;</td><td><b> comment </b></td><td><b>sync</b>&nbsp;&nbsp;&nbsp;</td><td><b>$$lang_vars{create_message}</b></td><tr>\n";

my $BM6;
my %BM4_BM6=();
my $BM6_act=128;
for ( my $j = 32; $j > 0; $j-- ) {
	$BM4_BM6{$j}=$BM6_act;
	$BM6_act--;
}

my $color="white";
foreach my $ip (@ip) {

	if ( $color eq "white" ) {
		$color = "#f2f2f2";
	} else {
		$color = "white";
	}

	my $net4=$ip[$i]->[0];
	my $BM4=$ip[$i]->[1];
	my $descr=$ip[$i]->[2] || "";
	$descr="" if $descr eq "NULL";
	my $loc=$ip[$i]->[4] || "";
	$loc="" if $loc eq "NULL";

	my $comentario=$ip[$i]->[6] || "";
	$comentario="" if $comentario eq "NULL";
	$comentario.=" " if $comentario;
	my $cat=$ip[$i]->[7] || "";
	$cat="" if $cat eq "NULL";
	my $sinc=$ip[$i]->[8];
	my $loc_id=$ip[$i]->[9];
	my $cat_id=$ip[$i]->[10];

#	$BM6=$BM4_BM6{$BM4};
	$BM6=96;

	$net4 =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})/;
	$first_oct=$1;
	$second_oct=$2;
	$third_oct=$3;
	$fourth_oct=$4;
	$first_oct_hex = sprintf("%X", $first_oct);
	$second_oct_hex = sprintf("%X", $second_oct);
	$third_oct_hex = sprintf("%X", $third_oct);
	$fourth_oct_hex = sprintf("%X", $fourth_oct);
	$first_oct_hex=0 if $first_oct==0;
	$second_oct_hex=0 if $second_oct==0;
	$third_oct_hex=0 if $third_oct==0;
	$fourth_oct_hex=0 if $fourth_oct==0;
	$first_oct_hex="0" . $first_oct_hex if $first_oct_hex =~ /^.{1}$/;
	$second_oct_hex="0" . $second_oct_hex if $second_oct_hex =~ /^.{1}$/;
	$third_oct_hex="0" . $third_oct_hex if $third_oct_hex =~ /^.{1}$/;
	$fourth_oct_hex="0" . $fourth_oct_hex if $fourth_oct_hex =~ /^.{1}$/;
	my $ipv6_mapped="::FFFF:${first_oct_hex}${second_oct_hex}:${third_oct_hex}${fourth_oct_hex}";
	print "<tr bgcolor=\"$color\"><td>${net4}/${BM4}&nbsp;&nbsp;&nbsp;</td><td>$ipv6_mapped&nbsp;&nbsp;&nbsp;</td><td align=\"center\">$BM6</td><td><input type=\"text\" name=\"descr_${i}\" value=\"$descr\"></td><td align=\"center\">$loc</td><td align=\"center\">$cat</td><td><input type=\"text\" name=\"comentario_${i}\" value=\"${comentario}(::FFFF:${net4})\"></td><td align=\"center\"><select name=\"sinc_${i}\">\n";
	my $checked_yes="";
	my $checked_no="";
	if ( $sinc eq "y" ) {
		$checked_yes="selected";
	} else {
		$checked_no="selected";
	}
	print "<option value=\"y\" $checked_yes>yes</option>\n";
	print "<option value=\"n\" $checked_no>no</option>\n";
	print "</select></td>\n";
	print "<td align=\"center\"><input type=\"checkbox\" name=\"create_${i}\" value=\"create\" checked>\n";
	print "<input type=\"hidden\" name=\"red_${i}\" value=\"$ipv6_mapped\"><input type=\"hidden\" name=\"BM_${i}\" value=\"$BM6\"><input type=\"hidden\" name=\"loc_id_${i}\" value=\"$loc_id\"><input type=\"hidden\" name=\"cat_id_${i}\" value=\"$cat_id\"><input type=\"hidden\" name=\"loc_${i}\" value=\"$loc\"><input type=\"hidden\" name=\"cat_${i}\" value=\"$cat\">\n";
	print "</td></tr>\n";
	$i++;
}
print "<input type=\"hidden\" name=\"anz_redes\" value=\"$i\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"></table>\n";
print "<br><p>\n";
print "<input type=\"submit\" class=\"input_link_w\" value=\"$$lang_vars{create_message}\" style=\"cursor:pointer;\">\n";
print "</form>\n";

$gip->print_end("$client_id");
