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
my ($lang_vars,$vars_file)=$gip->get_lang("","$lang");

my $red_num=$daten{red_num};

my $client_id = $daten{'client_id'} || $gip->get_first_client_id();
if ( $client_id !~ /^\d{1,4}$/ ) {
	$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{redes_message}","$vars_file");
        print_error("<b>ERROR</b><p>$$lang_vars{client_id_invalid_message}: $client_id","");
}

my $ip_version = $daten{'ip_version'} || "";

my @values_redes = $gip->get_red("$client_id","$red_num");
my $red = "$values_redes[0]->[0]" || "";
my $BM = "$values_redes[0]->[1]" || "";

my $redob = "$red/$BM";

$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{redes_message} $redob","$vars_file");
$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (1)") if $ip_version !~ /^(v4|v6)$/;

my $ipob_red = new Net::IP ($redob) || die "Can not create ip object $redob: $!\n";
my $redint=($ipob_red->intip());
my $class;
if ( $redint <= 2147483647 ) {
	$class = "A";
} elsif ( $redint >= 2147483648 && $redint <= 3221225471 ) {
	$class = "B";
} elsif ( $redint >= 3221225472 && $redint <= 3758096383 ) {
	$class = "C";
} elsif ( $redint >= 3758096384 && $redint <= 4160749567 ) {
	$class = "D";
} else {
	$class = "E";
}
my $type=($ipob_red->iptype());
my $mask=($ipob_red->mask());
my $hexip=($ipob_red->hexip());
my $hex = unpack('H*', "$red");
my $bin=($ipob_red->binip());
my $short=($ipob_red->short());
$short=$short . "/" . $BM;
my $broadcast=($ipob_red->last_ip());
my $first_ip_int=$redint+1;
my $first_ip = $gip->int_to_ip("$client_id","$first_ip_int","$ip_version");
my $last_ip_int = ($ipob_red->last_int());
my $ip_total=$last_ip_int-$first_ip_int;
$last_ip_int-- if $ip_version eq "v4";
my $last_ip = $gip->int_to_ip("$client_id","$last_ip_int","$ip_version");
my $wildcard="";
if ( $ip_version eq "v4" ) {
	$mask =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/;
	my $first_oc_wi = 255 - $1;
	my $sec_oc_wi = 255 - $2;
	my $thi_oc_wi = 255 - $3;
	my $fou_oc_wi = 255 - $4;
	$wildcard = $first_oc_wi . "." . "$sec_oc_wi" . "." . $thi_oc_wi . "." . $fou_oc_wi;
}
$hexip =~ /.x(.*)/;
my $v6=$1;
my $length_v6=length($v6);
$v6 = "0" . "$v6" if $length_v6 == 7;
$v6 =~ /(.{4})(.{4})/;
$v6="::ffff:" .  $1 . ":" . $2;

my $ip_ocu=$gip->count_host_entries("$client_id","$red_num");
my $free=$ip_total-$ip_ocu;
my ($free_calc,$percent_free,$ip_total_calc,$percent_ocu,$ocu_color);
if ( $free == 0 ) {
	$percent_free = '0%';
} elsif ( $free == $ip_total ) {
	$percent_free = '100%';
} else {
	$free_calc = $free . ".0";
	$ip_total_calc = $ip_total . ".0";
	$percent_free=100*$free_calc/$ip_total_calc;
	$percent_free =~ /^(\d+\.\d?).*/;
	$percent_free = $1 . '%';
}
if ( $ip_ocu == 0 ) {
	$percent_ocu = '0%';
	$ocu_color = "green";
} elsif ( $ip_ocu == $ip_total ) {
	$percent_ocu = '100%';
	$ocu_color = "red";
} else {
	$ip_total_calc = $ip_total . ".0";
	$percent_ocu=100*$ip_ocu/$ip_total_calc;
	if ( $percent_ocu =~ /e/ ) {
		$percent_ocu="0.1"
	} else {
		$percent_ocu =~ /^(\d+\.\d?).*/;
		$percent_ocu = $1;
	}
	if ( $percent_ocu >= 90 ) {
		$ocu_color = "red";
	} elsif ( $percent_ocu >= 80 ) {
		$ocu_color = "darkorange";
	} else {
		$ocu_color = "green";
	}
	$percent_ocu = $percent_ocu . '%';
}

my %rangos = $gip->get_rangos_hash("$client_id");

my @config = $gip->get_config("$client_id");
my $smallest_bm = $config[0]->[0] || "22";

my $ripe_type;
if ( $ip_version eq "v4" ) {
	$ripe_type="inetnum";
} else {
	$ripe_type="inet6num";
}
print "<a href=\"https://apps.db.ripe.net/whois/lookup/ripe/${ripe_type}/${red}\" class=\"input_link_w_right\" target=\"_blank\"><img src=\"./imagenes/ripe.png\"></a>\n";

print "<p><table border=\"0\" cellpadding=\"2\">";
#print "<tr><td align=\"right\" nowrap><a href=\"https://apps.db.ripe.net/whois/lookup/ripe/inetnum/${red}\" style=\"inputlinkw\" target=\"_blank\">RIPE</a></td></tr>\n";
print "<tr><td>$$lang_vars{clase_message}</td><td><b>$class</b></td></tr>\n" if $ip_version eq "v4";
print "<tr><td>$$lang_vars{tipo_message}</td><td><b>$type</b></td></tr>\n";
print "<tr><td>$$lang_vars{redes_message}</td><td><b>$red</b></td></tr>\n";
print "<tr><td>$$lang_vars{bitmask_message}</td><td><b>$BM</b></td></tr>\n" if $ip_version eq "v4";
print "<tr><td>$$lang_vars{prefix_length_message}</td><td><b>$BM</b></td></tr>\n" if $ip_version eq "v6";
print "<tr><td>$$lang_vars{netmask_message}</td><td><b>$mask</b></td></tr>\n" if $ip_version eq "v4";
print "<tr><td>$$lang_vars{wildcardmask_message}</td><td><b>$wildcard</b></td></tr>\n" if $ip_version eq "v4";
print "<tr><td>$$lang_vars{broadcast_message}</td><td><b>$broadcast</b></td></tr>\n" if $ip_version eq "v4";
if ( $BM == "32" ) {
	print "<tr><td>$$lang_vars{host_range_message}</td><td><font color=\"gray\"><b>N/A</b></font></td></tr>\n";
} else {
	print "<tr><td>$$lang_vars{host_range_message}</td><td><b>$first_ip -<br>$last_ip</b></td></tr>\n";
}
print "<tr><td><br></td></tr>\n";
if ( $BM == "32" ) {
	print "<tr><td>$$lang_vars{ip_en_total_message}</td><td><b>0</b></td></tr>\n";
} else {
	print "<tr><td>$$lang_vars{ip_en_total_message}</td><td><b>$ip_total</b></td></tr>\n";
}
if ( $BM >= $smallest_bm && $BM != "32" ) {
	print "<tr><td>$$lang_vars{ip_ocu_message}</td><td><font color=\"$ocu_color\"><b>$ip_ocu ($percent_ocu)</b></font></td></tr>\n";
	print "<tr><td>$$lang_vars{ip_libres_message}</td><td><font color=\"$ocu_color\"><b>$free ($percent_free)</b></font></td></tr>\n";
} else {
	print "<tr><td>$$lang_vars{ip_ocu_message}</td><td><font color=\"gray\"><b>N/A</b></font></td></tr>\n";
	print "<tr><td>$$lang_vars{ip_libres_message}</td><td><font color=\"gray\"><b>N/A</b></font></td></tr>\n";
}
print "<tr><td><br></td><td></td></tr>\n";
if ( $rangos{$red_num} ) {
	$rangos{$red_num} =~ s/\[//g;
	$rangos{$red_num} =~ s/\]//g;
	$rangos{$red_num} =~ s/-/ - /g;
	print "<tr><td>$$lang_vars{rangos_reservados_message}</td><td><b>$rangos{$red_num}</b></td></tr>\n";
	print "<tr><td><br></td><td></td></tr>\n";
}
print "<tr><td>$$lang_vars{corto_message}</td><td><b>$short</b></td></tr>\n";
print "<tr><td>$$lang_vars{int_id_message}</td><td><b>$redint</b></td></tr>\n";
print "<tr><td>$$lang_vars{hex_id_message} I</td><td><b>$hexip</b></td></tr>\n";
print "<tr><td>$$lang_vars{hex_id_message} II</td><td><b>$hex</b></td></tr>\n";
print "<tr><td>$$lang_vars{bin_id_message}</td><td><b>$bin</b></td></tr>\n";
print "<tr><td>$$lang_vars{mapeada_message}</td><td><b>$v6</b></td></tr>\n" if $ip_version eq "v4";
print "</table>\n";
print "<p><br><p><FORM><INPUT TYPE=\"BUTTON\" VALUE=\"$$lang_vars{atras_message}\" ONCLICK=\"history.go(-1)\" class=\"error_back_link\"></FORM>";

$gip->print_end("$client_id","$vars_file");
