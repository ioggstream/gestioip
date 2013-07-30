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


$daten{'base_net'} =~ /^(.*)\/(\d{1,3})$/; 
my $base_net=$1;
my $BM6=$2;
my $valid_v6 = $gip->check_valid_ipv6("$base_net") || "0";
if ( $valid_v6 != 1 ) {
	$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{ipv6_address_plan_message}","$vars_file");
	$gip->print_error("$client_id","$$lang_vars{no_valid_ipv6_address_message} (0)");
}

if ( ! $daten{'base_net'} ) {
	$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{ipv6_address_plan_message}","$vars_file");
	$gip->print_error("$client_id","$$lang_vars{no_valid_ipv6_address_message} (1)");
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


print <<EOF;
<script type="text/javascript">
function OnSubmitForm()
{
  if(document.pressed == '$$lang_vars{export_message}')
  {
    document.ip_insert_v6_networks.action ="$server_proto://$base_uri/res/ip_export_address_plan.cgi";
  }
  else
  if(document.pressed == '$$lang_vars{create_message}')
  {
    document.ip_insert_v6_networks.action ="$server_proto://$base_uri/res/ip_migrate_to_v6_mapped_insertred.cgi";
  }
  return true;
}
</script>
EOF


#my $import_dir = getcwd;
#$import_dir =~ s/res.*/import/;

#print "<p>\n";
#print "<b>$$lang_vars{from_address_block_message}</b> ($$lang_vars{from_message} $$lang_vars{ip_address_block_message} ${base_net}/${BM6})\n";
#print "<p><br>\n";

print "<p>\n";
if ( $vars_file =~ /vars_he$/ ) {
	print "<span style=\"float: $ori\">$rtl_helper(${base_net}/${BM6} $$lang_vars{ip_address_block_message} $$lang_vars{from_message}) <b>$$lang_vars{from_address_block_message}</b></span><br>\n";
} else {
	print "<b>$$lang_vars{from_address_block_message}</b> ($$lang_vars{from_message} $$lang_vars{ip_address_block_message} ${base_net}/${BM6})\n";
}
print "<p><br>\n";



my $red_exp= ip_expand_address ($base_net,6);
my $nibbles_pre=$red_exp;
$nibbles_pre =~ s/://g;
my @nibbles=split(//,$nibbles_pre);
my @nibbles_reverse=reverse @nibbles;
my @ip;
my $map_type=$daten{map_type} || "";
my $first_oct_match="";
my $second_oct_match="";
my $third_oct_match="";
my $match="";

#if ( $map_type eq "first_two_octs" || $map_type eq "first_three_octs" ) { 
$first_oct_match=$daten{first_octs_first} if defined($daten{first_octs_first});
$first_oct_match=$daten{first_oct_match} if defined($daten{first_oct_match});
$first_oct_match=$daten{first_oct_match_3_octs} if defined($daten{first_oct_match_3_octs});
$first_oct_match=$daten{first_two_octs_first} if defined($daten{first_two_octs_first});
$second_oct_match=$daten{first_two_octs_second} if defined($daten{first_two_octs_second});
$second_oct_match=$daten{second_oct_match} if defined($daten{second_oct_match});
$second_oct_match=$daten{second_oct_match_3_octs} if defined($daten{second_oct_match_3_octs});
$first_oct_match=$daten{first_three_octs_first} if defined($daten{first_three_octs_first});
$second_oct_match=$daten{first_three_octs_second} if defined($daten{first_three_octs_second});
$third_oct_match=$daten{first_three_octs_third} if defined($daten{first_three_octs_third});
$third_oct_match=$daten{third_oct_match} if defined($daten{third_oct_match});


$match=$first_oct_match if $first_oct_match;
$match.="." . $second_oct_match if $second_oct_match || $second_oct_match eq "0";
$match.="." . $third_oct_match if $third_oct_match || $third_oct_match  eq "0";

$gip->print_error("$client_id","$$lang_vars{all_octet_fields_message}") if (( $map_type eq "map_first_oct" && ! defined($first_oct_match) ) || ( $map_type eq "first_two_octs" && ( ! $first_oct_match || ! defined($second_oct_match) )) || ( $map_type eq "first_three_ocs" && ( ! $first_oct_match || ! $second_oct_match || ! $third_oct_match)));
$gip->print_error("$client_id","$$lang_vars{formato_octet_malo_message}$rtl_helper") if (( $map_type eq "map_first_oct" && $first_oct_match !~ /^\d{1,3}$/ ) || ( $map_type eq "first_two_octs" && ( $first_oct_match !~ /^\d{1,3}$/ || $second_oct_match !~ /^\d{1,3}$/ )) || ( $map_type eq "first_three_octs" && ( $first_oct_match !~ /^\d{1,3}$/ || $second_oct_match !~ /^\d{1,3}$/ || $third_oct_match !~ /^\d{1,3}$/ )));

@ip=$gip->get_redes_mig("$client_id","$match","$map_type","$BM6");

if ( ! $ip[0] ) {
	print "<p>$$lang_vars{no_matching_networks_message}<p><br><FORM><INPUT TYPE=\"BUTTON\" VALUE=\"$$lang_vars{atras_message}\" ONCLICK=\"history.go(-1)\" class=\"error_back_link\"></FORM><br>\n";
	$gip->print_end("$client_id");
}


my $i=0;
my ($first_oct,$second_oct,$third_oct,$fourth_oct,$first_oct_hex,$second_oct_hex,$third_oct_hex,$fourth_oct_hex,$replace_1,$replace_2,$replace_3,$replace_4,$replace_5,$replace_6,$replace_7,$replace_8);
#print "<form name=\"ip_insert_v6_networks\" method=\"POST\" action=\"$server_proto://$base_uri/res/ip_migrate_to_v6_mapped_insertred.cgi\">\n";
print "<form name=\"ip_insert_v6_networks\" method=\"POST\" onsubmit=\"return OnSubmitForm();\">\n";
print "<table border=\"0\" style=\"border-collapse:collapse\">\n";
print "<tr height=\"24px\"><td><b>$$lang_vars{ipv4_network_message}</b>&nbsp;&nbsp;&nbsp;</td><td><b>$$lang_vars{translated_ipv6_address_message}</b>&nbsp;&nbsp;&nbsp;</td><td width=\"30px\" align=\"center\"><b> $$lang_vars{prefix_length_message}&nbsp;&nbsp; </b></td><td><b> $$lang_vars{description_message}</b></td><td align=\"center\"><b>$$lang_vars{loc_message}</b>&nbsp;&nbsp;&nbsp;</td><td align=\"center\"><b>$$lang_vars{cat_message}</b>&nbsp;&nbsp;&nbsp;</td><td><b> $$lang_vars{comentario_message} </b></td><td><b>sync</b>&nbsp;&nbsp;&nbsp;</td><td><b>$$lang_vars{create_message}</b></td></tr>\n";
my $BM6_new="64";
my $color="white";

foreach my $ip (@ip) {
	my $net4=$ip[$i]->[0];
	my $BM4=$ip[$i]->[1];

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
	my $replace_rounds;
	if ( $BM6 <= 40 ) {
		$gip->print_error("$client_id","$$lang_vars{formato_octet_malo_message}") if ( ! $first_oct_match && ! $second_oct_match && ! $third_oct_match ) && $BM6 > 35;
		$gip->print_error("$client_id","$$lang_vars{formato_octet_malo_message}") if (( $first_oct_match && $first_oct_match !~ /^\d{1,3}$/ ) || ( $second_oct_match && $second_oct_match !~ /^\d{1,3}$/ ) || ( $third_oct_match && $third_oct_match !~ /^\d{1,3}$/ ));

		$replace_1=$first_oct_hex;
		$replace_3=$second_oct_hex;
		$replace_5=$third_oct_hex;
		$replace_7=$fourth_oct_hex;
		$replace_rounds=8;
		if ( $first_oct_match && ! $second_oct_match ) {
			$replace_1=$second_oct_hex;
			$replace_3=$third_oct_hex;
			$replace_5=$fourth_oct_hex;
			$replace_rounds=6;
		} elsif ( $second_oct_match && ! $third_oct_match ) {
			$replace_1=$third_oct_hex;
			$replace_3=$fourth_oct_hex;
			$replace_rounds=4;
		} elsif ( $third_oct_match ) {
			$replace_1=$fourth_oct_hex;
			$replace_rounds=2;
		}

		$replace_1 =~ /^(\w)(\w)$/;
		$replace_1=$1;
		$replace_2=$2;
		$replace_3 =~ /^(\w)(\w)$/;
		$replace_3=$1;
		$replace_4=$2;
		$replace_5 =~ /^(\w)(\w)$/;
		$replace_5=$1;
		$replace_6=$2;
		$replace_7 =~ /^(\w)(\w)$/;
		$replace_7=$1;
		$replace_8=$2;


	} elsif ( $BM6 > 40 && $BM6 <= 48 ) {
	## 44-51
		if ( $map_type eq "first_two_octs" ) {
			$replace_1=$third_oct_hex;
			$replace_3=$fourth_oct_hex;
			$replace_rounds=4;
		} elsif ( $map_type eq "first_three_octs" ) {
			$replace_1=$fourth_oct_hex;
			$replace_rounds=2;
		}
		$replace_1 =~ /^(\w)(\w)$/;
		$replace_1=$1;
		$replace_2=$2;
		if ( $map_type eq "first_two_octs" ) {
			$replace_3 =~ /^(\w)(\w)$/;
			$replace_3=$1;
			$replace_4=$2;
		}
	} else {
		$replace_1=$fourth_oct_hex;
		$replace_1 =~ /^(\w)(\w)$/;
		$replace_1=$1;
		$replace_2=$2;
		$replace_rounds=2;
	}

	my $red_part_helper1 = ($BM6-1)/4;
	my $bc="1";
	if ( $red_part_helper1 =~ /\./ ) {
		$red_part_helper1 =~ /\d\.(\d)/;
		$bc=$1;
	}

	$red_part_helper1 =~ s/\.\d*//;
	$red_part_helper1++ if $bc > 5;
	$red_exp="";
	my $j=0;
	my $k=1;
	foreach my $nib (@nibbles ) {
		if ( $j == 4 || $j==8 || $j==12 || $j==16 || $j==20 || $j==24 || $j==28 ) {
			$red_exp .= ":";
		}
		if ( $j>=$red_part_helper1 && $k <= $replace_rounds ) {
			$red_exp .= "${replace_1}" if $k == 1;
			$red_exp .= "${replace_2}" if $k == 2;
			$red_exp .= "${replace_3}" if $k == 3;
			$red_exp .= "${replace_4}" if $k == 4;
			$red_exp .= "${replace_5}" if $k == 5;
			$red_exp .= "${replace_6}" if $k == 6;
			$red_exp .= "${replace_7}" if $k == 7;
			$red_exp .= "${replace_8}" if $k == 8;
			$k++;
		} else {
			$red_exp .= $nib;
		}
		$j++;
	}

	my $red_exp_comp=ip_compress_address ($red_exp, 6);

	if ( $color eq "white" ) {
		$color = "#f2f2f2";
	} else {
		$color = "white";
	}

	my $descr=$ip[$i]->[2];
	$descr="" if $descr eq "NULL";
	my $loc=$ip[$i]->[4];
	$loc="" if $loc eq "NULL";

	my $comentario=$ip[$i]->[6];
	$comentario="" if $comentario eq "NULL";
	$comentario.=" " if $comentario;
	my $cat=$ip[$i]->[7];
	$cat="" if $cat eq "NULL";
	my $sinc=$ip[$i]->[8];
	my $loc_id=$ip[$i]->[9];
	my $cat_id=$ip[$i]->[10];


	print "<tr bgcolor=\"$color\"><td>$net4/$BM4&nbsp;&nbsp;&nbsp;</td><td>$red_exp_comp&nbsp;&nbsp;&nbsp;</td><td align=\"center\">$BM6_new</td><td><input type=\"text\" name=\"descr_${i}\" value=\"$descr\"></td><td align=\"center\">$loc</td><td align=\"center\">$cat</td><td><input type=\"text\" name=\"comentario_${i}\" value=\"${comentario}(${net4})\"></td><td align=\"center\"><select name=\"sinc_${i}\">\n";
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
	print "<input type=\"hidden\" name=\"red_${i}\" value=\"$red_exp\"><input type=\"hidden\" name=\"BM_${i}\" value=\"$BM6_new\"><input type=\"hidden\" name=\"loc_id_${i}\" value=\"$loc_id\"><input type=\"hidden\" name=\"cat_id_${i}\" value=\"$cat_id\"><input type=\"hidden\" name=\"loc_${i}\" value=\"$loc\"><input type=\"hidden\" name=\"cat_${i}\" value=\"$cat\"><input type=\"hidden\" name=\"red4_${i}\" value=\"$net4\"><input type=\"hidden\" name=\"BM4_${i}\" value=\"$BM4\">\n";
print "</td></tr>\n";


#	print "<tr><td>$ip[$i]->[0]/$ip[$i]->[1]</td><td>${red_exp_comp}/64</td></tr>\n";

	$i++;
}
#$i--;
print "<input type=\"hidden\" name=\"anz_redes\" value=\"$i\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"></table>\n";
print "</table><br><p>\n";
print "<span style=\"float: $ori\"><input type=\"submit\" class=\"input_link_w\" value=\"$$lang_vars{create_message}\" style=\"cursor:pointer;\" onClick=\"document.pressed=this.value\" VALUE=\"insert\"></span>\n";
print "<span style=\"float: $ori\"><input type=\"submit\" title=\"$$lang_vars{export_network_list_message}\" class=\"input_link_w\" value=\"$$lang_vars{export_message}\" style=\"cursor:pointer;\" onClick=\"document.pressed=this.value\" VALUE=\"export\"></span>\n";
print "</form>\n";


$gip->print_end("$client_id");
