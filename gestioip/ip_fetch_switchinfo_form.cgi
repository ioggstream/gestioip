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

my $daten=<STDIN>;
my $gip = GestioIP -> new();
my %daten=$gip->preparer($daten);

my $base_uri = $gip->get_base_uri();

my $lang = $daten{'lang'} || "";
my ($lang_vars,$vars_file)=$gip->get_lang("","$lang");
my $server_proto=$gip->get_server_proto();

my $client_id = $daten{'client_id'} || $gip->get_first_client_id();

my $ip_version=$daten{'ip_version'} || "";

$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{live_data_message}","$vars_file");

my $align="align=\"right\"";
my $align1="";
my $ori="left";
my $rtl_helper="<font color=\"white\">x</font>";
if ( $vars_file =~ /vars_he$/ ) {
        $align="align=\"left\"";
        $align1="align=\"right\"";
        $ori="right";
}


my @global_config = $gip->get_global_config("$client_id");
my $ipv4_only_mode=$global_config[0]->[5] || "yes";

$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (2)") if $ip_version !~ /^(v4|v6)$/;

my $module = "SNMP::Info";
my $module_check=$gip->check_module("$module") || "0";
$gip->print_error("$client_id","$$lang_vars{snmp_info_not_found_message} (3)") if $module_check != "1";

$module = "Net::DNS";
$module_check=$gip->check_module("$module") || "0";
$gip->print_error("$client_id","$$lang_vars{net_dns_not_found_message} (4)") if $module_check != "1";



my $red_num = $daten{'red_num'} || $gip->print_error("$client_id","$$lang_vars{formato_malo_message}");
#my $host_id = $daten{'host_id'} || $gip->print_error("$client_id","$$lang_vars{formato_malo_message}");

my $ip = $daten{'ip'} || $gip->$gip->print_error("$client_id","$$lang_vars{formato_malo_message}");

#my @values_redes=$gip->get_red("$client_id","$red_num");
#my $red = "$values_redes[0]->[0]" || "";
#my $BM = "$values_redes[0]->[1]" || "";


my $hide1_v6=$$lang_vars{snmp_username_message};
my $hide2_v6=$$lang_vars{security_level_message};
my $hide3_v6="<select name=\\\"sec_level\\\" id=\\\"sec_level\\\"> <option value=\\\"noAuthNoPriv\\\">noAuthNoPriv</option> <option value=\\\"authNoPriv\\\" selected>authNoPriv</option> <option value=\\\"authPriv\\\">authPriv</option>";
my $hide4_v6=$$lang_vars{auth_proto_message};
my $hide5_v6=$$lang_vars{auth_pass_message};
my $hide6_v6="<select name=\\\"auth_proto\\\" id=\\\"auth_proto\\\"><option value=\\\"\\\" selected>---</option> <option value=\\\"MD5\\\">MD5</option> <option value=\\\"SHA\\\">SHA</option></select>";
my $hide7_v6="<input type=\\\"password\\\" size=\\\"15\\\" name=\\\"auth_pass\\\" id=\\\"auth_pass\\\" maxlength=\\\"100\\\">";
my $hide8_v6=$$lang_vars{priv_proto_message};
my $hide9_v6=$$lang_vars{priv_pass_message};
my $hide10_v6="<select name=\\\"priv_proto\\\" id=\\\"priv_proto\\\"> <option value=\\\"\\\" selected>---</option> <option value=\\\"DES\\\" >DES</option> <option value=\\\"3DES\\\">3DES</option> <option value=\\\"AES\\\">AES</option></select>";
my $hide11_v6="<input type=\\\"password\\\" size=\\\"15\\\" name=\\\"priv_pass\\\" id=\\\"priv_pass\\\" maxlength=\\\"100\\\">";
my $hide12="$$lang_vars{snmp_default_public_message}";


print <<EOF;

<script type="text/javascript">
<!--
function changeText1(version){
  if(version == 1 | version == 2 ) {
    document.getElementById('Hide1').innerHTML = "$$lang_vars{snmp_community_message}";
    document.getElementById('Hide2').innerHTML = "";
    document.getElementById('Hide3').innerHTML = "";
    document.getElementById('Hide4').innerHTML = "";
    document.getElementById('Hide5').innerHTML = "";
    document.getElementById('Hide6').innerHTML = "";
    document.getElementById('Hide7').innerHTML = "";
    document.getElementById('Hide8').innerHTML = "";
    document.getElementById('Hide9').innerHTML = "";
    document.getElementById('Hide10').innerHTML = "";
    document.getElementById('Hide11').innerHTML = "";
 //   document.getElementById('Hide12').innerHTML = "$hide12";
    document.forms.snmp_version.community_string.type="password";
    document.forms.snmp_version.community_string.value="public";
  }else{
    document.getElementById('Hide1').innerHTML = "$hide1_v6";
    document.getElementById('Hide2').innerHTML = "$hide2_v6";
    document.getElementById('Hide3').innerHTML = "$hide3_v6";
    document.getElementById('Hide4').innerHTML = "$hide4_v6";
    document.getElementById('Hide5').innerHTML = "$hide5_v6";
    document.getElementById('Hide6').innerHTML = "$hide6_v6";
    document.getElementById('Hide7').innerHTML = "$hide7_v6";
    document.getElementById('Hide8').innerHTML = "$hide8_v6";
    document.getElementById('Hide9').innerHTML = "$hide9_v6";
    document.getElementById('Hide10').innerHTML = "$hide10_v6";
    document.getElementById('Hide11').innerHTML = "$hide11_v6";
    document.getElementById('Hide12').innerHTML = "";
    document.forms.snmp_version.community_string.type="text";
    document.forms.snmp_version.community_string.value="";
  }
}
-->
</script>


<script type="text/javascript">
<!--
function checkRefresh() {
  document.forms.snmp_version.snmp_version.selectedIndex="0";
}
-->
</script>



<script type="text/javascript">
<!--
function confirmation() {

        answer = confirm("$$lang_vars{snmp_discovery_in_execution_message}")

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

my $confirmation = $gip->get_config_confirmation("$client_id") || "yes";
my $onclick = "";
if ( $confirmation eq "yes" ) {
        $onclick =  "onclick=\"return confirmation();\"";
}

print "<p>\n";
print "<form name=\"snmp_version\"  method=\"POST\" action=\"$server_proto://$base_uri/ip_fetch_switchinfo.cgi\">\n";
print "<table border=\"0\" cellpadding=\"7\">\n";
if ( $lang_vars =~ /vars_he$/ ) {
	print "<tr><td colspan=\"4\" $align1><b>$ip $$lang_vars{hosts_message}</b><input type=\"hidden\" name=\"red_num\" value=\"$red_num\"><input type=\"hidden\" name=\"ip_version\" value=\"$ip_version\"><p> </td></tr>\n";
} else {
	print "<tr><td colspan=\"4\" $align1><b>$$lang_vars{hosts_message} $ip</b><input type=\"hidden\" name=\"red_num\" value=\"$red_num\"><input type=\"hidden\" name=\"ip_version\" value=\"$ip_version\"><p> </td></tr>\n";
}


if ( $ip_version eq "v4") {

print <<EOF;
	<tr><td><input type="hidden" name="ipv4" value="ipv4"></td></tr>
EOF
} else {
print <<EOF;
	<tr><td><input type="hidden" name="ipv6" value="ipv6"></td></tr>
EOF
}



print <<EOF;

<tr><td $align>$$lang_vars{snmp_version_message}</td>
<td colspan="3" $align1><select name="snmp_version" id="snmp_version" onchange="changeText1(this.value);">


<option value="1" selected>v1</option>
<option value="2">v2c</option>
<option value="3">v3</option>
</select>
</td></tr>


<tr><td $align>
<span id="Hide1" $align1>$$lang_vars{snmp_community_message}</span>
</td><td colspan="3" $align1><input type="password" size="10" name="community_string" value="public" maxlength="55"> <span id="Hide12" $align1>$$lang_vars{snmp_default_public_message}</span></td></tr>


<tr><td $align>
<span id="Hide2" $align1></span>
</td><td colspan=\"3\" $align1>
<span id="Hide3" $align1></span>
</select>

</td></tr>

<tr><td $align></td><td $align1><span id="Hide4"></span></td><td $align1><span id="Hide5"></span></td><td></td></tr>

<tr><td $align></td><td $align1>
<span id="Hide6"></span>
</select>

</td><td $align1><span id="Hide7"></span></td><td></tr>

<tr><td $align></td><td $align1><span id="Hide8"></span></td><td $align1><span id="Hide9"></span></td><td></td></tr>

<tr><td $align></td><td $align1>
<span id="Hide10"></span>
</td><td $align1><span id="Hide11"></span></td><td></tr>


<tr><td colespan="4" $align1></td></tr>


<tr><td $align1><br><input type="hidden" name="snmp_node" value="$ip"><input type="hidden" name="client_id" value="$client_id"><input type="submit" value="$$lang_vars{query_message}" name=\"B1\" class=\"input_link_w\"></td></tr>

</form>
</table>

EOF

$gip->print_end("$client_id","$vars_file");
