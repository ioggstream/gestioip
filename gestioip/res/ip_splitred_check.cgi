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
use Math::BigInt;


my $daten=<STDIN>;
my $gip = GestioIP -> new();
my %daten=$gip->preparer($daten);

my $base_uri = $gip->get_base_uri();
my ($lang_vars,$vars_file)=$gip->get_lang();
my $server_proto=$gip->get_server_proto();

my $client_id = $daten{'client_id'} || $gip->get_first_client_id();
if ( $client_id !~ /^\d{1,4}$/ ) {
        $client_id = 1;
        $gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{redes_message}","$vars_file");
        $gip->print_error("$client_id","$$lang_vars{formato_malo_message}");
}

my $ip_version_ele = $daten{'ip_version_ele'} || "";
my $ip_version = $daten{'ip_version'} || "";

my $red = "";
$red=$daten{'red'} if $daten{'red'};

if ( $ip_version eq "v4" && $red !~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\/\d{1,2}$/ ) {
        $gip->print_init("gestioip","$$lang_vars{split_red_message}","$$lang_vars{split_red_message}","$vars_file","$client_id");
        $gip->print_error("$client_id","$$lang_vars{formato_ip_malo_message}");
} elsif ( $ip_version eq "v6" && $red !~ /^(\w+\:\w+\:\w+\:\w+\:\w+\:\w+\:\w+\:\w+)\/\d{1,3}$/ ) {
        $gip->print_init("gestioip","$$lang_vars{split_red_message}","$$lang_vars{split_red_message}","$vars_file","$client_id");
        $gip->print_error("$client_id","$$lang_vars{formato_ip_malo_message}");
}

$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{split_red_message} $red","$vars_file");

$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (version_ele)") if $ip_version_ele !~ /^(v4|v6|46)$/;
$gip->print_error("$client_id","$$lang_vars{formato_malo_message} ") if $ip_version !~ /^(v4|v6)$/;

my ($keep_loc,$keep_cat);
$keep_loc=$daten{keep_loc} if $daten{keep_loc};
$keep_loc="n" if ! $keep_loc;
$keep_cat=$daten{keep_cat} if $daten{keep_cat};
$keep_cat="n" if ! $keep_cat;
$gip->print_error("$client_id","$$lang_vars{formato_malo_message}: $keep_loc") if $keep_loc !~ /^y|n$/;
$gip->print_error("$client_id","$$lang_vars{formato_malo_message}: $keep_cat") if $keep_cat !~ /^y|n$/;

my $start_entry=$daten{'start_entry'} || '0';
$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (1)") if $start_entry !~ /^\d{1,4}$/;
my $order_by=$daten{'order_by'} || 'red_auf';

if ( $daten{'split_type'} ne "same_bm" && $daten{'split_type'} ne "different_bm" ) { $gip->print_error("$client_id","$$lang_vars{formato_malo_message}"); }
my $split_type = $daten{'split_type'};
my $loc = $daten{'loc'} || "NULL";
my $cat = $daten{'cat'} || "NULL";

my $bitmasks;
if ( $split_type eq "same_bm" ) {
	$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (2) $daten{'new_bm'}") if $daten{'new_bm'} !~ /^\d{1,4}:\d{1,8}$/;
	$daten{'new_bm'} =~ /^(\d{1,4}):(\d{1,8})$/;
	my $new_bm=$1;
	my $anz_redes=$2;
	$bitmasks="/$new_bm" x $anz_redes;
} elsif ( $split_type eq "different_bm" ) {
	if ( ! $daten{'bitmasks'} ) { $gip->print_error("$client_id","no bitmasks"); }
	$daten{bitmasks} =~ s/[\r\f\n\t\s]//g;
	if ( $daten{bitmasks} !~ /^(\/\d{1,3}){2,}$/ ) { $gip->print_error("$client_id","$$lang_vars{bitmasks_malo_message}") };
	if ( $ip_version eq "v4" ) {
		if ( $daten{red} !~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\/\d{1,2}$/ ) { $gip->print_error("$client_id",$$lang_vars{formato_red_malo_message}) };
	} else {
		if ( $daten{red} !~ /^(\w+\:\w+\:\w+\:\w+\:\w+\:\w+\:\w+\:\w+)\/(\d{1,3})$/ ) { $gip->print_error("$client_id",$$lang_vars{formato_red_malo_message}) };
	}
	$bitmasks = $daten{bitmasks};
} else {
	gip->print_error("$client_id","$$lang_vars{formato_malo_message}");
}

$bitmasks =~ s/^\///;
my @bitmasks=split('/',$bitmasks);
my $anz_bitmasks=@bitmasks;

$gip->print_error("$client_id","$$lang_vars{max_split_50_message}") if $anz_bitmasks > 50;


my $redm = $red;
my ( $first_red_id, $red_bm);
if ( $ip_version eq "v4" ) {
	$redm =~ /(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\/(\d{1,2})/;
	$first_red_id=$1;
	$red_bm = $2;
} else {
	$redm =~ /^(\w+\:\w+\:\w+\:\w+\:\w+\:\w+\:\w+\:\w+)\/(\d{1,3})$/;
	$first_red_id=$1;
	$red_bm = $2;
}
my $redob_orig = "$first_red_id/$red_bm";
my $redob = "$first_red_id/$bitmasks[0]";
my $i=1;
my @new_redes;
$new_redes[0]=$redob;
my $bm_mess="$bitmasks[0]";
my $ipob_orig = new Net::IP ($redob_orig) or $gip->print_error("$client_id","$redob_orig - $$lang_vars{algo_malo_message}");
my $last_ip_int_orig = ($ipob_orig->last_int());
my $last_ip_orig = $gip->int_to_ip("$client_id","$last_ip_int_orig","$ip_version");
my $last_ip_int_new;
foreach (@bitmasks) {
	if ( $_ <= $red_bm ) { $gip->print_error("$client_id","$$lang_vars{bitmasks_grande_message}")};
	if ( $ip_version eq "v4" ) {
#		if ( $_ >= 31 ) { $gip->print_error("$client_id","$$lang_vars{no_bm_31_message}: $_") };
		if ( $_ > 32 ) { $gip->print_error("$client_id","$$lang_vars{no_bm_33_message}: $_") };
	} else {
#		if ( $_ >= 127 ) { $gip->print_error("$client_id","$$lang_vars{no_bm_127_message}: $_") };
		if ( $_ > 128 ) { $gip->print_error("$client_id","$$lang_vars{no_bm_129_message}: $_") };
	}
	my $ipob = new Net::IP ($redob) or $gip->print_error("$client_id","$red - /$bitmasks<p>$bm_mess... - $$lang_vars{rangos_malos_message}:<p> $$lang_vars{primero_rango_malo_message}: <b>$redob</b>");
	my $last_ip_int = ($ipob->last_int());
	$last_ip_int = Math::BigInt->new("$last_ip_int");
	my $first_ip_int = $last_ip_int + 1;
	my $first_ip=$gip->int_to_ip("$client_id","$first_ip_int","$ip_version");
	$new_redes[$i]="$first_ip/$bitmasks[$i]" if ( $bitmasks[$i] );
	$redob = $new_redes[$i] if ( $bitmasks[$i] );
	$bm_mess =~ s/<.*><u>//;
	$bm_mess =~ s/<.*>//;
	$bm_mess="$bm_mess/<font color=\"red\"><u>$bitmasks[$i]</u></font>" if ( $bitmasks[$i] );
	if ( $first_ip_int gt $last_ip_int_orig ) { $gip->print_error("$client_id","$$lang_vars{no_todas_redes_incluidas_message}<p>$bm_mess... - $$lang_vars{rangos_malos_message}<p> $$lang_vars{primero_rango_malo_message}: <b>$redob</b>") if ( $bitmasks[$i] ) };
	$last_ip_int_new = $last_ip_int;
	$i++;
}
print "<p><b>$red - /$bitmasks</b><p> $$lang_vars{dividir_message}<p>";
my $new_redes="";
foreach (@new_redes) {
	print "$_<br>" if $_;
	if ( $new_redes ) {
		$new_redes="$new_redes" . "-" . "$_" if $_;
	} else {
		$new_redes="$_" if $_;
	}
}


my @values_locations=$gip->get_loc("$client_id");
my @values_utype=$gip->get_utype("$client_id");
my @values_cat_net=$gip->get_cat_net("$client_id");

print "<p><br>$$lang_vars{si_bien_message} \"$$lang_vars{split_message}\" $$lang_vars{pulsar_message}<p>\n";
print "<form name=\"splitred\" method=\"POST\" action=\"$server_proto://$base_uri/res/ip_splitred.cgi\">\n";
print "<table border=\"0\" cellpadding=\"1\">\n";
print "<tr><td><b>$$lang_vars{redes_message}</b></td><td><b>  $$lang_vars{description_message}</b></td><td><b>  $$lang_vars{loc_message}</b></td><td><b>$$lang_vars{cat_message}</b></td><td><b>$$lang_vars{comentario_message}</b></td><td><b>$$lang_vars{sinc_message}</b></td><td></td></tr>\n";

my $k = "0";
foreach (@new_redes) {
	my ($form_red, $form_BM) = split("/",$_) if $_;
	next if ! $form_red;
	my $color = "white";

	print "<tr bgcolor=\"$color\" valign=\"top\"><td><b>$form_red/$form_BM &nbsp;</b></td>";
	print "<td><i><input type=\"text\" size=\"25\" name=\"descr_$k\" value=\"\" maxlength=\"100\"></i></td><td><select name=\"loc_$k\" size=\"1\">";
	print "<option></option>";

	my $j=0;
	foreach (@values_locations) {
		if ($values_locations[$j]->[0] eq "NULL") {
			$j++;
			next;
		}
		if ( $values_locations[$j]->[0] eq $loc ) {
			if ( $keep_loc eq "y" ) {
				print "<option selected>$values_locations[$j]->[0]</option>";
			} else {
				print "<option>$values_locations[$j]->[0]</option>";
			}
		} else {
			print "<option>$values_locations[$j]->[0]</option>";
		}
		$j++;
	}
	print "</td><td>";
	print "<select name=\"cat_net_$k\" size=\"1\">";
	print "<option></option>";
	$j=0;
	foreach (@values_cat_net) {
		if ($values_cat_net[$j]->[0] eq "NULL") {
			$j++;
			next;
		}
		if ( $values_cat_net[$j]->[0] eq "$cat" ) {
			if ( $keep_cat eq "y" ) {
				print "<option selected>$values_cat_net[$j]->[0]</option>";
			} else {
				print "<option>$values_cat_net[$j]->[0]</option>";
			}
		} else {
			print "<option>$values_cat_net[$j]->[0]</option>";
		}
		$j++;
	}

	print "</select></td><input name=\"BM_$k\" type=\"hidden\" value=\"$form_BM\"><input name=\"red_$k\" type=\"hidden\" value=\"$form_red\">";
	print "<td><textarea name=\"comentario_$k\" cols=\"30\" rows=\"1\" wrap=\"physical\" maxlength=\"500\"></textarea>";
	print "</td>";

	print "<td><input type=\"checkbox\" name=\"vigilada_$k\" value=\"y\"></td></tr>\n";
	$k++;
}
print "</table>\n";



if ( $last_ip_int_orig > $last_ip_int_new ) {
	my $last_ip_new=$gip->int_to_ip("$client_id","$last_ip_int_new","$ip_version");
	print "<p><br><i><b>$$lang_vars{aviso_message}</b><p>$$lang_vars{subredes_nuevas_no_include_message}:<p>$$lang_vars{rango_red_original_message}: $first_red_id-$last_ip_orig<br>$$lang_vars{rangos_subredes_nuevas_message}: $first_red_id-$last_ip_new\n";
	$last_ip_int_new = Math::BigInt->new("$last_ip_int_new");
	my $first_drop_ip_int=$last_ip_int_new + 1;
	my $first_drop_ip=$gip->int_to_ip("$client_id","$first_drop_ip_int","$ip_version");
	print "<p>$$lang_vars{direcciones_de_message} $first_drop_ip $$lang_vars{a_message} $last_ip_orig $$lang_vars{se_borra_message}</i>";
	print "<p><br>\n";
}

print "<input name=\"red\" type=\"hidden\" value=\"$red\">\n";
print "<input name=\"new_redes\" type=\"hidden\" value=\"$new_redes\"><input name=\"start_entry\" type=\"hidden\" value=\"$start_entry\"><input name=\"order_by\" type=\"hidden\" value=\"$order_by\">\n";
print "<p><br><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input name=\"ip_version\" type=\"hidden\" value=\"$ip_version\"><input name=\"ip_version_ele\" type=\"hidden\" value=\"$ip_version_ele\"><input type=\"submit\" value=\"$$lang_vars{split_message}\" name=\"B2\" class=\"input_link_w\">&nbsp;&nbsp;&nbsp;&nbsp<input type=\"checkbox\" name=\"keep_hosts\" value=\"y\" checked> <span class=\"HintText\">$$lang_vars{dejar_host_message}</span><p><span class=\"HintText\"> ($$lang_vars{no_se_mantiene_rangos_message})</span></form>\n";

print "<script type=\"text/javascript\">\n";
print "document.splitred.B2.focus();\n";
print "</script>\n";

$gip->print_end("$client_id","$vars_file");
