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


my $client_id = $daten{'client_id'} || "";
if ( $client_id !~ /^\d{1,4}$/ ) {
	$client_id = 1;
	$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{ipv6_address_plan_message}","$vars_file");
	$gip->print_error("$client_id","$$lang_vars{formato_malo_message}");
}

my $carry_over=$daten{carry_over} || "";
my $independent_anz=$daten{independent_anz} || "";
my $assign_hex=$daten{assign_hex} || "";
my $future_locs=$daten{'future_locs'} || "";
my $future_cats=$daten{'future_cats'} || "";
my $anz_locs=$daten{'anz_locs'} || "";
my $anz_cats=$daten{'anz_cats'} || "";
my $max_loc_nets=$daten{'max_loc_nets'} || "0";
my $max_cat_nets=$daten{'max_cat_nets'} || "0";
my $BM_l2=$daten{'BM_l2'} || "";
my $BM_l2_anz=$daten{'BM_l2_anz'} || "";
my $BM_l3=$daten{'BM_l3'} || "";
my $BM_l3_anz=$daten{'BM_l3_anz'} || "";
my $BM_l4=$daten{'BM_l4'} || "";
my $BM_l4_anz=$daten{'BM_l4_anz'} || "";
my $algorithm=$daten{'algorithm'};
if ( $algorithm !~ /(leftmost|centermost|rightmost)/ ) {
	$gip->CheckInput("$client_id",\%daten,"$$lang_vars{formato_malo_message}","$$lang_vars{ipv6_address_plan_message}","$vars_file");
	$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (1)");
}

#my %loc_cat_hex_combi;
#foreach my $loc ( @values_locations ) {
#        next if $loc->[0] eq "NULL";
#        foreach my $cat ( @values_categorias ) {
#                next if $cat->[0] eq "NULL";
#                my $loc_cat_hex_combi{$loc->[0]_$cat->[0]}=$daten{$loc->[0]_$cat->[0]} || "";
#        }
#}


$daten{'base_net'} =~ /^(.*)\/(\d{1,3})$/; 
my $base_net=$1;
my $BM6=$2;
my $valid_v6 = $gip->check_valid_ipv6("$base_net") || "0";
if ( $valid_v6 != 1 ) {
	$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{ipv6_address_plan_message}","$vars_file");
	$gip->print_error("$client_id","$$lang_vars{no_valid_ipv6_address_message}");
}

if ( ! $daten{'base_net'} ) {
	$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{ipv6_address_plan_message}","$vars_file");
	$gip->print_error("$client_id","$$lang_vars{no_valid_ipv6_address_message}");
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
    document.mig_hira_form.action ="$server_proto://$base_uri/res/ip_export_hierarchial_address_plan.cgi";
  }
  else
  if(document.pressed == '$$lang_vars{create_message}')
  {
    document.mig_hira_form.action ="$server_proto://$base_uri/res/ip_migrate_to_v6_hierarchical_insertred.cgi";
  }
  return true;
}
</script>
EOF



my @stat_net_cats4 = $gip->get_stat_net_cats("$client_id","v4");
my @stat_net_locs4 = $gip->get_stat_net_locs("$client_id","v4");
my @values_categorias=$gip->get_cat_net("$client_id");
my @values_locations=$gip->get_loc("$client_id");
my %bm = $gip->get_anz_hosts_bm_hash("$client_id","v6");
my $site_cat_counts=$gip->count_site_cats_nets("$client_id",\@values_categorias,\@values_locations);

my %loc_cat_anz;
my $j=0;
if ( $carry_over ) {
	for ( my $i=0; $i<=$anz_locs; $i++ ) {
		my $loc=$values_locations[$i];
		if ( $loc->[0] ) {
			next if $loc->[0] eq "NULL";
		} else {
			next;
		}
		foreach my $cat (@values_categorias ) {
			next if $cat->[0] eq "NULL";
			$loc_cat_anz{"$loc->[0]_$cat->[0]"}=$daten{"cat_loc_anz_${i}_${j}"};
			$j++;
		}
	}
}




print "<p><br>\n";
print "<span style=\"float: $ori\"><b>$$lang_vars{hierarchical_plan_message}</b></span> <span style=\"float: $ori\">&nbsp;&nbsp;($$lang_vars{ip_address_block_message} $base_net/$BM6)</span><br>\n";


my @ip=();
if ( $carry_over ) {
	@ip=$gip->get_redes_mig("$client_id","","");
}


my $redob_in = $base_net . "/" . $BM_l2;
my $ipob_red_in = new Net::IP ($redob_in) or die "Can not create IP object: $!\n";
my $last_ip_int = ($ipob_red_in->last_int());
$last_ip_int = Math::BigInt->new("$last_ip_int");
my $redint=($ipob_red_in->intip());
$redint = Math::BigInt->new("$redint");
my $anz_L2=$last_ip_int-$redint;;
$anz_L2 = Math::BigInt->new("$anz_L2");
my $i;
my $nextred_int=$redint;
my $nextred=$base_net;
my $nextred_exp=ip_expand_address ($base_net,6);

my $cat_hash=$gip->get_net_cat_hash("$client_id");
my $loc_hash=$gip->get_loc_hash("$client_id");

my $k=0;
my ($i_end,$j_end,$m_end);
if ( $independent_anz ) {
#	$i_end=$max_loc_nets;
	$i_end=$anz_locs-1;
	$j_end=$max_cat_nets;
} else {
	$i_end=$anz_locs-1;
	$j_end=$anz_cats-1;
}

#print "<form name=\"mig_hira_form\" id=\"mig_hira_form\" method=\"POST\" action=\"$server_proto://$base_uri/res/ip_migrate_to_v6_hierarchical_insertred.cgi\" style=\"display:inline\">\n";
print "<form name=\"mig_hira_form\" id=\"mig_hira_form\" method=\"POST\" onsubmit=\"return OnSubmitForm();\">\n";
for ( $i=0; $i<=$i_end; $i++ ) {

	if ( $i != 0 ) {
		$nextred_int+=$anz_L2+1;
		$nextred = $gip->int_to_ip("$client_id","$nextred_int","v6");
		$nextred_exp=ip_expand_address ($nextred,6);
	}

	my $loc=$values_locations[$k];
#	next if $loc->[0] eq "NULL";
	$loc->[0] = "NULL" if ! $loc->[0];
	if ( $loc->[0] eq "NULL" ) {
		$k++;
		next;
	}
	print "<p><br><p><h2 $align1>$loc->[0]</h2>\n";
	my $redob_in_3 = $nextred . "/" . $BM_l3;
	my $ipob_red_in_3 = new Net::IP ($redob_in_3) or die "Can not create IP object: $!\n";
	my $last_ip_int_3 = ($ipob_red_in_3->last_int());
	$last_ip_int_3 = Math::BigInt->new("$last_ip_int_3");
	my $redint_3=($ipob_red_in_3->intip());
	$redint_3 = Math::BigInt->new("$redint_3");
	my $anz_L3=$last_ip_int_3-$redint_3;
	$anz_L3 = Math::BigInt->new("$anz_L3");
	my $j;

	my $nextred_int_3=$redint_3;
	my $nextred_3 = $gip->int_to_ip("$client_id","$nextred_int_3","v6");

	print "<table border=\"0\" style=\"border-collapse:collapse\">\n";
	print "<tr height=\"24px\"><td><b>$$lang_vars{ip_address_message}</b>&nbsp;&nbsp;&nbsp;</td><td width=\"30px\" align=\"center\"><b> $$lang_vars{prefix_length_message} </b></td><td>&nbsp;&nbsp;<b> $$lang_vars{description_message}</b></td><td align=\"center\"><b>$$lang_vars{loc_message}</b>&nbsp;&nbsp;&nbsp;</td><td align=\"center\"><b>$$lang_vars{cat_message}</b>&nbsp;&nbsp;&nbsp;</td><td><b> $$lang_vars{comentario_message} </b></td><td><b>sync</b>&nbsp;&nbsp;&nbsp;</td><td><b>$$lang_vars{create_message}</b></td><td></td></tr>\n";

	print "<tr bgcolor=\"#E59900\"><td>$nextred_exp</td><td align=\"center\">$BM_l2</td><td><input type=\"text\" name=\"descr_l2_${i}\" value=\"\"></td><td align=\"center\">$loc->[0]</td><td align=\"center\">---</td><td><input type=\"text\" name=\"comentario_l2_${i}\" value=\"\"></td><td align=\"center\">---</td>\n";
	print "<td align=\"center\"><input type=\"checkbox\" name=\"create_l2_${i}\" value=\"create\" checked>\n";
	print "<input type=\"hidden\" name=\"red_l2_${i}\" value=\"$nextred_exp\"><input type=\"hidden\" name=\"BM_l2_${i}\" value=\"$BM_l2\"><input type=\"hidden\" name=\"loc_id_l2_${i}\" value=\"$loc_hash->{$loc->[0]}\"><input type=\"hidden\" name=\"cat_id_l2_${i}\" value=\"-1\"><input type=\"hidden\" name=\"loc_l2_${i}\" value=\"$loc->[0]\"><input type=\"hidden\" name=\"cat_l2_${i}\" value=\"\"></td><td><input type=\"button\" name=\"clear_button_l2_${i}\" value=\"\" class=\"reset_text_field_button\" onClick=\"descr_l2_${i}.value='';comentario_l2_${i}.value='';\"></td></tr>\n";
	print "</table>\n";


	$nextred_int+=$anz_L2+1; 
	$nextred = $gip->int_to_ip("$client_id","$nextred_int","v6");

	my $l=0;
	for ( $j=0; $j<=$j_end; $j++ ) {
		my $cat=$values_categorias[$l];
		last if $l >= scalar(@values_categorias); 
		if ( $cat->[0] eq "NULL" ) {
			$l++;
			next;
		}

		if ( $vars_file =~ /vars_he$/ ) {
			print "<p><h3 $align1>&nbsp;&nbsp;&nbsp;&nbsp;$cat->[0] - $loc->[0]</h3>\n";
		} else {
			print "<p><h3>&nbsp;&nbsp;&nbsp;&nbsp;$loc->[0] - $cat->[0]</h3>\n";
		}

		print "<table border=\"0\" style=\"border-collapse:collapse\">\n";
		print "<tr height=\"24px\"><td>&nbsp;&nbsp;&nbsp;&nbsp;</td><td><b>$$lang_vars{ip_address_message}</b>&nbsp;&nbsp;&nbsp;</td><td width=\"30px\" align=\"center\"><b> $$lang_vars{prefix_length_message} </b></td><td>&nbsp;&nbsp;<b> $$lang_vars{description_message}</b></td><td align=\"center\"><b>$$lang_vars{loc_message}</b>&nbsp;&nbsp;&nbsp;</td><td align=\"center\"><b>$$lang_vars{cat_message}</b>&nbsp;&nbsp;&nbsp;</td><td><b> $$lang_vars{comentario_message} </b></td><td><b>sync</b>&nbsp;&nbsp;&nbsp;</td><td><b>$$lang_vars{create_message}</b></td></tr>\n";

#		print "<tr bgcolor=\"#E59900\"><td bgcolor=\"white\">&nbsp;&nbsp;&nbsp;&nbsp;</td><td>$nextred_3</td><td align=\"center\">$BM_l3</td><td><input type=\"text\" name=\"descr_l3_${i}_${j}\" value=\"\"></td><td align=\"center\">$loc->[0]</td><td align=\"center\">---</td><td><input type=\"text\" name=\"comentario_l3_${i}_${j}\" value=\"\"></td><td align=\"center\">---</td>\n";
		print "<tr bgcolor=\"#E59900\"><td bgcolor=\"white\">&nbsp;&nbsp;&nbsp;&nbsp;</td><td>$nextred_3</td><td align=\"center\">$BM_l3</td><td><input type=\"text\" name=\"descr_l3_${i}_${j}\" value=\"\"></td><td align=\"center\">$loc->[0]</td><td align=\"center\">$cat->[0]</td><td><input type=\"text\" name=\"comentario_l3_${i}_${j}\" value=\"\"></td><td align=\"center\">---</td>\n";
		print "<td align=\"center\"><input type=\"checkbox\" name=\"create_l3_${i}_${j}\" value=\"create\" checked>\n";
		print "<input type=\"hidden\" name=\"red_l3_${i}_${j}\" value=\"$nextred_3\"><input type=\"hidden\" name=\"BM_l3_${i}_${j}\" value=\"$BM_l3\"><input type=\"hidden\" name=\"loc_id_l3_${i}_${j}\" value=\"$loc_hash->{$loc->[0]}\"><input type=\"hidden\" name=\"cat_id_l3_${i}_${j}\" value=\"$cat_hash->{$cat->[0]}\"><input type=\"hidden\" name=\"loc_l3_${i}_${j}\" value=\"$loc->[0]\"><input type=\"hidden\" name=\"cat_l3_${i}_${j}\" value=\"$cat->[0]\"></td><td><input type=\"button\" name=\"clear_button_l3_${i}_${i}\" value=\"\" class=\"reset_text_field_button\" onClick=\"descr_l3_${i}_${j}.value='';comentario_l3_${i}_${j}.value='';\"></td></tr>\n";
		print "</table>\n";

		my $redob_in_4 = $nextred_3 . "/64";

		$nextred_int_3+=$anz_L3+1; 
		$nextred_3 = $gip->int_to_ip("$client_id","$nextred_int_3","v6");

		my $ipob_red_in_4 = new Net::IP ($redob_in_4) or die "Can not create IP object: $!\n";
		my $last_ip_int_4 = ($ipob_red_in_4->last_int());
		$last_ip_int_4 = Math::BigInt->new("$last_ip_int_4");
		my $redint_4=($ipob_red_in_4->intip());
		$redint_4 = Math::BigInt->new("$redint_4");
		my $anz_L4=$last_ip_int_4-$redint_4;
		$anz_L4 = Math::BigInt->new("$anz_L4");
		my $nextred_int_4=$redint_4;
		my $nextred_4 = $gip->int_to_ip("$client_id","$nextred_int_4","v6");
		
		if ( ${$site_cat_counts}{"$loc->[0]_$cat->[0]"}->[0]==0 && ! $independent_anz ) {
			print "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; <i>$$lang_vars{no_networks_message}</i><br>\n";
			$l++;
			next;
		}

		my @ip_cat_loc=();
		my $n=0;
		my $o=0;
		foreach my $ip (@ip) {
			if ( ! $ip[$o]->[0] ) {
				$n++;
				$o++;
				next;
			}
			my $checkloc=$ip[$o]->[4] || "";
			my $checkcat=$ip[$o]->[7] || "";
			if ( $checkloc eq $loc->[0] && $checkcat eq $cat->[0] ) {
				$ip_cat_loc[$n]=$ip;
				$n++;
			}
			$o++;
		}

		print "<p>\n";
		print "<table border=\"0\" style=\"border-collapse:collapse\">\n";
		my $color="white";

		if ( $independent_anz ) {
#			$m_end=$max_cat_nets;
			$m_end=$loc_cat_anz{"$loc->[0]_$cat->[0]"} || "0";
		} else {
			$m_end=${$site_cat_counts}{"$loc->[0]_$cat->[0]"}->[0] || "0";
		}

		if ( $m_end > 0 ) {
			print "<tr height=\"24px\"><td>&nbsp;&nbsp;&nbsp;&nbsp;</td><td>&nbsp;&nbsp;&nbsp;&nbsp;</td><td><b>$$lang_vars{ip_address_message}</b>&nbsp;&nbsp;&nbsp;</td><td width=\"30px\" align=\"center\"><b> $$lang_vars{prefix_length_message} </b></td><td>&nbsp;&nbsp;<b> $$lang_vars{description_message}</b></td><td align=\"center\"><b>$$lang_vars{loc_message}</b>&nbsp;&nbsp;&nbsp;</td><td align=\"center\"><b>$$lang_vars{cat_message}</b>&nbsp;&nbsp;&nbsp;</td><td><b> $$lang_vars{comentario_message} </b></td><td><b>sync</b>&nbsp;&nbsp;&nbsp;</td><td><b>$$lang_vars{create_message}</b></td></tr>\n";
		} else {
			print "<tr><td></td></tr>";
		}

		for ( my $m=0; $m<$m_end; $m++ ) {

			if ( $color eq "white" ) {
				$color = "#f2f2f2";
			} else {
				$color = "white";
			}

			my $descr=$ip_cat_loc[$m]->[2] || "";
			$descr="" if $descr eq "NULL";
			my $loc_show=$ip_cat_loc[$m]->[4] || "";
			$loc_show="" if $loc_show eq "NULL";

			my $comentario=$ip_cat_loc[$m]->[6] || "";
			$comentario="" if $comentario eq "NULL";
			$comentario.=" " if $comentario;
			my $cat=$cat->[0];

			my $sinc=$ip_cat_loc[$m]->[8] || "";
			my $sinc_checked="";
			$sinc_checked="checked" if $sinc eq "y";

			my $loc_id=$ip_cat_loc[$m]->[9];
			my $cat_id=$ip_cat_loc[$m]->[10];

			print "<tr bgcolor=\"$color\"><td>&nbsp;&nbsp;&nbsp;&nbsp;</td><td>&nbsp;&nbsp;&nbsp;&nbsp;</td><td>$nextred_4</td><td align=\"center\">64</td><td><input type=\"text\" name=\"descr_l4_${i}_${j}_${m}\" value=\"$descr\"></td><td align=\"center\">$loc->[0]</td><td align=\"center\">$cat</td><td><input type=\"text\" name=\"comentario_l4_${i}_${j}_${m}\" value=\"$comentario\"></td><td align=\"center\"><input type=\"checkbox\" name=\"sinc_l4_${i}_${j}_${m}\" value=\"yes\" $sinc_checked></td>\n";

			print "<td align=\"center\"><input type=\"checkbox\" name=\"create_l4_${i}_${j}_${m}\" value=\"create\" checked>\n";
#			print "<input type=\"hidden\" name=\"red_l4_${i}_${j}_${m}\" value=\"$nextred_4\"><input type=\"hidden\" name=\"BM_l4_${i}_${j}_${m}\" value=\"$BM_l4\"><input type=\"hidden\" name=\"loc_id_l4_${i}_${j}_${m}\" value=\"$loc_hash->{$loc->[0]}\"><input type=\"hidden\" name=\"cat_id_l4_${i}_${j}_${m}\" value=\"$cat_hash->{$cat}\"><input type=\"hidden\" name=\"loc_l4_${i}_${j}_${m}\" value=\"$loc->[0]\"><input type=\"hidden\" name=\"cat_${m}\" value=\"$cat\"></td><td><input type=\"button\" name=\"clear_button_l4_${i}_${j}_${m}\" value=\"\" class=\"reset_text_field_button\" onClick=\"descr_l4_${i}_${j}_${m}.value='';comentario_l4_${i}_${j}_${m}.value='';\"></td></tr>\n";
			print "<input type=\"hidden\" name=\"red_l4_${i}_${j}_${m}\" value=\"$nextred_4\"><input type=\"hidden\" name=\"BM_l4_${i}_${j}_${m}\" value=\"$BM_l4\"><input type=\"hidden\" name=\"loc_id_l4_${i}_${j}_${m}\" value=\"$loc_hash->{$loc->[0]}\"><input type=\"hidden\" name=\"cat_id_l4_${i}_${j}_${m}\" value=\"$cat_hash->{$cat}\"><input type=\"hidden\" name=\"loc_l4_${i}_${j}_${m}\" value=\"$loc->[0]\"><input type=\"hidden\" name=\"cat_l4_${i}_${j}_${m}\" value=\"$cat\"></td><td><input type=\"button\" name=\"clear_button_l4_${i}_${j}_${m}\" value=\"\" class=\"reset_text_field_button\" onClick=\"descr_l4_${i}_${j}_${m}.value='';comentario_l4_${i}_${j}_${m}.value='';\"></td></tr>\n";

			$nextred_int_4+=$anz_L4+1; 
			$nextred_4 = $gip->int_to_ip("$client_id","$nextred_int_4","v6");
		}
		print "</table>\n";
		$l++;
	}
	$k++;
}


print "<br><p>\n";
print "<input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"hidden\" name=\"anz_locs\" value=\"$anz_locs\"><input type=\"hidden\" name=\"anz_cats\" value=\"$anz_cats\">\n";
print "<span style=\"float: $ori\"><input type=\"submit\" class=\"input_link_w\" title=\"$$lang_vars{create_message}\" style=\"cursor:pointer;\" onClick=\"document.pressed=this.value\" VALUE=\"insert\"></span>\n";
print "<span style=\"float: $ori\"><input type=\"submit\" title=\"$$lang_vars{export_network_list_message}\" class=\"input_link_w\" value=\"$$lang_vars{export_message}\" style=\"cursor:pointer;\" onClick=\"document.pressed=this.value\" VALUE=\"export\"></span>\n";
print "</form>\n";
print "<br>\n";



$gip->print_end("$client_id");
