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
use DBI;
use GestioIP;

my $daten=<STDIN>;
my $gip = GestioIP -> new();
my %daten=$gip->preparer("$daten") if $daten;

my $lang = $daten{'lang'} || "";
my ($lang_vars,$vars_file,$entries_per_page);
if ( $daten{'entries_per_page'} ) {
        $daten{'entries_per_page'} = "500" if $daten{'entries_per_page'} !~ /^\d{1,3}$/;
        ($lang_vars,$vars_file,$entries_per_page)=$gip->get_lang("$daten{'entries_per_page'}","$lang");
} else {
        ($lang_vars,$vars_file,$entries_per_page)=$gip->get_lang("","$lang");
}


my $client_id = $daten{'client_id'} || $gip->get_first_client_id();
if ( $client_id !~ /^\d{1,4}$/ ) {
        $client_id = 1;
        $gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{redes_message}","$vars_file");
        $gip->print_error("$client_id","$$lang_vars{formato_malo_message} (1)");
}

my $ip_version_ele=$daten{'ip_version_ele'} || $gip->get_ip_version_ele();
$ip_version_ele="v4" if ! $ip_version_ele;
my $ip_version=$daten{'ip_version'} || "";

my ($show_rootnet, $show_endnet,$hide_not_rooted);
$show_rootnet=$gip->get_show_rootnet_val() || "1";
$show_endnet=$gip->get_show_endnet_val() || "1";
$hide_not_rooted=$gip->get_hide_not_rooted_val() || "0";


$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{redes_dispo_message}","$vars_file");

$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (version_ele)") if $ip_version_ele !~ /^(v4|v6|46)$/;
$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (2)") if $ip_version !~ /^(v4|v6)$/;

if ( ! $daten{new_range} ) { $gip->print_error("$client_id",$$lang_vars{formato_malo_message}) };

my ($new_range,$red_nuevo, $BM_nuevo);
if ( $ip_version eq "v4" ) {
	if ( $daten{new_range} !~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\/\d{1,2}$/ ) { $gip->print_error("$client_id",$$lang_vars{check_new_rango_message}) };
	$new_range=$daten{new_range};
	$new_range =~ /^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\/(\d{1,2})$/;
	$red_nuevo = $1;
	$BM_nuevo = $2;
} else {
	if ( $daten{new_range} !~ /^\w+\:\w+\:\w+\:\w+\:\w+\:\w+\:\w+\:\w+\/\d{1,3}$/ ) { $gip->print_error("$client_id",$$lang_vars{check_new_rango_message}) };
	$new_range=$daten{new_range};
	$new_range =~ /^(\w+\:\w+\:\w+\:\w+\:\w+\:\w+\:\w+\:\w+)\/(\d{1,3})$/;
	$red_nuevo = $1;
	$BM_nuevo = $2;
}
my $red_exists = $gip->check_red_exists("$client_id","$red_nuevo","$BM_nuevo","");
$gip->print_error("$client_id","$$lang_vars{red_exists_message}: $new_range") if $red_exists;


my @overlap_redes=$gip->get_overlap_red("$ip_version","$client_id");
my @overlap_found = $gip->find_overlap_redes("$client_id","$red_nuevo","$BM_nuevo",\@overlap_redes,"$ip_version","$vars_file");

my $event;
my $i=0;
my @red_id_old;
my $new_range_audit;
my $red_id_nuevo;
my $keep_range = $daten{keep_range} || "n";
if ( $overlap_found[0] ) {
	$red_id_nuevo=$gip->get_last_red_num("$client_id");
	$red_id_nuevo++;
	foreach ( @overlap_found ) {
		if ( $_ eq $new_range ) { next; }
		my $red = "";
		if ( $ip_version eq "v4" ) {
			$_ =~ /^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\/\d{1,2}$/;
			$red = $1;
		} else {
			$_ =~ /^(\w+\:\w+\:\w+\:\w+\:\w+\:\w+\:\w+\:\w+)\/\d{1,3}$/;
			$red = $1;
		}
		my $red_id_old=$gip->get_red_id_from_red("$client_id","$red") || "";
		my @values_redes = $gip->get_red("$client_id","$red_id_old");
		my $BM_old_audit = "$values_redes[0]->[1]" || "";
		my $descr_old_audit = "$values_redes[0]->[2]" || "---";
		$descr_old_audit = "---" if $descr_old_audit eq "NULL";
		my $loc_old_audit=$gip->get_loc_from_redid("$client_id","$red_id_old");
		$loc_old_audit = "---" if $loc_old_audit eq "NULL";
		my $vigilada_old_audit = "$values_redes[0]->[4]" || "n";
		my $comentario_old_audit = "$values_redes[0]->[5]" || "---";
		$comentario_old_audit = "---" if $comentario_old_audit eq "NULL";
		my $cat_id_old_audit = "$values_redes[0]->[6]" || "---";
		my $cat_old_audit=$gip->get_cat_net_from_id("$client_id","$cat_id_old_audit");
		$cat_old_audit = "---" if $cat_old_audit eq "NULL";

		if ( $event ) {
			$event = $event . ";" . "$red/$BM_old_audit,$descr_old_audit,$loc_old_audit,$cat_old_audit,$comentario_old_audit,$vigilada_old_audit";
		} else {
			$event = "$red/$BM_old_audit,$descr_old_audit,$loc_old_audit,$cat_old_audit,$comentario_old_audit,$vigilada_old_audit";
		}

		if ( $keep_range eq "y" ) {
			$gip->update_red_id_ranges("$client_id","$red_id_old","$red_id_nuevo");
		} else {
			$gip->delete_range_red_id("$client_id","$red_id_old");
		}

		$gip->delete_red("$client_id","$red_id_old");
		$red_id_old[$i++]=$red_id_old;
	}
	my $new_range1=$new_range;
	my $descr = $daten{descr} || "NULL";
	my $loc_nuevo = $daten{loc} || "-1";
	my $loc_id_nuevo=$gip->get_loc_id("$client_id","$loc_nuevo") || "-1";
	my $cat_net_nuevo = $daten{cat_net} || "-1";
	my $cat_net_id_nuevo = $gip->get_cat_net_id("$client_id","$cat_net_nuevo") || "-1";
	my $vigilada = $daten{vigilada} || "n";
	$gip->print_error("$client_id","$$lang_vars{palabra_reservada_comment_NULL_message}") if $daten{'descr'} eq "NULL";
	my $comentario = $daten{comentario} || "NULL";
	my $keep_hosts = $daten{keep_hosts} || "n";
	my $comentario_audit = "";
	$comentario_audit = $comentario if $comentario;
	my $descr_audit=$descr;
	$comentario_audit="---" if $comentario_audit eq "NULL";
	$descr_audit="---" if $descr_audit eq "NULL";
	my $loc_nuevo_audit=$loc_nuevo;
	$loc_nuevo_audit="---" if $loc_nuevo_audit eq "-1";
	my $cat_net_nuevo_audit=$cat_net_nuevo;
	$cat_net_nuevo_audit="---" if $cat_net_nuevo_audit eq "-1";
	$new_range_audit="$new_range,$descr_audit,$loc_nuevo_audit,$cat_net_nuevo_audit,$comentario_audit,$vigilada";

	$gip->insert_net("$client_id","$red_id_nuevo","$red_nuevo","$BM_nuevo","$descr","$loc_id_nuevo","$vigilada","$comentario","$cat_net_id_nuevo","$ip_version") or die $gip->print_error("$client_id",$$lang_vars{algo_malo_message});
	foreach my $ele( @red_id_old ) {
		if ( $keep_hosts eq "y") {
			$gip->update_host_red_id_red_num("$client_id","$red_id_nuevo","$ele");
		} else {
			$gip->delete_red_ip("$client_id","$ele");
		}
	}
} else {
	$gip->print_error("$client_id",$$lang_vars{algo_malo_message});
}

my $audit_type="6";
my $audit_class="2";
my $update_type_audit="1";
$event=$event . " -> " . $new_range_audit;
$gip->insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");

print "<p><b>$$lang_vars{agregado_message}: $new_range</b>";

my $start_entry=0;

my @ip=$gip->get_redes("$client_id","","","","","red_auf","$ip_version_ele","$show_rootnet","$show_endnet","$hide_not_rooted");
my $anz_values_redes = scalar(@ip);
my $pages_links=$gip->get_pages_links_red("$client_id","$start_entry","$anz_values_redes","$entries_per_page","","","red_auf","","","$show_rootnet","$show_endnet","$hide_not_rooted");

$gip->PrintRedTabHead("$client_id","$vars_file","","$entries_per_page","$pages_links","","","$ip_version_ele","$show_rootnet","$show_endnet","$hide_not_rooted");

if ( @ip ) {
	my %changed_red_num;
	$changed_red_num{$red_id_nuevo}=$red_id_nuevo;
	$gip->PrintRedTab("$client_id",\@ip,"$vars_file","simple","","","","red_auf","","","","$show_rootnet","$show_endnet",\%changed_red_num,"","$hide_not_rooted");
} else {
	print "<p class=\"NotifyText\">$$lang_vars{no_resultado_message}</p><br>\n";
}

$gip->print_end("$client_id","$vars_file");
