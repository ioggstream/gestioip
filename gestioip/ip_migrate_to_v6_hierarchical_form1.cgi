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
if ( $valid_v6 != 1 || ! $base_net || ! $BM6  ) {
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


print "<p><br>\n";
print "<span style=\"float: $ori\"><b>$$lang_vars{hierarchical_plan_message}</b></span> <span style=\"float: $ori\">&nbsp;&nbsp;($$lang_vars{ip_address_block_message} $base_net/$BM6)</span><br>\n";


if ( $red_in eq "0000:0000:0000:0000:0000:0000:0000:0000" ) {
	print "<p><br>$BM6: $$lang_vars{invalid_net_prefix_message} $base_net<p>\n";
	print "<p><br><FORM><INPUT TYPE=\"BUTTON\" VALUE=\"$$lang_vars{atras_message}\" ONCLICK=\"history.go(-1)\" class=\"error_back_link\"></FORM>\n";
	$gip->print_end("$client_id");
} elsif ( $base_net_exp ne $red_in ) {
	print "<p><br><i>$BM6: $$lang_vars{invalid_net_prefix_message} $base_net</i><p>\n";
	print "<i>$$lang_vars{using_net_message} $red_in/$BM6</i><p>\n";
}
	

my $match_message="";
print "<p><br>\n";
print "<form name=\"mig_form\"action=\"$server_proto://$base_uri/ip_migrate_hierarchical_to_v6.cgi\" method=\"post\">\n";
print "<p><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"hidden\" name=\"base_net\" value=\"$base_net/$BM6\"><input type=\"hidden\" name=\"mig_type\" value=\"hierarchical\"></p>\n";
if ( $BM6 <= 32 ) {
} elsif ( $BM6 <= 40 ) {
} elsif ( $BM6 <= 48 ) {
#	$match_message="$$lang_vars{hierarchical_block_explic1_message} /${BM6} $$lang_vars{hierarchical_block_explic_message}";
	$match_message="$$lang_vars{direct_translation_block_explic1_message} /${BM6} $$lang_vars{direct_translation_block_explic_message}";
} elsif ( $BM6 > 48  ) {
	$gip->print_error("$client_id","$$lang_vars{no_prefix_length_49_allowed}");
#} elsif ( $BM6 > 56  ) {
}

my @stat_net_cats4 = $gip->get_stat_net_cats("$client_id","v4");
my @values_categorias=$gip->get_cat_net("$client_id");
my @values_locations=$gip->get_loc("$client_id");
my $site_cat_counts=$gip->count_site_cats_nets("$client_id",\@values_categorias,\@values_locations);


my %counts_cat_nets=();
my $i=0;
for (@stat_net_cats4) {
        $counts_cat_nets{$stat_net_cats4[$i++]->[0]}++;
}

my $max_cat_nets = 0;
my $max_cat_nets_name;
#$_ > $max_cat_nets and $max_cat_nets = $_ for values %counts_cat_nets;

        for ( my $i=0; $i<=$anz_locs; $i++ ) {
                my $loc=$values_locations[$i];
                if ( $loc->[0] ) {
                        next if $loc->[0] eq "NULL";
                } else {
                        next;
                }
                foreach my $cat (@values_categorias ) {
                        next if $cat->[0] eq "NULL";
			if ( ${$site_cat_counts}{"$loc->[0]_$cat->[0]"}->[0] > $max_cat_nets ) {
				$max_cat_nets = ${$site_cat_counts}{"$loc->[0]_$cat->[0]"}->[0];
				$max_cat_nets_name="$loc->[0]_$cat->[0]";
			}
                }
        }


my %bm = $gip->get_anz_hosts_bm_hash("$client_id","v6");

my $biggest="0";
while ( my ($key, $value) = each(%$site_cat_counts) ) {
	next if $key =~ /NULL/;
	if ( $value->[0] > $biggest ) {
		$biggest=$value->[0] if $value->[0] > $biggest;
	}
}

my $loc_cat="";
my $k=0;
while ( my ($key, $value) = each(%$site_cat_counts) ) {
	next if $key =~ /NULL/;
	if ( $value->[0] == $biggest ) {
		$loc_cat.=", $key";
		$k++;
	}
	if ( $k == 2 ) {
		$loc_cat.=",...";
		last;
	}
}
$loc_cat =~ s/^, //;
$loc_cat =~ s/_/\//g;


my $anz_locs_dri=$anz_locs;
$anz_locs_dri=$anz_locs/3 if $anz_locs > $anz_locs_dri;
$anz_locs_dri=~s/\..*//;
my $future_locs=$anz_locs+$anz_locs_dri;

my $anz_cats_dri=$anz_cats;
$anz_cats_dri=$anz_cats/3;
$anz_cats_dri=~s/\..*//;
my $future_cats=$anz_cats+$anz_cats_dri;


my $max_cat_nets_show=$max_cat_nets;
$max_cat_nets=10 if $max_cat_nets == 0;
my $future_max_cat_nets=$max_cat_nets*2;


print "<table>\n";

if ( $vars_file =~ /vars_he$/ ) {
	print "<tr><td $align>$$lang_vars{how_many_sites_message}$rtl_helper</td><td $align1><input type=\"text\" name=\"future_locs\" size=\"2\" value=\"$future_locs\">&nbsp;&nbsp;($$lang_vars{locs_message} <b>$anz_locs</b> $$lang_vars{actually_using_message})</td></tr>\n";
	print "<tr><td $align>$$lang_vars{how_many_cats_message}$rtl_helper</td><td $align1><input type=\"text\" name=\"future_cats\" size=\"2\" value=\"$future_cats\">&nbsp;&nbsp;($$lang_vars{cats_message} <b>$anz_cats</b> $$lang_vars{actually_using_message})</td></tr>\n";
	print "<tr><td $align>$$lang_vars{net_reserve_for_futur_usage_message}$rtl_helper</td><td $align1><input type=\"text\" name=\"future_networks\" size=\"2\" value=\"$future_max_cat_nets\">$rtl_helper(($loc_cat) <b>$max_cat_nets_show</b> $$lang_vars{max_number_net_cat_message})$rtl_helper</td></tr>\n";
} else {
	print "<tr><td $align>$$lang_vars{how_many_sites_message}$rtl_helper</td><td $align1><input type=\"text\" name=\"future_locs\" size=\"2\" value=\"$future_locs\"> ($$lang_vars{actually_using_message} <b>$anz_locs</b> $$lang_vars{locs_message})</td></tr>\n";
	print "<tr><td $align>$$lang_vars{how_many_cats_message}$rtl_helper</td><td $align1><input type=\"text\" name=\"future_cats\" size=\"2\" value=\"$future_cats\"> ($$lang_vars{actually_using_message} <b>$anz_cats</b> $$lang_vars{cats_message})</td></tr>\n";
	print "<tr><td $align>$$lang_vars{net_reserve_for_futur_usage_message}$rtl_helper</td><td $align1><input type=\"text\" name=\"future_networks\" size=\"2\" value=\"$future_max_cat_nets\">$rtl_helper ($$lang_vars{max_number_net_cat_message} <b>$max_cat_nets_show</b> ($loc_cat))$rtl_helper</td></tr>\n";
}
print <<EOF;
</table>
<p><br>
<span style=\"float: $ori\">
$$lang_vars{carry_over_descr_message}
<input type="checkbox" name="carry_over" id="carry_over" value="carry_over" checked><p><br>
</span>
<p>
<span style=\"float: $ori\">
$$lang_vars{indep_net_number_message}
<input type="checkbox" name="independent_anz" id="independent_anz" value="independent_anz"><p><br>
</span>
<p>
EOF
#$$lang_vars{assign_special_hex_combination_message}
#<input type="checkbox" name="assign_hex" id="assign_hex" value="assign_hex" checked><p><br>

print <<EOF;
<br><p>
<span style=\"float: $ori\">
<input type="submit" name="Submit" value="$$lang_vars{submit_message}" class="input_link_w">
</span>
</form>
EOF


$gip->print_end("$client_id");
