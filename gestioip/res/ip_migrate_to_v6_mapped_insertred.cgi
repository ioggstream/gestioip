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
use Net::IP;
use Net::IP qw(:PROC);
use lib '../modules';
use GestioIP;

my $daten=<STDIN>;
my $gip = GestioIP -> new();
my %daten=$gip->preparer($daten);

my $lang = $daten{'lang'} || "";
my ($lang_vars,$vars_file,$entries_per_page);
if ( $daten{'entries_per_page'} ) {
        $daten{'entries_per_page'} = "500" if $daten{'entries_per_page'} !~ /^\d{1,3}$/;
        ($lang_vars,$vars_file,$entries_per_page)=$gip->get_lang("$daten{'entries_per_page'}","$lang");
} else {
        ($lang_vars,$vars_file,$entries_per_page)=$gip->get_lang("","$lang");
}

my $client_id = $daten{'client_id'} || "";
if ( $client_id !~ /^\d{1,4}$/ ) {
#	$client_id = 1;
	$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{ipv6_address_plan_message}","$vars_file");
	$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (1) $client_id");
}

my $ip_version = "v6";

my $anz_redes=$daten{'anz_redes'};

my @global_config = $gip->get_global_config("$client_id");
my $global_ip_version=$global_config[0]->[5] || "v4";
my $ip_version_ele="";


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

print "<p><b style=\"float: $ori\">$$lang_vars{creating_networks_message}</b><br><p>\n";
print "<span class=\"sinc_text\">";

$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (2)") if $ip_version !~ /^(v4|v6)$/; 
$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (3)") if $anz_redes !~ /^\d{1,5}/; 

my @new_redes_detail=();

for (my $l=0; $l <= $anz_redes; $l++) {
	if ( ! $daten{"red_$l"} ) {
		next;
	}
	$new_redes_detail[$l]->[0] = ip_expand_address($daten{"red_$l"},6);
	$new_redes_detail[$l]->[1] = $daten{"BM_$l"};
	$new_redes_detail[$l]->[2] = $daten{"descr_$l"} || "";
	$new_redes_detail[$l]->[3] = $daten{"loc_id_$l"} || "";
	$new_redes_detail[$l]->[4] = $daten{"cat_id_$l"} || "";
	$new_redes_detail[$l]->[5] = $daten{"comentario_$l"} || "";
	$new_redes_detail[$l]->[6] = $daten{"sinc_$l"} || "n";
	$new_redes_detail[$l]->[7] = $daten{"loc_$l"} || "";
	$new_redes_detail[$l]->[8] = $daten{"cat_$l"} || "";
	$new_redes_detail[$l]->[9] = $daten{"create_$l"} || "";
}

my $rootnet_val="0";
my $m = "0";
my $event;
foreach my $ele (@new_redes_detail) {
if ( ! $ele || ! $new_redes_detail[$m]->[0] ) { next; }

	my $create=$new_redes_detail[$m]->[9];
	if ( $create ne "create" ) {
		$m++;
		next;
	}

	my $red_nuevo=$new_redes_detail[$m]->[0];
	my $BM_nuevo=$new_redes_detail[$m]->[1];
	my $descr_nuevo = $new_redes_detail[$m]->[2] || "NULL";
	my $loc_id_nuevo = $new_redes_detail[$m]->[3] || "-1";
	my $cat_id_nuevo = $new_redes_detail[$m]->[4] || "-1";
	my $comentario_nuevo = $new_redes_detail[$m]->[5] || "NULL";
	my $vigilada_nuevo = $new_redes_detail[$m]->[6] || "n";
	my $loc_nuevo = $new_redes_detail[$m]->[7] || "";
	my $cat_nuevo = $new_redes_detail[$m]->[8] || "";

#	my $redob = $red_nuevo . "/" . $BM_nuevo;
#	my $ipob = new Net::IP ($redob) or $gip->print_error("$client_id","$$lang_vars{formato_malo_message}<b>$redob</b>");
	my $red_exists = $gip->check_red_exists("$client_id","$red_nuevo","$BM_nuevo","");
        if ( $red_exists ) {
		if ( $vars_file =~ /vars_he$/ ) {
			print "<span style=\"float: $ori\">$$lang_vars{ignorado_message} - $$lang_vars{red_exists_message} :<b>$red_nuevo/$BM_nuevo</b></span><br>\n";
		} else {
			print "<b>$red_nuevo/$BM_nuevo</b>: $$lang_vars{red_exists_message} - $$lang_vars{ignorado_message}<br>\n";
		}
		$m++;
		next;
	}

	my $red_id_nuevo=$gip->get_last_red_num("$client_id");
	$red_id_nuevo++;
	$gip->insert_net("$client_id","$red_id_nuevo","$red_nuevo","$BM_nuevo","$descr_nuevo","$loc_id_nuevo","$vigilada_nuevo","$comentario_nuevo","$cat_id_nuevo","$ip_version","$rootnet_val") or die $gip->print_error("$client_id");
	print "<p><b style=\"float: $ori\">$$lang_vars{redes_nuevos_done_message}</b><br><p>\n" if $m == "0";
	if ( $vars_file =~ /vars_he$/ ) {
		print "<span style=\"float: $ori\">$$lang_vars{added_message} :<b>$red_nuevo/$BM_nuevo</b></span><br>\n";
	} else {
		print "<b>$red_nuevo/$BM_nuevo</b>: $$lang_vars{added_message}<br>\n";
	}


	#audit
	my $audit_type="17";
	my $audit_class="2";
	my $update_type_audit="1";
	$descr_nuevo = "---" if $descr_nuevo eq "NULL";
	$loc_nuevo = "---" if $loc_nuevo eq "NULL";
	$cat_nuevo = "---" if $cat_nuevo eq "NULL";
	$comentario_nuevo = "---" if $comentario_nuevo eq "NULL";
	$event = "$red_nuevo/$BM_nuevo,$descr_nuevo,$loc_nuevo,$cat_nuevo,$comentario_nuevo,$vigilada_nuevo" if $new_redes_detail[$m]->[0];
	$gip->insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");
	$m++;
}



print "</span>";
print "<h3 style=\"float: $ori\">$$lang_vars{listo_message}</h3><br><p><br>$rtl_helper\n";

$gip->print_end("$client_id","$vars_file","go_to_top");
