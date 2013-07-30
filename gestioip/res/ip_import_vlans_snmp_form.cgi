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

my $daten=<STDIN>;
my $gip = GestioIP -> new();
my %daten=$gip->preparer($daten);

my $base_uri = $gip->get_base_uri();
my $server_proto=$gip->get_server_proto();

my $lang = $daten{'lang'} || "";
my ($lang_vars,$vars_file)=$gip->get_lang("","$lang");


my $client_id = $daten{'client_id'} || $gip->get_first_client_id();

$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{import_vlans_from_snmp_message}","$vars_file");

my @global_config = $gip->get_global_config("$client_id");
my $ipv4_only_mode=$global_config[0]->[5] || "yes";


my $hide1_v6=$$lang_vars{snmp_username_message};
my $hide2_v6=$$lang_vars{security_level_message};
my $hide3_v6="<select name=\\\"sec_level\\\" id=\\\"sec_level\\\"> <option value=\\\"noAuthNoPriv\\\">noAuthNoPriv<\\/option> <option value=\\\"authNoPriv\\\" selected>authNoPriv<\\/option> <option value=\\\"authPriv\\\">authPriv<\\/option><\\/select>";
my $hide4_v6=$$lang_vars{auth_proto_message};
my $hide5_v6=$$lang_vars{auth_pass_message};
my $hide6_v6="<select name=\\\"auth_proto\\\" id=\\\"auth_proto\\\"><option value=\\\"\\\" selected>---<\\/option> <option value=\\\"MD5\\\">MD5<\\/option> <option value=\\\"SHA\\\">SHA<\\/option><\\/select>";
my $hide7_v6="<input type=\\\"password\\\" size=\\\"15\\\" name=\\\"auth_pass\\\" id=\\\"auth_pass\\\" maxlength=\\\"100\\\">";
my $hide8_v6=$$lang_vars{priv_proto_message};
my $hide9_v6=$$lang_vars{priv_pass_message};
my $hide10_v6="<select name=\\\"priv_proto\\\" id=\\\"priv_proto\\\"> <option value=\\\"\\\" selected>---<\\/option> <option value=\\\"DES\\\" >DES<\\/option> <option value=\\\"3DES\\\">3DES<\\/option> <option value=\\\"AES\\\">AES<\\/option><\\/select>";
my $hide11_v6="<input type=\\\"password\\\" size=\\\"15\\\" name=\\\"priv_pass\\\" id=\\\"priv_pass\\\" maxlength=\\\"100\\\">";
my $hide12="$$lang_vars{snmp_default_public_message} <img src=\\\"../imagenes/quick_help.png\\\" title=\\\"$$lang_vars{community_explic_message}\\\">";

#my $hide13="$$lang_vars{is_key_message}";
#my $hide14="$$lang_vars{is_key_message}";
#my $hide15="<input type=\\\"checkbox\\\" name=\\\"auth_is_key\\\" value=\\\"yes\\\">";
#my $hide16="<input type=\\\"checkbox\\\" name=\\\"priv_is_key\\\" value=\\\"yes\\\">";

my $align="align=\"right\"";
my $align1="";
my $ori="left";
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

EOF

my $l2_device_id=$gip->get_cat_id_from_cat_name("$client_id","L2 device");
my $l3_device_id=$gip->get_cat_id_from_cat_name("$client_id","L3 device");
my @l2devices=$gip->get_vlan_import_devices("$client_id","$l2_device_id","v4");
my @l3devices=$gip->get_vlan_import_devices("$client_id","$l3_device_id","v4");
my @l2devices_v6=$gip->get_vlan_import_devices("$client_id","$l2_device_id","v6");
my @l3devices_v6=$gip->get_vlan_import_devices("$client_id","$l3_device_id","v6");


my $snmp_node_opt="";
my $l2devices_opt="";
my $l3devices_opt="";
my $l2devices_v6_opt="";
my $l3devices_v6_opt="";

$snmp_node_opt="snmp_node.disabled=false;";
$l2devices_opt="l2devices.disabled=true;" if $l2devices[0];
$l3devices_opt="l3devices.disabled=true;" if $l3devices[0];
$l2devices_v6_opt="l2devices_v6.disabled=true;" if $l2devices_v6[0];
$l3devices_v6_opt="l3devices_v6.disabled=true;" if $l3devices_v6[0];


my $onclick_opt=$snmp_node_opt . " " . $l2devices_opt . " " . $l3devices_opt . " " . $l2devices_v6_opt . " " . $l3devices_v6_opt . " ";


print <<EOF;

<p>
<br>
<form name="snmp_version" method="POST" action="$server_proto://$base_uri/res/ip_import_vlans_snmp.cgi">
<table border="0" cellpadding="7">

EOF

print "<tr><td $align><b>$$lang_vars{snmp_equipo_message}</b> <input type=\"radio\" name=\"import_device_type\" value=\"node\" onclick=\"$onclick_opt\" checked></td><td colspan=\"3\" $align1><input type=\"text\" size=\"25\" name=\"snmp_node\" value=\"\" maxlength=\"75\"> <i>($$lang_vars{ip_o_dns_message})</i></td></tr>\n";

if ( $l2devices[0] ) {
	$snmp_node_opt="snmp_node.disabled=true;";
	$l2devices_opt="l2devices.disabled=false;";
	$l3devices_opt="l3devices.disabled=true;" if $l3devices[0];
	$l2devices_v6_opt="l2devices_v6.disabled=true;" if $l2devices_v6[0];
	$l3devices_v6_opt="l3devices_v6.disabled=true;" if $l3devices_v6[0];
	my $onclick_opt=$snmp_node_opt . " " . $l2devices_opt . " " . $l3devices_opt . " " . $l2devices_v6_opt . " " . $l3devices_v6_opt;
	print "<tr><td $align><b>$$lang_vars{l2_device_message}</b> <input type=\"radio\" name=\"import_device_type\" value=\"layer2\" onclick=\"$onclick_opt\"></td><td colspan=\"3\" $align1><select name=\"l2devices\" size=\"3\" multiple disabled>\n";
	foreach (@l2devices) {
		$_->[1] =~ s/_/-/g;
		print "<option>$_->[0] - $_->[1]</option>";
	}
	print "</select></td></tr>\n";
} else {
	print "<tr><td $align><b>$$lang_vars{l2_device_message}</b> <input type=\"radio\" name=\"import_device_type\" value=\"layer2\" disabled></td><td colspan=\"3\" $align1><i>$$lang_vars{no_l2_device_message}</i>\n</td></tr>";
}


if ( $l3devices[0] ) {
	$snmp_node_opt="snmp_node.disabled=true;";
	$l2devices_opt="l2devices.disabled=true;" if $l2devices[0];
	$l3devices_opt="l3devices.disabled=false;";
	$l2devices_v6_opt="l2devices_v6.disabled=true;" if $l2devices_v6[0];
	$l3devices_v6_opt="l3devices_v6.disabled=true;" if $l3devices_v6[0];
	my $onclick_opt=$snmp_node_opt . " " . $l2devices_opt . " " . $l3devices_opt . " " . $l2devices_v6_opt . " " . $l3devices_v6_opt;
	print "<tr><td $align><b>$$lang_vars{l3_device_message}</b> <input type=\"radio\" name=\"import_device_type\" value=\"layer3\" onclick=\"$onclick_opt\"></td><td colspan=\"3\" $align1><select name=\"l3devices\" size=\"3\" multiple disabled>\n";
	foreach (@l3devices) {
		$_->[1] =~ s/_/-/g;
		print "<option>$_->[0] - $_->[1]</option>";
	}
	print "</select></td></tr>\n";
} else {
	print "<tr><td $align><b>$$lang_vars{l3_device_message}</b> <input type=\"radio\" name=\"import_device_type\" value=\"layer3\" disabled></td><td colspan=\"3\" $align1><i>$$lang_vars{no_l3_device_message}</i>\n</td></tr>";
}


if ( $ipv4_only_mode eq "no" ) {

	if ( $l2devices_v6[0] ) {
		$snmp_node_opt="snmp_node.disabled=true;";
		$l2devices_opt="l2devices.disabled=true;" if $l2devices[0];
		$l3devices_opt="l3devices.disabled=true;" if $l3devices[0];
		$l2devices_v6_opt="l2devices_v6.disabled=false;";
		$l3devices_v6_opt="l3devices_v6.disabled=true;" if $l3devices_v6[0];
		my $onclick_opt=$snmp_node_opt . " " . $l2devices_opt . " " . $l3devices_opt . " " . $l2devices_v6_opt . " " . $l3devices_v6_opt;
		print "<tr><td $align><b>$$lang_vars{l2_device_message} IPv6</b> <input type=\"radio\" name=\"import_device_type\" value=\"layer2\" onclick=\"$l2devices_v6_opt\"></td><td colspan=\"3\" $align1><select name=\"l2devices_v6\" size=\"3\" multiple disabled>\n" if $l3devices[0];
		print "<tr><td $align><b>$$lang_vars{l2_device_message} IPv6</b> <input type=\"radio\" name=\"import_device_type\" value=\"layer2\" onclick=\"$onclick_opt\"></td><td colspan=\"3\" $align1><select name=\"l2devices_v6\" size=\"3\" multiple disabled>\n" if ! $l3devices[0];
		foreach (@l2devices_v6) {
			$_->[0] = $gip->int_to_ip("$client_id","$_->[0]","v6");
			$_->[1] =~ s/_/-/g;
			print "<option value=\"$_->[0]\">$_->[0] - $_->[1]</option>";
		}
		print "</select></td></tr>\n";
	} else {
		print "<tr><td $align><b>$$lang_vars{l2_device_message} IPv6</b> <input type=\"radio\" name=\"import_device_type\" value=\"layer2\" disabled></td><td colspan=\"3\" $align1><i>$$lang_vars{no_l2_device_message}</i>\n</td></tr>";
	}


	if ( $l3devices_v6[0] ) {
		$snmp_node_opt="snmp_node.disabled=true;";
		$l2devices_opt="l2devices.disabled=true;" if $l2devices[0];
		$l3devices_opt="l3devices.disabled=true;" if $l3devices[0];
		$l2devices_v6_opt="l2devices_v6.disabled=true;" if $l2devices_v6[0];
		$l3devices_v6_opt="l3devices_v6.disabled=false;";
		my $onclick_opt=$snmp_node_opt . " " . $l2devices_opt . " " . $l3devices_opt . " " . $l2devices_v6_opt . " " . $l3devices_v6_opt;
		print "<tr><td $align><b>$$lang_vars{l3_device_message} IPv6</b> <input type=\"radio\" name=\"import_device_type\" value=\"layer3\" onclick=\"$onclick_opt\"></td><td colspan=\"3\" $align1><select name=\"l3devices_v6\" size=\"3\" multiple disabled>\n" if $l2devices[0];
		print "<tr><td $align><b>$$lang_vars{l3_device_message} IPv6</b> <input type=\"radio\" name=\"import_device_type\" value=\"layer3\" onclick=\"l3devices_v6.disabled=false;snmp_node.disabled=true;\"></td><td colspan=\"3\" $align1><select name=\"l3devices_v6\" size=\"3\" multiple disabled>\n" if ! $l2devices[0];
		foreach (@l3devices_v6) {
			$_->[0] = $gip->int_to_ip("$client_id","$_->[0]","v6");
			$_->[1] =~ s/_/-/g;
			print "<option value=\"$_->[0]\">$_->[0] - $_->[1]</option>";
		}
		print "</select></td></tr>\n";
	} else {
		print "<tr><td $align><b>$$lang_vars{l3_device_message} IPv6</b> <input type=\"radio\" name=\"import_device_type\" value=\"layer3\" disabled></td><td colspan=\"3\" $align1><i>$$lang_vars{no_l3_device_message}</i>\n</td></tr>";
	}

}


print <<EOF;

<tr><td colspan="4"><br><p></td></tr>

<tr><td $align>$$lang_vars{snmp_version_message}</td>
<td colspan="3" $align1><select name="snmp_version" id="snmp_version" onchange="changeText1(this.value);">


<option value="1" selected>v1</option>
<option value="2">v2c</option>
<option value="3">v3</option>
</select>
</td></tr>


<tr><td $align>
<span id="Hide1">$$lang_vars{snmp_community_message}</span>
</td><td colspan="3" $align1><input type="password" size="10" name="community_string" value="public" maxlength="55"> <span id="Hide12">$$lang_vars{snmp_default_public_message} <img src=\"../imagenes/quick_help.png\" title=\"$$lang_vars{community_explic_message}\" alt=\"help\"></span></td></tr>


<tr><td $align>
<span id="Hide2"></span>
</td><td colspan=\"3\" $align1>
<span id="Hide3"></span>
</select>

</td></tr>

<tr><td $align></td><td $align1><span id="Hide4"></span></td><td $align1><span id="Hide5"></span></td><td></td></tr>

<tr><td $align></td><td $align1>
<span id="Hide6"></span>
</select>

</td><td $align1><span id="Hide7"></span></td><td></td></tr>

<tr><td $align></td><td $align1><span id="Hide8"></span></td><td $align1><span id="Hide9"></span></td><td></td></tr>

<tr><td $align></td><td $align1>
<span id="Hide10"></span>
</td><td $align1><span id="Hide11"></span></td><td></td></tr>

EOF

#print <<EOF;
#<tr><td colspan="4"><br></td></tr>
#<tr><td $align> $$lang_vars{debug_mode_message}</td>
#<td colspan="3">&nbsp;<input type="checkbox" name="debug" value="1"></td></tr>
#EOF

print <<EOF;
<tr><td><br><input type="hidden" name="client_id" value="$client_id"><input type="submit" value="$$lang_vars{query_message}" name=\"B1\" class=\"input_link_w\"></td></tr>

</form>
</table>


EOF



$gip->print_end("$client_id");
