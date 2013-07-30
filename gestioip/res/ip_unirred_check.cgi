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
my %daten=$gip->preparer("$daten") if $daten;

my $base_uri = $gip->get_base_uri();
my $server_proto=$gip->get_server_proto();

my $lang = $daten{'lang'} || "";
my ($lang_vars,$vars_file)=$gip->get_lang("","$lang");

my $client_id = $daten{'client_id'} || $gip->get_first_client_id();
if ( $client_id !~ /^\d{1,4}$/ ) {
	$client_id = 1;
	$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{redes_message}","$vars_file");
	$gip->print_error("$client_id","$$lang_vars{formato_malo_message}");
}

my $ip_version_ele="";
$ip_version_ele=$daten{'ip_version_ele'} || $gip->get_ip_version_ele();

my $ip_version="";
if ( $ip_version_ele eq "v4" && ! $ip_version ) {
        $ip_version = "v4";
} elsif ( $ip_version_ele eq "v6" && ! $ip_version ) {
        $ip_version = "v6";
} elsif ( ! $ip_version ) {
        $ip_version = "v4";
}


$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{unir_redes_message}","$vars_file");

$gip->print_error("$client_id","$$lang_vars{formato_malo_message} $ip_version_ele (version_ele)") if $ip_version_ele !~ /^(v4|v6|46)$/;


my @values_locations=$gip->get_loc("$client_id");
my @values_utype=$gip->get_utype("$client_id");
my @values_cat_net=$gip->get_cat_net("$client_id");

# call from ip_unirred_check.cgi
if ( $daten{new_range} ) {

	my $comentario;

	if ( ! $daten{red1} || ! $daten{red2} || ! $daten{unirred} ) { $gip->print_error("$client_id",$$lang_vars{algo_malo_message}) };
	if ( $ip_version eq "v4" ) {
		if ( $daten{new_range} !~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\/\d{1,2}$/ ) { $gip->print_error("$client_id",$$lang_vars{check_new_rango_message}) };
		if ( $daten{red1} !~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\/\d{1,2}$/ ||  $daten{red2} !~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\/\d{1,2}$/ ) { $gip->print_error("$client_id",$$lang_vars{check_new_rango_message}) };
	} else {
		if ( $daten{new_range} !~ /^\w+\:\w+\:\w+\:\w+\:\w+\:\w+\:\w+\:\w+\/\d{1,3}$/ ) { $gip->print_error("$client_id",$$lang_vars{check_new_rango_message}) };
		if ( $daten{red1} !~ /^\w+\:\w+\:\w+\:\w+\:\w+\:\w+\:\w+\:\w+\/\d{1,3}$/ ||  $daten{red2} !~ /^\w+\:\w+\:\w+\:\w+\:\w+\:\w+\:\w+\:\w+\/\d{1,3}$/ ) { $gip->print_error("$client_id",$$lang_vars{check_new_rango_message}) };
	}
	my $new_range=$daten{new_range};
	my $red1=$daten{red1};
	my $red2=$daten{red2};
	my $new_range_o = new Net::IP ("$new_range") or $gip->print_error("$client_id","$$lang_vars{comprueba_red_BM_message}: <b>$new_range</b> (1)");
	my $new_range_last=$new_range_o->last_ip();
	my $new_range1=$new_range;
	my ($new_range_first,$new_BM_first);
	if ( $ip_version eq "v4" ) {
		$new_range1 =~ /^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\/(\d{1,2})$/;
		$new_range_first = $1;
		$new_BM_first = $2;
	} else {
		$new_range1 =~ /^(\w+\:\w+\:\w+\:\w+\:\w+\:\w+\:\w+\:\w+)\/(\d{1,3})$/;
		$new_range_first = $1;
		$new_BM_first = $2;
	}
	my @overlap_redes=$gip->get_overlap_red("$ip_version","$client_id");
	my @overlap_found = $gip->find_overlap_redes("$client_id","$new_range_first","$new_BM_first",\@overlap_redes,"$ip_version","$vars_file");

	if ( $overlap_found[0] ) {
		print "<p>$$lang_vars{rango_nuevo_message} $new_range ($new_range_first-$new_range_last) $$lang_vars{contieneria_message}:<p>\n";
		foreach ( @overlap_found ) {
			print "$_ <br>";
			my $red_new_ip;
			if ( $ip_version eq "v4" ) {
				$_ =~ /^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\/.+/;
				$red_new_ip = $1;
			} else {
				$_ =~ /^(\w+\:\w+\:\w+\:\w+\:\w+\:\w+\:\w+\:\w+)\/.+$/;
				$red_new_ip = $1;
			}
			my $red_num=$gip->get_red_id_from_red("$client_id","$red_new_ip") || "-1";
			my @values_redes = $gip->get_red("$client_id","$red_num");
			my $new_red_comentario = "$values_redes[0]->[5]" || "";
			if ( $comentario ) {
				$comentario = $comentario . " " . $new_red_comentario if $new_red_comentario;
			} else {
				$comentario = $new_red_comentario if $new_red_comentario;
			}
		}

		print "<p><br>$$lang_vars{si_bien_message} \"$$lang_vars{agregar_message}\" $$lang_vars{pulsar_message}<br>\n";


		my $color = "white";
		print "<form method=\"POST\" name=\"unirred2\" action=\"$server_proto://$base_uri/res/ip_unirred.cgi\">";
		print "<table border=\"0\" cellpadding=\"1\">\n";
		print "<tr><td><b>$$lang_vars{redes_message}</b></td><td><b>  $$lang_vars{description_message}</b></td><td><b>  $$lang_vars{loc_message}</b></td><td><b>$$lang_vars{cat_message}</b></td><td><b>$$lang_vars{comentario_message}</b></td><td><b>$$lang_vars{sinc_message}</b></td><td></td></tr>\n";
		print "<tr bgcolor=\"$color\" valign=\"top\"><td><b>$new_range &nbsp;</b></td>";
		print "<td><i><input type=\"text\" size=\"25\" name=\"descr\" value=\"\" maxlength=\"100\"></i></td><td><select name=\"loc\" size=\"1\">";
		print "<option></option>";

		my $j=0;
		foreach (@values_locations) {
			if ($values_locations[$j]->[0] eq "NULL") {
				$j++;
				next;
			}
			print "<option>$values_locations[$j]->[0]</option>";
			$j++;
		}
		print "</td><td>";
		print "<select name=\"cat_net\" size=\"1\">";
		print "<option></option>";
		$j=0;
		foreach (@values_cat_net) {
			if ($values_cat_net[$j]->[0] eq "NULL") {
				$j++;
				next;
			}
			print "<option>$values_cat_net[$j]->[0]</option>";
			$j++;
		}
		my ($form_red,$form_BM) = split("/",$new_range);
		print "</select></td><input name=\"BM\" type=\"hidden\" value=\"$form_BM\"><input name=\"red\" type=\"hidden\" value=\"$form_red\">";
		print "<td><textarea name=\"comentario\" cols=\"30\" rows=\"1\" wrap=\"physical\" maxlength=\"500\"></textarea>";
		print "</td>";

		print "<td><input type=\"checkbox\" name=\"vigilada\" value=\"y\"></td></tr>\n";
		print "</table>\n";


		print "<p><input type=\"hidden\" name=\"new_range\" value=\"$new_range\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"hidden\" name=\"ip_version\" value=\"$ip_version\"><input type=\"submit\" value=\"$$lang_vars{agregar_message}\" class=\"input_link_w\" name=\"B2\">&nbsp;&nbsp;&nbsp;&nbsp<input type=\"checkbox\" name=\"keep_hosts\" value=\"y\" checked><span class=\"HintText\"> $$lang_vars{dejar_host_message}</span>";
		print "&nbsp;&nbsp;&nbsp;&nbsp<input type=\"checkbox\" name=\"keep_range\" value=\"y\" checked><span class=\"HintText\"> $$lang_vars{dejar_reserved_range_message}</span>";
		print "</form>";
		print "<script type=\"text/javascript\">\n";
		print "document.unirred1.B2.focus();\n";
		print "</script>\n";
		print "<p><br><p><br>$$lang_vars{si_no_bien_message} $$lang_vars{rango_a_mano_message}<br>\n";
		print "<form method=\"POST\" name=\"new_range\" action=\"$server_proto://$base_uri/res/ip_unirred_check.cgi\"><input type=\"text\" name=\"new_range\" size=\"44\" maxlength=\"44\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"submit\" value=\"$$lang_vars{submit_message}\" class=\"input_link_w\"><input type=\"hidden\" name=\"red1\" value=\"$red1\"><input type=\"hidden\" name=\"red2\" value=\"$red2\"><input type=\"hidden\" name=\"unirred\" value=\"$daten{unirred}\"></form>\n";
	} else {
		print "<p>$$lang_vars{rango_nuevo_message} $new_range ($new_range_first-$new_range_last) $$lang_vars{no_contiene_redes_message} $red1, $red2<p>\n";
		print "$$lang_vars{otro_rango_message}:<br><form method=\"POST\" name=\"new_range_new\" action=\"$server_proto://$base_uri/res/ip_unirred_check.cgi\"><input type=\"text\" name=\"new_range\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"submit\" value=\"$$lang_vars{submit_message}\" class=\"input_link_w\"></form>\n";
		print "<script type=\"text/javascript\">";
		print "document.unirred.new_range_new.focus()";
		print "</script>";

	}

# call from ip_unirred_form.cgi
} else {
	if ( ! $daten{unirred} ) { $gip->print_error("$client_id",$$lang_vars{dos_checkboxes_message}) };
	my ($red1, $red2, $unirred_num_1, $unirred_num_2);
	if ( $ip_version eq "v4" ) {
		if ( $daten{unirred} =~ /^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\/\d{1,2})\s\d+$/ ) { $gip->print_error("$client_id",$$lang_vars{dos_checkboxes_message}) };
		if ( $daten{unirred} !~ /^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\/\d{1,2})\s(\d+)_(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\/\d{1,2})\s(\d+)$/ ) { $gip->print_error("$client_id","$$lang_vars{formato_red_malo_message} $daten{unirred}") };
		$red1 = $1;
		$red2 = $3;
		$unirred_num_1 = $2;
		$unirred_num_2 = $4;
	} else {
#		if ( $daten{new_range} =~ /^\w+\:\w+\:\w+\:\w+\:\w+\:\w+\:\w+\:\w+\/\d{1,3}\s\d+$/ ) { $gip->print_error("$client_id",$$lang_vars{dos_checkboxes_message}) };
		if ( $daten{unirred} !~ /^(\w+\:\w+\:\w+\:\w+\:\w+\:\w+\:\w+\:\w+\/\d{1,3})\s(\d+)_(\w+\:\w+\:\w+\:\w+\:\w+\:\w+\:\w+\:\w+\/\d{1,3})\s(\d+)$/ ) { $gip->print_error("$client_id",$$lang_vars{formato_red_malo_message}) };
		$red1 = $1;
		$red2 = $3;
		$unirred_num_1 = $2;
		$unirred_num_2 = $4;
	}

	my $comentario;
	for (my $k = $unirred_num_1; $k <= $unirred_num_2; $k++) {
		my $comentario_new;
		my $comentario_unirred_num = "comentario_" . $k;
		$comentario_new=$daten{$comentario_unirred_num} || "";
		if ( $comentario ) {
			$comentario = $comentario . " " . $comentario_new;
		} else {
			$comentario = $comentario_new;
		}
	}

	my $ip1o = new Net::IP ("$red1") or $gip->print_error("$client_id","$$lang_vars{comprueba_red_BM_message}: $red1 (2)");
	my $ip1=$ip1o->ip();
	my $ip2o = new Net::IP ("$red2") or $gip->print_error("$client_id","$$lang_vars{comprueba_red_BM_message}: $red2 (3)");
	my $ip2=$ip2o->last_ip();

	my ($ip_bin1, $ip_bin2);
	my @prefix;
	if ( $ip_version eq "v4" ) {
		$ip_bin1 = ip_iptobin ($ip1,4);
		$ip_bin2 = ip_iptobin ($ip2,4);
		@prefix = ip_range_to_prefix($ip_bin1,$ip_bin2,4);
	} else {
		$ip_bin1 = ip_iptobin ($ip1,6);
		$ip_bin2 = ip_iptobin ($ip2,6);
		@prefix = ip_range_to_prefix($ip_bin1,$ip_bin2,6);
	}

	my $out_red1=$prefix[0];
	if ( $prefix[1] ) {
		print "<p>$$lang_vars{no_agregar_message}:<p>$red1  + $red2 $$lang_vars{no_resulta_valida_message}<br>\n";
		print "<p><br>$$lang_vars{rango_a_mano_message}<br>\n";
		print "<form method=\"POST\" name=\"new_range\" action=\"$server_proto://$base_uri/res/ip_unirred_check.cgi\"><input type=\"text\" name=\"new_range\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"submit\" value=\"$$lang_vars{submit_message}\" class=\"input_link_w\"><input type=\"hidden\" name=\"red1\" value=\"$red1\"><input type=\"hidden\" name=\"red2\" value=\"$red2\"><input type=\"hidden\" name=\"unirred\" value=\"$daten{unirred}\"></form>\n";
		print "<script type=\"text/javascript\">";
		print "document.unirred.new_range.focus()";
		print "</script>";
		$gip->print_end("$client_id","$vars_file");
	}
	my ($in_ip1,$in_mask1)=split ("/", $red1);
	my ($out_ip1,$out_mask1)=split ("/", $out_red1);
	if ( $in_mask1 le $out_mask1 && ! $prefix[1] ) {
		print "<p>$$lang_vars{no_agregar_message}:<p>$red1  + $red2 $$lang_vars{no_resulta_valida_message}<br>\n";
		print "<p><br>$$lang_vars{rango_a_mano_message}<br>\n";
		print "<form method=\"POST\" name=\"new_range\" action=\"$server_proto://$base_uri/res/ip_unirred_check.cgi\"><input type=\"text\" name=\"new_range\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"submit\" value=\"$$lang_vars{submit_message}\" class=\"input_link_w\"><input type=\"hidden\" name=\"red1\" value=\"$red1\"><input type=\"hidden\" name=\"red2\" value=\"$red2\"><input type=\"hidden\" name=\"unirred\" value=\"$daten{unirred}\"></form>\n";
		print "<script type=\"text/javascript\">";
		print "document.unirred.new_range.focus()";
		print "</script>";
		$gip->print_end("$client_id","$vars_file");
	}

	my $new_range=$prefix[0];

	my $new_range_o = new Net::IP ("$new_range") or $gip->print_error("$client_id","$$lang_vars{comprueba_red_BM_message}: <b>$new_range</b>(4)");
	my $new_range_last=$new_range_o->last_ip();
	my $new_range1=$new_range;
	
	my ($new_range_first,$new_BM_first);
	if ( $ip_version eq "v4" ) {
		$new_range1 =~ /^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\/(\d{1,2})$/;
		$new_range_first = $1;
		$new_BM_first = $2;
	} else {
		$new_range1 =~ /^(\w+\:\w+\:\w+\:\w+\:\w+\:\w+\:\w+\:\w+)\/(\d{1,3})$/;
		$new_range_first = $1;
		$new_BM_first = $2;
	}

	my @overlap_redes=$gip->get_overlap_red("$ip_version","$client_id");
	my @overlap_found = $gip->find_overlap_redes("$client_id","$new_range_first","$new_BM_first",\@overlap_redes,"$ip_version","$vars_file");


	if ( $overlap_found[0] ) {
		print "<p>$$lang_vars{rango_nuevo_message} <b>$new_range</b> ($new_range_first-$new_range_last) $$lang_vars{contieneria_message}<p>";
		foreach ( @overlap_found ) {
			print "$_ <br>";
		}
		print "<p><br>$$lang_vars{si_bien_unir_message} \"$$lang_vars{agregar_message}\" $$lang_vars{pulsar_message}<p>\n";

		my $color = "white";
		print "<form method=\"POST\" name=\"unirred2\" action=\"$server_proto://$base_uri/res/ip_unirred.cgi\">";
		print "<table border=\"0\" cellpadding=\"1\">\n";
		print "<tr><td><b>$$lang_vars{redes_message}</b></td><td><b>  $$lang_vars{description_message}</b></td><td><b>  $$lang_vars{loc_message}</b></td><td><b>$$lang_vars{cat_message}</b></td><td><b>$$lang_vars{comentario_message}</b></td><td><b>$$lang_vars{sinc_message}</b></td><td></td></tr>\n";
		print "<tr bgcolor=\"$color\" valign=\"top\"><td><b>$new_range &nbsp;</b></td>";
		print "<td><i><input type=\"text\" size=\"25\" name=\"descr\" value=\"\" maxlength=\"100\"></i></td><td><select name=\"loc\" size=\"1\">";
		print "<option></option>";

		my $j=0;
		foreach (@values_locations) {
			if ($values_locations[$j]->[0] eq "NULL") {
				$j++;
				next;
			}
			print "<option>$values_locations[$j]->[0]</option>";
			$j++;
		}
		print "</td><td>";
		print "<select name=\"cat_net\" size=\"1\">";
		print "<option></option>";
		$j=0;
		foreach (@values_cat_net) {
			if ($values_cat_net[$j]->[0] eq "NULL") {
				$j++;
				next;
			}
			print "<option>$values_cat_net[$j]->[0]</option>";
			$j++;
		}
		my ($form_red,$form_BM) = split("/",$new_range);
		print "</select></td><input name=\"BM\" type=\"hidden\" value=\"$form_BM\"><input name=\"red\" type=\"hidden\" value=\"$form_red\">";
		print "<td><textarea name=\"comentario\" cols=\"30\" rows=\"1\" wrap=\"physical\" maxlength=\"500\"></textarea>";
		print "</td>";

		print "<td><input type=\"checkbox\" name=\"vigilada\" value=\"y\"></td></tr>\n";
		print "</table>\n";

		print "<input type=\"hidden\" name=\"new_range\" value=\"$new_range\"><p><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"hidden\" name=\"ip_version\" value=\"$ip_version\"><input type=\"submit\" value=\"$$lang_vars{agregar_message}\" class=\"input_link_w\" name=\"B2\">&nbsp;&nbsp;&nbsp;&nbsp<input type=\"checkbox\" name=\"keep_hosts\" value=\"y\" checked><span class=\"HintText\"> $$lang_vars{dejar_host_message}</span>";
		print "&nbsp;&nbsp;&nbsp;&nbsp<input type=\"checkbox\" name=\"keep_range\" value=\"y\" checked><span class=\"HintText\"> $$lang_vars{dejar_reserved_range_message}</span>";
		print "</form>";
		print "<script type=\"text/javascript\">\n";
		print "document.unirred2.B2.focus();\n";
		print "</script>\n";
		print "<p><br><p><br>$$lang_vars{si_no_bien_message} $$lang_vars{rango_a_mano_message}<br>\n";
		print "<form method=\"POST\" name=\"new_range\" action=\"$server_proto://$base_uri/res/ip_unirred_check.cgi\"><input type=\"text\" name=\"new_range\" size=\"44\" maxlength=\"44\"> <input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"submit\" value=\"$$lang_vars{submit_message}\" class=\"input_link_w\"><input type=\"hidden\" name=\"red1\" value=\"$red1\"><input type=\"hidden\" name=\"red2\" value=\"$red2\"><input type=\"hidden\" name=\"unirred\" value=\"$daten{unirred}\"></form>\n";
	} else {
		$gip->print_error("$client_id","$$lang_vars{rango_no_contiene_redes_message} $red1, $red2");
	}

}

$gip->print_end("$client_id","$vars_file");
