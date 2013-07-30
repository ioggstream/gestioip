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

my $carry_over=$daten{carry_over} || "";
my $independent_anz=$daten{independent_anz} || "";
my $assign_hex=$daten{assign_hex} || "";

my $BM_l2_lastred=$daten{'BM_l2_lastred'} || "";
my $future_locs=$daten{'future_locs'} || "";
my $future_cats=$daten{'future_cats'} || "";
my $max_cat_nets=$daten{'future_networks'} || "1";
my $BM_l2=$daten{'BM_l2'} || "";
my $BM_l2_anz=$daten{'BM_l2_anz'} || "";
my $BM_l3=$daten{'BM_l3'} || "";
my $BM_l3_anz=$daten{'BM_l3_anz'} || "";
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
	$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (0)");
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

print "<p><br>\n";
print "<span style=\"float: $ori\"><b>$$lang_vars{hierarchical_plan_message}</b></span> <span style=\"float: $ori\">&nbsp;&nbsp;($$lang_vars{ip_address_block_message} $base_net/$BM6)</span><br>\n";


my @stat_net_cats4 = $gip->get_stat_net_cats("$client_id","v4");
my @stat_net_locs4 = $gip->get_stat_net_locs("$client_id","v4");
my @values_categorias=$gip->get_cat_net("$client_id");
my @values_locations=$gip->get_loc("$client_id");
my $anz_locs=$gip->count_locs("$client_id");
#$anz_locs+=$future_locs;
$anz_locs=$future_locs;
my $anz_cats=$gip->count_cats("$client_id");
#$anz_cats+=$future_cats;
$anz_cats=$future_cats;
my %bm = $gip->get_anz_hosts_bm_hash("$client_id","v6");
my $site_cat_counts=$gip->count_site_cats_nets("$client_id",\@values_categorias,\@values_locations);


my %counts_loc_nets = ();
my $i=0;
for (@stat_net_locs4) {
	$counts_loc_nets{$stat_net_locs4[$i++]->[0]}++;
}

my $max_loc_nets = 0;
$_ > $max_loc_nets and $max_loc_nets = $_ for values %counts_loc_nets;


my %counts_cat_nets=();
$i=0;
for (@stat_net_cats4) {
	$counts_cat_nets{$stat_net_cats4[$i++]->[0]}++;
}

print "<p><br>\n";
print "<table border=\"0\">\n";

my $script="ip_migrate_hierarchical_to_v6_1.cgi";
$script="ip_migrate_to_v6_hierarchical_assign.cgi" if $assign_hex;

my $possible_subnets_message="";
my $free_networks_left_message="";
my $nibble_boundary_text="";
my $input_link_style;
my $net_host_message;
my $start = $BM6+1;
my $test=63;
my $last=65;
my $k=0;
my $base_net_comp=ip_compress_address ($base_net, 6);
my $valid_net_found="0";
my ($BM_l4, $BM_l4_anz);
if ( ! $BM_l2 ) {
	my $free_networks_left_rtl="";
	$free_networks_left_message.="$$lang_vars{surplus_location_networks_message}";
	for (my $i=$start; $i<=$last; $i++) {
		if ( ! defined($bm{$test}) ) {
			last;
		}
		my $anz_redes=$bm{$test};
		my $anz_redes2=$bm{$i};
		$anz_redes=~s/,//g;
		$anz_redes2=~s/,//g;
		my $div=$bm{$i};
		$div=~s/,//g;
		my $nets_por_cat=$div/$anz_cats;
		$nets_por_cat=~s/\..*//;

		my $free_networks_left=$anz_redes-$anz_locs;
		if ( $anz_redes < $anz_locs ) {
			$test--;
			$k++;
			next;
		}
		my $m=0;
		my $test1="63";
		my $start1=$i+1;
		my @level_2_redes_ok=();
		for (my $j=$start1; $j<=63; $j++) {
			my $anz_redes_x=$bm{$test1};
			my $anz_redes2_x=$bm{$j};
			$anz_redes_x=~s/,//g;
			$anz_redes2_x=~s/,//g;
			if ( $anz_redes_x < $anz_cats ) {
				$test1--;
				next;
			}
			if ( $anz_redes2_x < $max_cat_nets ) {
				last;
			}
			$level_2_redes_ok[$m]=$i;
			$m++;
			$test1--;
		}

		if ( ! $level_2_redes_ok[0] ) {
			print "$$lang_vars{not_enough_bits_message}<br>\n" if $valid_net_found == 0;
			print "<p><br><p><FORM><INPUT TYPE=\"BUTTON\" VALUE=\"$$lang_vars{atras_message}\" ONCLICK=\"history.go(-1)\" class=\"error_back_link\"></FORM>\n" if $valid_net_found == 0;
			last;
		}

		if ( $valid_net_found == 0 ) {
			if ( $vars_file =~ /vars_he$/ ) {
				print "<b style=\"float: $ori\">$$lang_vars{subnet_level_message} I: $$lang_vars{locs_message}</b><br><p>\n";
			} else {
				print "<b style=\"float: $ori\">$$lang_vars{locs_message}: I $$lang_vars{subnet_level_message}</b><br><p>\n";
			}
			print "<span style=\"float: $ori\">$$lang_vars{choose_amount_message} <i>$$lang_vars{locs_message}</i></span><br><p>\n";
		}

		$valid_net_found=1;

		if ( $vars_file =~ /vars_he$/ ) {
			$free_networks_left_rtl=$free_networks_left;
			$free_networks_left="";
		}

		$input_link_style="input_link_w_net";
		$nibble_boundary_text="Non-Nibble Boundary";
		if ( $i % 4 == 0 ) {
			$input_link_style="input_link_g_net" if $k <= 64;
			$nibble_boundary_text="Nibble Boundary";
		}
				
		$net_host_message = "($bm{$i} $$lang_vars{entradas_redes_message})";
		print "<tr><td $align1>$possible_subnets_message</td><td $align1><form name=\"calculate_form_more_l1_${i}\" id=\"calculate_form_more_l1_${i}\" method=\"POST\" action=\"$server_proto://$base_uri/ip_migrate_hierarchical_to_v6.cgi\" style=\"display:inline\"><input type=\"hidden\" name=\"red\" value=\"$base_net\"><input type=\"hidden\" name=\"BM\" value=\"$BM6\"><input type=\"hidden\" name=\"ip_version\" value=\"v6\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"hidden\" name=\"more_possible_subnets\" value=\"yes\"><input type=\"hidden\" name=\"BM_l2\" value=\"${i}\"><input type=\"hidden\" name=\"BM_l2_anz\" value=\"$bm{$test}\"><input type=\"hidden\" name=\"base_net\" value=\"$base_net/$BM6\"><input type=\"hidden\" name=\"future_locs\" value=\"$future_locs\"><input type=\"hidden\" name=\"future_cats\" value=\"$future_cats\"><span id=\"selected_index${k}\"></span><input type=\"hidden\" name=\"carry_over\" value=\"$carry_over\"><input type=\"hidden\" name=\"assign_hex\" value=\"$assign_hex\"><input type=\"hidden\" name=\"independent_anz\" value=\"$independent_anz\"><input type=\"hidden\" name=\"future_networks\" value=\"$max_cat_nets\"><input type=\"submit\" value=\"$bm{$test} $$lang_vars{redes_dispo_message} /${i}\" name=\"B2\" class=\"$input_link_style\" title=\"$nibble_boundary_text\"></form> ${rtl_helper}${free_networks_left} ${free_networks_left_message}${rtl_helper}${free_networks_left_rtl}</td></tr>\n";
		$test--;
		$k++;
		last if $k == "63";
	}
	print "</table>\n";
} elsif ( $BM_l2 && ! $BM_l3 ) {
	my $free_networks_left_rtl="";
	if ( $lang_vars =~ /vars_he$/ ) {
		print "<b style=\"float: $ori\">$$lang_vars{cats_message} : II $$lang_vars{subnet_level_message}</b><br><p>\n";
	} else {
		print "<b style=\"float: $ori\">$$lang_vars{subnet_level_message} II: $$lang_vars{cats_message}</b><br><p>\n";
	}
	print "<span style=\"float: $ori\">$$lang_vars{choose_amount_message} <i>$$lang_vars{cats_message}</i></span><br><p>\n";
	$free_networks_left_message.="$$lang_vars{surplus_cat_networks_message}";

	my $redob_in = $base_net . "/" . $BM6;
	my $ipob_red_in = new Net::IP ($redob_in) or die "Can not create IP object: $!\n";
	my $last_ip_int = ($ipob_red_in->last_int());
	$last_ip_int = Math::BigInt->new("$last_ip_int");


	my $redob_in_l2 = $base_net . "/" . $BM_l2;
	my $ipob_red_in_l2 = new Net::IP ($redob_in_l2) or die "Can not create IP object: $!\n";
	my $last_ip_int_l2 = ($ipob_red_in_l2->last_int());
	$last_ip_int_l2 = Math::BigInt->new("$last_ip_int_l2");
	my $redint_l2=($ipob_red_in_l2->intip()) || 0;
	$redint_l2 = Math::BigInt->new("$redint_l2");
	$redint_l2--;

	my $BM_l2_anz=$daten{BM_l2_anz};
	my $BM_l2_value=$last_ip_int_l2-$redint_l2;
	$BM_l2_value =~ s/,//g;
	$BM_l2_value = Math::BigInt->new("$BM_l2_value");
	my $first_ip_last_red_int=$last_ip_int - $BM_l2_value + 2;
	$first_ip_last_red_int--;
	$first_ip_last_red_int = Math::BigInt->new("$first_ip_last_red_int");
	my $first_ip_last_red = $gip->int_to_ip("$client_id","$first_ip_last_red_int","v6");
	my $first_ip_last_red_comp=ip_compress_address ($first_ip_last_red, 6);
	if ( $vars_file =~ /vars_he$/ ) {
		print "<tr><td $align>${rtl_helper}<i>$$lang_vars{locs_message}</i> :I $$lang_vars{subnet_level_message}</td><td $align1>${rtl_helper}($anz_locs :$$lang_vars{required_message}) <b>/${BM_l2} $$lang_vars{redes_dispo_message} $BM_l2_anz</b><br>${rtl_helper}($base_net_comp/${BM_l2} - $first_ip_last_red_comp/${BM_l2})${rtl_helper}<FORM style=\"display:inline\"><INPUT TYPE=\"BUTTON\" VALUE=\"back\" ONCLICK=\"history.go(-1)\" class=\"error_back_link\"></FORM></td></tr>\n";
	} else {
		print "<tr><td $align1>$$lang_vars{subnet_level_message} I: <i>$$lang_vars{locs_message}</i></td><td $align1><b>${rtl_helper}$BM_l2_anz $$lang_vars{redes_dispo_message} /${BM_l2}</b> ($$lang_vars{required_message}: $anz_locs)${rtl_helper}<br>($base_net_comp/${BM_l2} - $first_ip_last_red_comp/${BM_l2}) <FORM style=\"display:inline\"><INPUT TYPE=\"BUTTON\" VALUE=\"back\" ONCLICK=\"history.go(-1)\" class=\"error_back_link\"></FORM></td></tr>\n";
	}
	my $start = $BM_l2+1;
	my $net_host_message;
	if ( $vars_file =~ /vars_he$/ ) {
		$possible_subnets_message="${rtl_helper}<i>$$lang_vars{cats_message}</i> :II $$lang_vars{subnet_level_message}";
	} else {
		$possible_subnets_message="$$lang_vars{subnet_level_message} II: <i>$$lang_vars{cats_message}</i>";
	}
	my $found_valid_net=0;
	for (my $i=$start; $i<=$last-2; $i++) {
		if ( ! defined($bm{$test}) ) {
			last;
		}
		my $anz_redes=$bm{$test};
		my $anz_redes2=$bm{$i};
		$anz_redes=~s/,//g;
		$anz_redes2=~s/,//g;
		my $free_networks_left=$anz_redes-$anz_cats;
		if ( $anz_redes < $anz_cats ) {
			$test--;
			$k++;
			next;
		}
		if ( $i==65 || $anz_redes2 < $max_cat_nets ) {
			last;
		}

		$found_valid_net=1;
		$net_host_message = "($bm{$i} $$lang_vars{entradas_redes_message} $$lang_vars{per_message} $$lang_vars{cat_message})" if $i < 64;

		if ( $vars_file =~ /vars_he$/ ) {
			$free_networks_left_rtl=$free_networks_left;
			$free_networks_left="";
			$net_host_message = "($$lang_vars{direcciones_message} $bm{i})${rtl_helper}";
			$net_host_message = " ($$lang_vars{cat_message} $$lang_vars{per_message} $$lang_vars{entradas_redes_message} $bm{$i})${rtl_helper}" if $i < 64;
		}

		$input_link_style="input_link_w_net";
		$nibble_boundary_text="Non-Nibble Boundary";
		if ( $i % 4 == 0 ) {
			$input_link_style="input_link_g_net" if $k <= 64;
			$nibble_boundary_text="Nibble Boundary";
		}

		print "<tr><td $align>$possible_subnets_message</td><td $align1><form name=\"calculate_form_more_l2_${i}\" id=\"calculate_form_more_l2_${i}\" method=\"POST\" action=\"$server_proto://$base_uri/ip_migrate_hierarchical_to_v6.cgi\" style=\"display:inline\"><input type=\"hidden\" name=\"red\" value=\"$base_net\"><input type=\"hidden\" name=\"BM\" value=\"$BM6\"><input type=\"hidden\" name=\"ip_version\" value=\"v6\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"hidden\" name=\"more_possible_subnets\" value=\"yes\"><input type=\"hidden\" name=\"BM_l2\" value=\"$BM_l2\"><input type=\"hidden\" name=\"BM_l2_anz\" value=\"$BM_l2_anz\"><input type=\"hidden\" name=\"BM_l2_lastred\" value=\"$first_ip_last_red\"><input type=\"hidden\" name=\"BM_l3\" value=\"${i}\"><input type=\"hidden\" name=\"BM_l3_anz\" value=\"$bm{$test}\"><input type=\"hidden\" name=\"base_net\" value=\"$base_net/$BM6\"><input type=\"hidden\" name=\"future_locs\" value=\"$future_locs\"><input type=\"hidden\" name=\"future_cats\" value=\"$future_cats\"><span id=\"selected_index${k}\"></span><input type=\"hidden\" name=\"carry_over\" value=\"$carry_over\"><input type=\"hidden\" name=\"assign_hex\" value=\"$assign_hex\"><input type=\"hidden\" name=\"independent_anz\" value=\"$independent_anz\"><input type=\"hidden\" name=\"future_networks\" value=\"$max_cat_nets\"><input type=\"submit\" value=\"$bm{$test} networks /${i}\" name=\"B2\" class=\"$input_link_style\" title=\"$nibble_boundary_text\"></form> ${free_networks_left} ${free_networks_left_message} ${free_networks_left_rtl}${net_host_message}</td></tr>\n";
		$possible_subnets_message="";
		$test--;
		$k++;
		last if $k == "63";
	}
	print "</table>\n";
} elsif ( $BM_l2 && $BM_l3 ) {
	print "<span style=\"float: $ori\">$$lang_vars{create_address_plan_message}</span><br><p>\n";

	my $redob_in = $base_net . "/" . $BM6;
	my $ipob_red_in = new Net::IP ($redob_in) or die "Can not create IP object: $!\n";
	my $last_ip_int = ($ipob_red_in->last_int());
	$last_ip_int = Math::BigInt->new("$last_ip_int");

	my $BM_l2_anz=$daten{BM_l2_anz};
	my $BM_l2_lastred_comp=ip_compress_address ($BM_l2_lastred, 6);


	my $redob_in_l3 = $base_net . "/" . $BM_l3;
	my $ipob_red_in_l3 = new Net::IP ($redob_in_l3) or die "Can not create IP object: $!\n";
	my $last_ip_int_l3 = ($ipob_red_in_l3->last_int());
	$last_ip_int_l3 = Math::BigInt->new("$last_ip_int_l3");
	my $redint_l3=($ipob_red_in_l3->intip()) || 0;
	$redint_l3 = Math::BigInt->new("$redint_l3");
	$redint_l3--;

	my $BM_l3_value=$last_ip_int_l3-$redint_l3;
	my $BM_64_value=$bm{64};
	$BM_l3_value =~ s/,//g;
	$BM_l3_value = Math::BigInt->new("$BM_l3_value");
	$BM_64_value =~ s/,//g;
	$BM_64_value = Math::BigInt->new("$BM_64_value");
	my $BM_l3_lastred_int=$last_ip_int - $BM_l3_value + 2;
	$BM_l3_lastred_int--;
	$BM_l3_lastred_int = Math::BigInt->new("$BM_l3_lastred_int");
	my $BM_l3_lastred = $gip->int_to_ip("$client_id","$BM_l3_lastred_int","v6");
	my $BM_l3_lastred_comp=ip_compress_address ($BM_l3_lastred, 6);
	my $first_ip_last_red_64_int=$last_ip_int - $BM_64_value + 2;
	$first_ip_last_red_64_int--;
	$first_ip_last_red_64_int = Math::BigInt->new("$first_ip_last_red_64_int");
	my $first_ip_last_64_red = $gip->int_to_ip("$client_id","$first_ip_last_red_64_int","v6");
	my $first_ip_last_64_red_comp=ip_compress_address ($first_ip_last_64_red, 6);
	if ( $vars_file =~ /vars_he$/ ) {
		print "<tr><td $align><i>$$lang_vars{locs_message}</i> :I $$lang_vars{subnet_level_message}</td><td $align1>${rtl_helper}($anz_locs :$$lang_vars{required_message}) <b>/${BM_l2} $$lang_vars{redes_dispo_message} $BM_l2_anz</b><br>${rtl_helper}($base_net_comp/${BM_l2} - $BM_l2_lastred_comp/${BM_l2})${rtl_helper}</td></tr>\n";
		print "<tr><td $align><i>$$lang_vars{cats_message}</i> :II $$lang_vars{subnet_level_message}</td><td $align1>&nbsp;&nbsp;&nbsp;&nbsp;${rtl_helper}($anz_cats :$$lang_vars{required_message}) <b>/${BM_l3} $$lang_vars{redes_dispo_message} $BM_l3_anz</b><br>&nbsp;&nbsp;&nbsp;&nbsp;${rtl_helper}($base_net_comp/${BM_l3} - $BM_l3_lastred_comp/${BM_l3})${rtl_helper}</td></tr>\n";
	} else {
		print "<tr><td>$$lang_vars{subnet_level_message} I: <i>$$lang_vars{locs_message}</i></td><td><b>$BM_l2_anz networks /${BM_l2}</b> ($$lang_vars{required_message}: $anz_locs)<br>($base_net_comp/${BM_l2} - $BM_l2_lastred_comp/${BM_l2})</td></tr>\n";
		print "<tr><td>$$lang_vars{subnet_level_message} II: <i>$$lang_vars{cats_message}</i></td><td>&nbsp;&nbsp;&nbsp;&nbsp;<b>$BM_l3_anz networks /${BM_l3}</b> ($$lang_vars{required_message}: $anz_cats)<br>&nbsp;&nbsp;&nbsp;&nbsp;($base_net_comp/${BM_l3} - $BM_l3_lastred_comp/${BM_l3})</td></tr>\n";
	}
	my $start = $BM_l2+1;
	my $net_host_message;
#	$possible_subnets_message=$$lang_vars{subnet_level_message};
	if ( $vars_file =~ /vars_he$/ ) {
		$possible_subnets_message ="<i>$$lang_vars{cat_message} $$lang_vars{per_message} $$lang_vars{endnets_message} :III $$lang_vars{subnet_level_message}";
	} else {
		$possible_subnets_message ="$$lang_vars{subnet_level_message} III: <i>$$lang_vars{endnets_message} $$lang_vars{per_message} $$lang_vars{cat_message}</i>";
	}
	for (my $i=$start; $i<=$last; $i++) {
		last if ! defined($bm{$test});
		my $anz_redes=$bm{$test};
		my $anz_redes2=$bm{$i};
		$anz_redes=~s/,//g;
		$anz_redes2=~s/,//g;
		my $free_networks_left=$anz_redes-$anz_cats;
		if ( $i < 64 ) {
			$test--;
			$k++;
			next;
		}
		last if $i==65;
		$net_host_message = "($bm{$i} $$lang_vars{direcciones_message})";
		$net_host_message = "($bm{$i} $$lang_vars{entradas_redes_message})" if $i < 64;
		if ( $vars_file =~ /vars_he$/ ) {
			print "<tr><td $align>$possible_subnets_message</td><td $align1>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;${rtl_helper}($max_cat_nets :$$lang_vars{required_message}) <b>/${i} $$lang_vars{redes_dispo_message} $bm{$BM_l3}</b><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;${rtl_helper}($base_net_comp/${i} - $first_ip_last_64_red_comp/${i})$rtl_helper  <FORM style=\"display:inline\"><INPUT TYPE=\"BUTTON\" VALUE=\"back\" ONCLICK=\"history.go(-1)\" class=\"error_back_link\"></FORM></td></tr>\n";
		} else {
			print "<tr><td $align>$possible_subnets_message</td><td $align1>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<b>$bm{$BM_l3} networks /${i}</b> ($$lang_vars{required_message}: $max_cat_nets)<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;($base_net_comp/${i} - $first_ip_last_64_red_comp/${i}) <FORM style=\"display:inline\"><INPUT TYPE=\"BUTTON\" VALUE=\"back\" ONCLICK=\"history.go(-1)\" class=\"error_back_link\"></FORM></td></tr>\n";
		}
		$BM_l4="$i";
		$BM_l4_anz=$bm{$BM_l3};
		$possible_subnets_message="";
		$test--;
		$k++;
		last if $k == "63";
	}

print "</table>\n";

my $script="ip_migrate_hierarchical_to_v6_1.cgi";
$script="ip_migrate_to_v6_hierarchical_countnets.cgi" if $independent_anz;


print <<EOF;
<p><br>
<form name="calculate_form_more" id="calculate_form_more" method="POST" action="$server_proto://$base_uri/$script" style="display:inline"><input type="hidden" name="base_net" value="${base_net}/${BM6}"><input type="hidden" name="ip_version" value="v6"><input type="hidden" name="client_id" value="$client_id"> 
<p><br>
<span style=\"float: $ori\">
<input type="hidden" name="algorithm" value="leftmost"><input type="hidden" name="BM_l2" value="$BM_l2"><input type="hidden" name="BM_l2_anz" value="$BM_l2_anz"> <input type="hidden" name="BM_l3" value="$BM_l3"> <input type="hidden" name="BM_l3_anz" value="$BM_l3_anz"><input type="hidden" name="BM_l4" value="$BM_l4"> <input type="hidden" name="BM_l4_anz" value="$BM_l4_anz"><input type="hidden" name="max_cat_nets" value="$max_cat_nets"><input type="hidden" name="max_loc_nets" value="$max_loc_nets"><input type="hidden" name="anz_locs" value="$anz_locs"><input type="hidden" name="anz_cats" value="$anz_cats">
<span id="selected_index${k}"></span><input type=\"hidden\" name=\"carry_over\" value=\"$carry_over\"><input type=\"hidden\" name=\"assign_hex\" value=\"$assign_hex\"><input type=\"hidden\" name=\"independent_anz\" value=\"$independent_anz\"><input type="submit" value="$$lang_vars{submit_message}" name="B2" class="input_link_w_net"></form>
</span>


EOF

}

$gip->print_end("$client_id");
