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

# VERSION 3.0.0


use strict;
use lib '../modules';
use GestioIP;

my $daten=<STDIN>;
my $gip = GestioIP -> new();
my %daten=$gip->preparer($daten);

my $base_uri = $gip->get_base_uri();
my $server_proto=$gip->get_server_proto();

my $lang = $daten{'lang'} || "";
my ($lang_vars,$vars_file)=$gip->get_lang("","$lang");


my $client_id = $daten{'client_id'} || $gip->get_first_client_id();

$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{import_routes_message}","$vars_file");

my @global_config = $gip->get_global_config("$client_id");
my $ipv4_only_mode=$global_config[0]->[5] || "yes";

my $hide1_v6=$$lang_vars{snmp_username_message};
my $hide2_v6=$$lang_vars{security_level_message};
my $hide3_v6="&nbsp;&nbsp;<select name=\\\"sec_level\\\" id=\\\"sec_level\\\"> <option value=\\\"noAuthNoPriv\\\">noAuthNoPriv<\\/option> <option value=\\\"authNoPriv\\\" selected>authNoPriv<\\/option> <option value=\\\"authPriv\\\">authPriv<\\/option><\\/select>";
my $hide4_v6="&nbsp;&nbsp;$$lang_vars{auth_proto_message}";
my $hide5_v6="&nbsp;&nbsp;$$lang_vars{auth_pass_message}";
my $hide6_v6="&nbsp;&nbsp;<select name=\\\"auth_proto\\\" id=\\\"auth_proto\\\"><option value=\\\"\\\" selected>---<\\/option> <option value=\\\"MD5\\\">MD5<\\/option> <option value=\\\"SHA\\\">SHA<\\/option><\\/select>";
my $hide7_v6="&nbsp;&nbsp;<input type=\\\"password\\\" size=\\\"15\\\" name=\\\"auth_pass\\\" id=\\\"auth_pass\\\" maxlength=\\\"100\\\">";
my $hide8_v6="&nbsp;&nbsp;$$lang_vars{priv_proto_message}";
my $hide9_v6="&nbsp;&nbsp;$$lang_vars{priv_pass_message}";
my $hide10_v6="&nbsp;&nbsp;<select name=\\\"priv_proto\\\" id=\\\"priv_proto\\\"> <option value=\\\"\\\" selected>---<\\/option> <option value=\\\"DES\\\" >DES<\\/option> <option value=\\\"3DES\\\">3DES<\\/option> <option value=\\\"AES\\\">AES<\\/option><\\/select>";
my $hide11_v6="&nbsp;&nbsp;<input type=\\\"password\\\" size=\\\"15\\\" name=\\\"priv_pass\\\" id=\\\"priv_pass\\\" maxlength=\\\"100\\\">";
my $hide12="$$lang_vars{snmp_default_public_message} <img src=\\\"../imagenes/quick_help.png\\\" title=\\\"$$lang_vars{community_explic_message}\\\">";

my $align="align=\"right\"";
my $align1="";
my $ori="left";
my $rtl_helper="<font color=\"white\">x</font>";
if ( $vars_file =~ /vars_he$/ ) {
        $align="align=\"left\"";
        $align1="align=\"right\"";
        $ori="right";
}


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



<p>
<form name="snmp_version" method="POST" action="$server_proto://$base_uri/res/ip_import_snmp.cgi">
<table border="0" cellpadding="7" style="border-collapse:collapse">
<tr><td $align><b>$$lang_vars{snmp_equipo_message}</b></td><td colspan="7" $align1><input type="text" size="25" name="snmp_node" value="" maxlength="75"> <i>($$lang_vars{ip_o_dns_message})</i></td></tr>
<tr><td><br></td></tr>

EOF

if ( $ipv4_only_mode eq "no" ) {

print <<EOF;
	<tr><td $align> $$lang_vars{import_networks_ip_version_message}</td>
	<td colspan="3" $align1>&nbsp;&nbsp;v4<input type="checkbox" name="ipv4" value="ipv4" checked>&nbsp;&nbsp;&nbsp;v6<input type="checkbox" name="ipv6" value="ipv6">$rtl_helper</td></tr>
	<tr><td><br></td></tr>
EOF
} else {
print <<EOF;
	<tr><td $align1><input type="hidden" name="ipv4" value="ipv4"></td></tr>
EOF
}

print <<EOF;

<tr align="center"><td $align rowspan="2"> $$lang_vars{import_route_types_message}</td><td>&nbsp;&nbsp;local</td><td>static</td><td>other</td><td>OSPF</td><td>RIP</td><td>IS-IS</br><td>Cisco EIGRP</td>
<tr><td align="center">&nbsp;&nbsp;<input type="checkbox" name="local_routes" value="local_routes" checked></td><td align="center"><input type="checkbox" name="static_routes" value="static_routes" checked></td><td align="center"><input type="checkbox" name="other_routes" value="other_routes"></td><td align="center"><input type="checkbox" name="ospf_routes" value="ospf_routes"></td><td align="center"><input type="checkbox" name="rip_routes" value="rip_routes"></td><td align="center"><input type="checkbox" name="isis_routes" value="isis_routes"></td><td align="center"><input type="checkbox" name="eigrp_routes" value="eigrp_routes"></td>
<tr><td><br></td></tr>

<tr><td $align>$$lang_vars{snmp_version_message}</td>
<td colspan="7" $align1>&nbsp;&nbsp;<select name="snmp_version" id="snmp_version" onchange="changeText1(this.value);">


<option value="1" selected>v1</option>
<option value="2">v2c</option>
<option value="3">v3</option>
</select>
</td></tr>


<tr><td $align>
<span id="Hide1">$$lang_vars{snmp_community_message}</span>
</td><td colspan="7" $align1>&nbsp;&nbsp;<input type="password" size="10" name="community_string" value="public" maxlength="55"> <span id="Hide12">$$lang_vars{snmp_default_public_message} <img src=\"../imagenes/quick_help.png\" title=\"$$lang_vars{community_explic_message}\" alt=\"help\"></span></td></tr>


<tr><td $align>
<span id="Hide2"></span>
</td><td colspan=\"7\" $align1>
<span id="Hide3"></span>
</select>

</td></tr>

<tr><td $align></td><td colspan=\"3\" $align1><span id="Hide4"></span></td><td colspan=\"4\" $align1><span id="Hide5"></span></td></tr>

<tr><td $align></td><td colspan=\"3\" $align1>
<span id="Hide6"></span>
</select>

</td><td colspan=\"4\" $align1><span id="Hide7"></span></td></tr>

<tr><td $align></td><td colspan=\"3\" $align1><span id="Hide8"></span></td><td colspan=\"4\" $align1><span id="Hide9"></span></td></tr>

<tr><td $align></td><td colspan=\"3\" $align1>
<span id="Hide10"></span>
</td><td colspan=\"4\" $align1><span id="Hide11"></span></td></tr>


<tr><td colspan="8" $align1></td></tr>

<tr><td $align><br>$$lang_vars{process_only_net_v4_message}</td><td colspan="7" $align1><br>&nbsp;&nbsp;<input type="text" name=\"process_networks_v4\" width="20" maxlength=\"500\"></td></tr>
EOF

if ( $ipv4_only_mode eq "no" ) {
print <<EOF;
<tr><td $align><br>$$lang_vars{process_only_net_v6_message}</td><td colspan="7" $align1><br>&nbsp;&nbsp;<input type="text" name=\"process_networks_v6\" width="20" maxlength=\"500\"></td></tr>
EOF
}

print <<EOF;

<tr><td colspan="8" $align1><br></td></tr>

<tr><td $align><br>$$lang_vars{add_comment_snmp_query_message}</td><td colspan="7" $align1><br><input type="checkbox" name="add_comment" value="y"></td></tr>

<tr><td $align>$$lang_vars{mark_sync_message}</td><td colspan="7" $align1><input type=\"checkbox\" name=\"mark_sync\" value="y" checked></td>
<tr><td><br><input type="hidden" name="client_id" value="$client_id"><input type="submit" value="$$lang_vars{query_message}" name=\"B1\" class=\"input_link_w\"></td></tr>

</form>
</table>

EOF


$gip->print_end("$client_id","$vars_file");
