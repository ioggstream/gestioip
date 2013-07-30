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
use DBI;
use lib './modules';
use GestioIP;

my $daten=<STDIN>;
my $gip = GestioIP -> new();
my %daten=$gip->preparer("$daten") if $daten;

my $lang = $daten{'lang'} || "";
my ($lang_vars,$vars_file,$entries_per_page)=$gip->get_lang("","$lang");
my $base_uri = $gip->get_base_uri();

my $client_id = $daten{'client_id'} || $gip->get_first_client_id();
my $server_proto=$gip->get_server_proto();

if ( $daten{'client_id'} !~ /^\d{1,4}$/ ) {
                $gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{down_networks_message}","$vars_file");
                $gip->print_error("$client_id","$$lang_vars{formato_malo_message} (1)");
}

my $ipv4=$daten{'ipv4'} || "";
my $ipv6=$daten{'ipv6'} || "";


$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{down_networks_message}","$vars_file");

if ( $daten{'down_hosts'} ) {
	$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (2)") if $daten{'down_hosts'} ne "down" && $daten{'down_hosts'} ne "down_and_never_checked";
}

my $down_hosts=$daten{'down_hosts'};

my $which_version = "";
if ( $ipv4 && ! $ipv6 ) {
	$which_version = "v4";
} elsif ( ! $ipv4 && $ipv6 ) {
	$which_version = "v6";
}


my @down_host_redes_ids;
if ( $down_hosts eq "down" ) {
	@down_host_redes_ids=$gip->search_net_hosts_down("$client_id","$which_version");
} else {
	@down_host_redes_ids=$gip->search_net_hosts_down_never_checked("$client_id","$which_version");
}
if ( ! $down_host_redes_ids[0] ) {
	print "<p class=\"NotifyText\">$$lang_vars{no_resultado_message}</p><br>\n";
	print "<FORM><INPUT TYPE=\"BUTTON\" VALUE=\"$$lang_vars{atras_message}\" ONCLICK=\"history.go(-1)\" class=\"error_back_link\"></FORM>\n";
	$gip->print_end("$client_id");
}

my $redes_hash=$gip->get_redes_hash("$client_id");

print "<p>\n";
print "<table border=\"0\" style=\"border-collapse:collapse\" cellpadding=\"2\">\n";
print "<tr></td><td><b>&nbsp;&nbsp;&nbsp;$$lang_vars{redes_message}</b></td><td>&nbsp;&nbsp;&nbsp;<b>$$lang_vars{BM_message}</bm></td><td><b>&nbsp;&nbsp;&nbsp;$$lang_vars{description_message}</b></td><td><b>&nbsp;&nbsp;&nbsp;$$lang_vars{loc_message} </b></td><td><b>&nbsp;&nbsp;&nbsp;$$lang_vars{cat_message} </b></td><td><b>&nbsp;&nbsp;&nbsp;$$lang_vars{comentario_message} </b></td><td><b>&nbsp;&nbsp;&nbsp;$$lang_vars{sinc_message}</b></td><td></td></tr>\n";

my $color_helper="0";
my ( $red_num,$color,$stylename);
my ( $keys, $value );
$stylename="show_detail";

my $j ="0";
foreach (  @down_host_redes_ids ) {
	my $red_num = $down_host_redes_ids[$j]->[0];

	my $red=$redes_hash->{"$red_num"}[0];
	my $BM=$redes_hash->{"$red_num"}[1];
	my $descr=$redes_hash->{"$red_num"}[2] || "";
	my $loc=$redes_hash->{"$red_num"}[3] || "";
	my $cat=$redes_hash->{"$red_num"}[4] || "";
	my $vigilada=$redes_hash->{"$red_num"}[5] || "";
	my $comentario=$redes_hash->{"$red_num"}[6] || "";
	my $ip_version=$redes_hash->{"$red_num"}[7] || "";
	$cat = "" if $cat eq "NULL";
	$loc = "" if $loc eq "NULL";
	$descr = "" if $descr eq "NULL";
	$comentario = "" if $comentario eq "NULL";
	my $sinc = "";
	$sinc = "x" if $vigilada eq "y";

	my $form_name = "document.forms.list_host" . $j . ".submit()";
 
	if ( $color_helper eq "0" ) {
		$color="#f2f2f2";
		$color_helper="1";
	} else {
		$color="white";
		$color_helper="0";
	}

	print "<tr bgcolor=\"$color\" class=\"$stylename\" onClick=\"$form_name\" style=\"cursor:pointer;\"><td>&nbsp;&nbsp;&nbsp;$red</td><td>&nbsp;&nbsp;&nbsp;$BM</td><td>&nbsp;&nbsp;&nbsp;$descr</td><td>&nbsp;&nbsp;&nbsp;$loc</td><td>&nbsp;&nbsp;&nbsp;$cat</td><td>&nbsp;&nbsp;&nbsp;$comentario</td><td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;$sinc</td><td><form method=\"POST\" name=\"list_host$j\" action=\"$server_proto://$base_uri/ip_show.cgi\"><input name=\"red_num\" type=\"hidden\" value=\"$red_num\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input name=\"ip_version\" type=\"hidden\" value=\"$ip_version\"></form></td></tr>";
	$j++;
    
}
print "</table>\n";

$gip->print_end("$client_id");
