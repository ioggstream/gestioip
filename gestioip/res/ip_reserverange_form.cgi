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
use lib '../modules';
use GestioIP;
use Math::BigInt;

my $daten=<STDIN>;
my $gip = GestioIP -> new();
my %daten=$gip->preparer($daten) if $daten;

my $base_uri = $gip->get_base_uri();
my $server_proto=$gip->get_server_proto();

my $lang = $daten{'lang'} || "";
my ($lang_vars,$vars_file)=$gip->get_lang("","$lang");

my $red_num = "";
$red_num=$daten{'red_num'} if $daten{'red_num'};

my $client_id = $daten{'client_id'} || $gip->get_first_client_id();
if ( $client_id !~ /^\d{1,4}$/ ) {
        $gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{reservar_rango_message}","$vars_file");
        print_error("1","$$lang_vars{client_id_invalid_message}");
}

if ( $red_num !~ /^\d{1,5}$/ ) {
        $gip->print_init("gestioip","$$lang_vars{reservar_rango_message}","$$lang_vars{reservar_rango_message}","$vars_file","$client_id");
        $gip->print_error("$client_id",$$lang_vars{formato_red_malo_message}) ;
}

my ($start_entry_hosts,$entries_per_page_hosts);
if ( $daten{'entries_per_page_hosts'} && $daten{'entries_per_page_hosts'} =~ /^\d{1,4}$/ ) {
        $entries_per_page_hosts=$daten{'entries_per_page_hosts'};
} else {
        $entries_per_page_hosts = "254";
}
if ( $daten{'start_entry_hosts'} && $daten{'start_entry_hosts'} =~ /^\d{1,40}$/ ) {
        $start_entry_hosts=$daten{'start_entry_hosts'};
} else {
        $start_entry_hosts="0";
}

my $text_field_number_given_form = "";
if ( defined($daten{'text_field_number_given'}) ) {
        $text_field_number_given_form="<input name=\"text_field_number_given\" type=\"hidden\" value=\"text_field_number_given\">";
}

my @values_redes = $gip->get_red("$client_id","$red_num");
my $red = "$values_redes[0]->[0]" || "";
my $BM = "$values_redes[0]->[1]" || "";
my $descr = "$values_redes[0]->[2]" || "";
my $comentario = "$values_redes[0]->[5]" || "";
my $ip_version = "$values_redes[0]->[7]" || "";

$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{reservar_rango_red_message} $red/$BM","$vars_file");

my $confirmation=$gip->get_config_confirmation("$client_id") || "yes";

print <<EOF;
<script type="text/javascript">
<!--
function confirmation() {
	var answer = confirm("$$lang_vars{delete_selected_range_message}")
	if (answer){
		return true;
	}
	else{
		return false;
	}
}
//-->
</script>
EOF

my $onclick = "";
if ( $confirmation eq "yes" ) {
        $onclick =  "onclick=\"return confirmation();\"";
}

$gip->print_error("$client_id","$$lang_vars{formato_malo_message}") if ( $daten{'referer'} !~ /^host_list_view|red_view$/ );
my $referer=$daten{'referer'};


my $start_entry=$daten{'start_entry'} || '0';
$gip->print_error("$client_id",$$lang_vars{formato_malo_message}) if $start_entry !~ /^\d{1,4}$/;
my $order_by=$daten{'order_by'} || "red_auf";

my @rangos = $gip->get_rangos("$client_id");

my $redob = $red . "/" . $BM;
my $ipob_red = new Net::IP ($redob) || die "Can not create ip object $redob: $!\n";
my $redint=($ipob_red->intip());
$redint = Math::BigInt->new("$redint");
my $first_ip_int = $redint + 1;
my $broad_ip_int = ($ipob_red->last_int());
$broad_ip_int = Math::BigInt->new("$broad_ip_int");
my $last_ip_int = $broad_ip_int - 1;
my @all_ip; 
my $j = "0";
for (my $i = $first_ip_int; $i <= $last_ip_int; $i++) {
	my $add=$gip->int_to_ip("$client_id","$i","$ip_version");	
	$all_ip[$j] = $add;
	$j++;
}

my @values_range_types=$gip->get_range_type();

print "<p><b>$$lang_vars{reservar_rango_message}</b><p>\n";
print "<p><table border=\"0\" cellpadding=\"4\" cellspacing=\"2\"><tr><td colspan=\"5\">";
print "$$lang_vars{reservar_rango_expl_message}<p></td></tr>\n";
print "<tr><td align=\"right\"><form name=\"add_reserverange_form\" method=\"POST\" action=\"$server_proto://$base_uri/res/ip_reserverange.cgi\">\n";
print "$$lang_vars{reservar_start_address_message}";
print "<td><select name=\"reserve_start_address\" size=\"5\">";
foreach (@all_ip) {
	print "<option>$_</option>\n";
}
print "</select></td>";

print "<td align=\"right\">$$lang_vars{reservar_end_address_message}</td>";
print "<td><select name=\"reserve_end_address\" size=\"5\">";
foreach (@all_ip) {
	print "<option>$_</option>\n";
}
print "</select></td><td width=\"17%\"></td></tr>";
print "<tr><td align=\"right\"><p><br>$$lang_vars{reservar_comment_message}</td>";
print "<td colspan=\"3\"><p><br><input name=\"comentario\" size=\"20\" maxlength=\"30\"></td></tr>\n";
print "<tr><td align=\"right\">$$lang_vars{tipo_rango_message}</td>";
print "<td><select name=\"range_type_id\" size=\"3\">";
$j=0;
foreach (@values_range_types) {
	print "<option value=\"$values_range_types[$j]->[1]\">$values_range_types[$j]->[0]</option>\n";
	$j++;
}
print "</select></td><td width=\"17%\"></td>";

print "<input name=\"red\" type=\"hidden\" value=\"$red/$BM\"><input name=\"start_entry\" type=\"hidden\" value=\"$start_entry\"><input name=\"referer\" type=\"hidden\" value=\"$referer\"><input name=\"order_by\" type=\"hidden\" value=\"$order_by\">\n";
print "<input name=\"adddel\" type=\"hidden\" value=\"add\"></tr>\n";
print "<tr><td colspan=\"2\"><br><input name=\"start_entry_hosts\" type=\"hidden\" value=\"$start_entry_hosts\"><input name=\"entries_per_page_hosts\" type=\"hidden\" value=\"$entries_per_page_hosts\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input name=\"ip_version\" type=\"hidden\" value=\"$ip_version\">$text_field_number_given_form<input type=\"submit\" value=\"$$lang_vars{crear_message}\" name=\"B2\" class=\"input_link_w\"></td></tr></form>\n";
print "</table>\n";
print "<p><br><p><br>\n";

print "<b>$$lang_vars{borrar_rango_message}</b><p>\n";
print "<p><table border=\"0\" cellpadding=\"2\" cellspacing=\"2\"><tr><td>";
$j=0;
my $k=0;
my @rangos_red;
if ( @rangos ) {
	foreach ( @rangos ) {
		if ( $rangos[$j]->[5] eq "$red_num" ) {
			$rangos_red[$k] = "<option value=\"$rangos[$j]->[0]\">" . $gip->int_to_ip("$client_id","$rangos[$j]->[1]","$ip_version") . "-" . $gip->int_to_ip("$client_id","$rangos[$j]->[2]","$ip_version") . " ($rangos[$j]->[3])</option>\n";
			$k++;
		}
		$j++;
	}
	if ( $rangos_red[0] ) {
		print "$$lang_vars{borrar_rango_expl_message}<p></td></tr>\n";
		print "<tr><td><form name=\"delete_reserverange_form\" method=\"POST\" action=\"$server_proto://$base_uri/res/ip_reserverange.cgi\">";
		print "<select name=\"range_id\" size=\"1\">";
		foreach ( @rangos_red ) {
			print "$_";
		}
		print "</select><input name=\"red\" type=\"hidden\" value=\"$red/$BM\"><input name=\"start_entry\" type=\"hidden\" value=\"$start_entry\"><input name=\"referer\" type=\"hidden\" value=\"$referer\"><input name=\"adddel\" type=\"hidden\" value=\"del\"><p></td></tr>\n";
		print "<tr><td colspan=\"2\"><input name=\"order_by\" type=\"hidden\" value=\"$order_by\"><input name=\"start_entry_hosts\" type=\"hidden\" value=\"$start_entry_hosts\"><input name=\"entries_per_page_hosts\" type=\"hidden\" value=\"$entries_per_page_hosts\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input name=\"ip_version\" type=\"hidden\" value=\"$ip_version\">$text_field_number_given_form<input type=\"submit\" value=\"$$lang_vars{borrar_message}\" name=\"B2\" class=\"input_link_w\" $onclick></form></td></tr>\n";
	} else {
		print "<i>$$lang_vars{no_rango_message}</i></form></td></tr>\n";
	}
} else {
	print "<i>$$lang_vars{no_rango_message}</i></form></td></tr>\n";
}
print "</table>\n";


print "<script type=\"text/javascript\">\n";
print "document.add_reserverange_form.reserve_start_address.focus();\n";
print "</script>\n";

$gip->print_end("$client_id","$vars_file");
