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
my $max_loc_nets=$daten{'max_loc_nets'} || "";
my $max_cat_nets=$daten{'max_cat_nets'} || "";
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


print "<p><br>\n";
print "<span style=\"float: $ori\"><b>$$lang_vars{hierarchical_plan_message}</b></span> <span style=\"float: $ori\">&nbsp;&nbsp;($$lang_vars{ip_address_block_message} $base_net/$BM6)</span><br>\n";
print "<p><br>\n";
print "<span style=\"float: $ori\">$$lang_vars{choose_nets_por_catloc_message}</span>\n";

my @stat_net_cats4 = $gip->get_stat_net_cats("$client_id","v4");
my @stat_net_locs4 = $gip->get_stat_net_locs("$client_id","v4");
my @values_categorias=$gip->get_cat_net("$client_id");
my @values_locations=$gip->get_loc("$client_id");
my %bm = $gip->get_anz_hosts_bm_hash("$client_id","v6");
my $site_cat_counts=$gip->count_site_cats_nets("$client_id",\@values_categorias,\@values_locations);

my $script="ip_migrate_hierarchical_to_v6_1.cgi";

print "<p><br>\n";
print "<form name=\"mig_hira_form\" id=\"mig_hira_form\" method=\"POST\" action=\"$server_proto://$base_uri/$script\" style=\"display:inline\">\n";
print "<table border=\"0\" style=\"border-collapse:collapse\">\n";

my $j=0;
if ( $carry_over ) {
	for ( my $i=0; $i<=$anz_locs; $i++ ) {
		my $loc=$values_locations[$i];
		if ( $loc->[0] ) {
			next if $loc->[0] eq "NULL";
			print "<tr><td><b>$loc->[0]</b></td></tr>";
		} else {
			next;
		}
		foreach my $cat (@values_categorias ) {
			next if $cat->[0] eq "NULL";
			print "<tr><td>$cat->[0]</td><td> <input type=\"text\" name=\"cat_loc_anz_${i}_${j}\" value=\"${$site_cat_counts}{\"$loc->[0]_$cat->[0]\"}->[0]\" size=\"3\"></td>\n";
			$j++;
		}
		print "<tr><td><br></td><td></td></tr>\n";
	}
}

print "</table>\n";

print "<br><p>\n";
print "<input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"hidden\" name=\"base_net\" value=\"${base_net}/${BM6}\"><input type=\"hidden\" name=\"ip_version\" value=\"v6\">\n";

print "<input type=\"hidden\" name=\"algorithm\" value=\"leftmost\"><input type=\"hidden\" name=\"BM_l2\" value=\"$BM_l2\"><input type=\"hidden\" name=\"BM_l2_anz\" value=\"$BM_l2_anz\"> <input type=\"hidden\" name=\"BM_l3\" value=\"$BM_l3\"> <input type=\"hidden\" name=\"BM_l3_anz\" value=\"$BM_l3_anz\"><input type=\"hidden\" name=\"BM_l4\" value=\"$BM_l4\"> <input type=\"hidden\" name=\"BM_l4_anz\" value=\"$BM_l4_anz\"><input type=\"hidden\" name=\"max_cat_nets\" value=\"$max_cat_nets\"><input type=\"hidden\" name=\"max_loc_nets\" value=\"$max_loc_nets\"><input type=\"hidden\" name=\"anz_locs\" value=\"$anz_locs\"><input type=\"hidden\" name=\"anz_cats\" value=\"$anz_cats\">\n";

print "<span style=\"float: $ori\">\n";
print "<input type=\"hidden\" name=\"carry_over\" value=\"$carry_over\"><input type=\"hidden\" name=\"assign_hex\" value=\"$assign_hex\"><input type=\"hidden\" name=\"independent_anz\" value=\"$independent_anz\"><input type=\"submit\" value=\"$$lang_vars{submit_message}\" name=\"B2\" class=\"input_link_w_net\">\n";
print "</span>\n";
print "</form>\n";


$gip->print_end("$client_id");
