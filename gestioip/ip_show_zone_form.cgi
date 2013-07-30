#!/usr/bin/perl -w -T

# Copyright (C) 2012 Marc Uebel

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
use POSIX qw(strftime);
use lib './modules';
use GestioIP;


my $gip = GestioIP -> new();
my $daten=<STDIN>;
my %daten=$gip->preparer($daten);

my $server_proto=$gip->get_server_proto();

my $lang = $daten{'lang'} || "";
my ($lang_vars,$vars_file)=$gip->get_lang("","$lang");
my $base_uri = $gip->get_base_uri();


my $client_id = $daten{'client_id'} || $gip->get_first_client_id();
$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{dns_zone_files_message}","$vars_file");

my $align="align=\"right\"";
my $align1="";
my $ori="left";
my $rtl_helper="<font color=\"white\">x</font>";
if ( $vars_file =~ /vars_he$/ ) {
	$align="align=\"left\"";
	$align1="align=\"right\"";
	$ori="right";
}

my $red_num=$daten{'red_num'} || $gip->print_error("$client_id","$$lang_vars{formato_malo_message} (1)");
my $ip_version=$daten{'ip_version'} || "";
$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (2)") if $ip_version !~ /^(v4|v6)$/;

my @red=();
@red=$gip->get_red("$client_id","$red_num");

my $red=$red[0]->[0];
my $BM=$red[0]->[1];
my $rootnet=$red[0]->[9];


print <<EOF;

<script type="text/javascript">
<!--
function checkRefresh() {
  document.forms.show_zone_form.server_type.selectedIndex="0";
  document.getElementById('create_generic_check').checked=false;
  document.getElementById('Hide3').innerHTML = "<font color=\\\"gray\\\">$$lang_vars{all_addresses_message}</font>";
  document.getElementById('Hide4').innerHTML = "<input type=\\\"radio\\\" name=\\\"create_generic\\\" id=\\\"create_generic\\\" value=\\\"all\\\" disabled>";
  document.getElementById('Hide5').innerHTML = "<font color=\\\"gray\\\">$$lang_vars{free_addresses_message}</font>";
  document.getElementById('Hide6').innerHTML = "<input type=\\\"radio\\\" name=\\\"create_generic\\\" id=\\\"create_generic\\\" value=\\\"free\\\" disabled>";
//  document.show_zone_form.create_generic.disabled = true;
}
-->
</script>

<script type="text/javascript">
<!--
function changeText1(value){
  if( value == "BIND" ) {
    document.getElementById('Hide7').innerHTML = "$$lang_vars{create_reverse_zone_files_all_message}";
    document.getElementById('Hide8').innerHTML = "<input type=\\\"checkbox\\\" name=\\\"all_reverse_zones\\\" id=\\\"all_reverse_zones\\\" value=\\\"yes\\\">";
  } else {
    document.getElementById('Hide7').innerHTML = "$$lang_vars{create_SOA_records_all_message}";
//    document.getElementById('Hide8').innerHTML = "";
  }
}
-->
</script>

<script type="text/javascript">
<!--
function changeText2(){
  if( document.getElementById('create_generic_check').checked==true  ) {
//    document.show_zone_form.create_generic.disabled = false;
//    document.getElementById('create_generic').disabled = false;
    document.show_zone_form.create_generic[0].disabled = false;
    document.show_zone_form.create_generic[1].disabled = false;
    document.show_zone_form.create_generic[0].checked = true;
    document.getElementById('Hide3').innerHTML = "$$lang_vars{all_addresses_message}";
    document.getElementById('Hide5').innerHTML = "$$lang_vars{free_addresses_message}";
  } else {
    document.show_zone_form.create_generic[0].checked = false;
    document.show_zone_form.create_generic[1].checked = false;
    document.show_zone_form.create_generic.disabled = true;
    document.getElementById('Hide3').innerHTML = "<font color=\\\"gray\\\">$$lang_vars{all_addresses_message}</font>";
    document.getElementById('Hide5').innerHTML = "<font color=\\\"gray\\\">$$lang_vars{free_addresses_message}</font>";
  }
}
-->
</script>

EOF

my $datetime=time();
my $serial = strftime "%Y%m%d", localtime($datetime);
$serial.="01";

print "<br><b>$$lang_vars{redes_message} $red/$BM</b><p>\n";
print "<p>\n";
print "<form name=\"show_zone_form\" method=\"POST\" action=\"$server_proto://$base_uri/ip_show_zone.cgi\"><br>\n";
print "<table border=\"0\" cellpadding=\"5\" cellspacing=\"2\">\n";


print "<tr><td $align>$$lang_vars{dns_server_type_message_zone_file_message}</td><td><select name=\"server_type\" id=\"server_type\" size=\"1\" onchange=\"changeText1(this.value);\">";
my @server_types=("BIND","tinydns");
foreach (@server_types) {
        print "<option>$_</option>\n";
}
print "</select></td></tr>\n";


print "<tr><td $align>$$lang_vars{domain_message}</td><td $align1><input name=\"domain\" type=\"text\"  size=\"15\" maxlength=\"100\" value=\"\"></td></tr>\n";
print "<tr><td $align>$$lang_vars{serial_message}</td><td $align1><input name=\"serial\" type=\"text\"  size=\"8\" maxlength=\"20\" value=\"$serial\"></td></tr>\n";
print "<tr><td $align>$$lang_vars{refresh_message}</td><td $align1><input name=\"refresh\" type=\"text\" size=\"8\" maxlength=\"20\" value=\"24h\"></td></tr>\n";
print "<tr><td $align>$$lang_vars{retry_message}</td><td $align1><input name=\"retry\" type=\"text\" size=\"8\" maxlength=\"20\" value=\"2h\"></td></tr>\n";
print "<tr><td $align>$$lang_vars{expire_message}</td><td $align1><input name=\"expire\" type=\"text\" size=\"8\" maxlength=\"20\" value=\"1000h\"></td></tr>\n";
print "<tr><td $align>$$lang_vars{minimum_message}</td><td $align1><input name=\"minimum\" type=\"text\" size=\"8\" maxlength=\"20\" value=\"2d\"></td></tr>\n";
print "<tr><td $align>TTL</td><td $align1><input name=\"TTL\" type=\"text\" size=\"8\" maxlength=\"20\" value=\"1h\"></td></tr>\n";
print "<tr><td $align>Nameserver<br>(master)</td><td $align1><input name=\"nameserver1\" type=\"text\" size=\"20\" maxlength=\"50\" value=\"\"></td></tr>\n";
print "<tr><td $align>Nameserver<br>(slave)</td><td $align1><input name=\"nameserver2\" type=\"text\" size=\"20\" maxlength=\"50\" value=\"\"></td></tr>\n";
#print "<tr><td $align>Nameserver III</td><td $align1><input name=\"nameserver3\" type=\"text\" size=\"20\" maxlength=\"50\" value=\"\"></td></tr>\n";
print "<tr><td $align>Mailserver I</td><td $align1><input name=\"mailserver1\" type=\"text\" size=\"20\" maxlength=\"50\" value=\"\"></td></tr>\n";
print "<tr><td $align>Mailserver II</td><td $align1><input name=\"mailserver2\" type=\"text\" size=\"20\" maxlength=\"50\" value=\"\"></td></tr>\n";

#if ($BM ne 8 && $BM ne 16 && $BM ne 24 && $ip_version eq "v4" ) {
#	print "<tr><td $align colspan=\"2\"><br></td>\n";
#	print "<tr><td $align colspan=\"2\">$$lang_vars{mask_on_non_octet_boundary_message}: $red/<b>$BM</b><br></td></tr>\n";
#	print "<tr><td $align>$$lang_vars{delegate_zone_to_dedicated_server}</td><td $align1><input type=\"checkbox\" name=\"dedicated_server\" value=\"yes\"></td></tr>\n";
#}

	print "<tr><td $align>$$lang_vars{ignore_unknown_entries_message}</td><td $align1><input type=\"checkbox\" name=\"ignore_unknown\" value=\"yes\" checked></td></tr>\n";
		print "<tr><td $align>$$lang_vars{ignore_out_of_zone_data_message}</td><td $align1><input type=\"checkbox\" name=\"ignore_out_of_zone_data\" value=\"yes\" checked></td></tr>\n";
	if ( $ip_version eq "v4" ) {
		print "<tr><td $align>$$lang_vars{create_generic_reverse_entries_message}</td><td $align1><input type=\"checkbox\" name=\"create_generic_check\" id=\"create_generic_check\" value=\"yes\" onchange=\"changeText2();\">\n";
		print "&nbsp;&nbsp;&nbsp;&nbsp;<span id=\"Hide3\"><font color=\"gray\">$$lang_vars{all_addresses_message}</font></span><span id=\"Hide4\"><input type=\"radio\" name=\"create_generic\" id=\"create_generic\" value=\"free\" disabled></span>";
		print "&nbsp;&nbsp;&nbsp;<span id=\"Hide5\"><font color=\"gray\">$$lang_vars{free_addresses_message}</font></span><span id=\"Hide6\"><input type=\"radio\" name=\"create_generic\" id=\"create_generic\" value=\"all\" disabled></span></td></tr>\n";
	}
	if ( $rootnet == 1 && $ip_version eq "v4" ) {
		print "<tr><td $align><span id=\"Hide7\">$$lang_vars{create_reverse_zone_files_all_message}</span></td><td $align1><span id=\"Hide8\"><input type=\"checkbox\" name=\"all_reverse_zones\" id=\"all_reverse_zones\" value=\"yes\"></span></td></tr>\n";
	}

print "</table>\n";

print "<p>\n";

print "<script type=\"text/javascript\">\n";
	print "document.show_zone_form.domain.focus();\n";
print "</script>\n";

print "<span style=\"float: $ori\"><br><p><br><input type=\"hidden\" value=\"$client_id\" name=\"client_id\"><input type=\"hidden\" value=\"$red_num\" name=\"red_num\"><input type=\"hidden\" value=\"$ip_version\" name=\"ip_version\"><input type=\"submit\" value=\"$$lang_vars{submit_message}\" name=\"B2\" class=\"input_link_w_net\"></form></span><br><p>\n";


$gip->print_end("$client_id");
