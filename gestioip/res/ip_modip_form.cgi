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
use Net::IP;
use Net::IP qw(:PROC);
use lib '../modules';
use GestioIP;


my $daten=<STDIN>;
my $gip = GestioIP -> new();
my %daten=$gip->preparer($daten);

my $base_uri = $gip->get_base_uri();
my $server_proto=$gip->get_server_proto();

my $lang = $daten{'lang'} || "";
my ($lang_vars,$vars_file,$entries_per_page_hosts);
($lang_vars,$vars_file)=$gip->get_lang("","$lang");
if ( $daten{'entries_per_page_hosts'} && $daten{'entries_per_page_hosts'} =~ /^\d{1,3}$/ ) {
        $entries_per_page_hosts=$daten{'entries_per_page_hosts'};
} else {
        $entries_per_page_hosts = "254";
}

my $client_id = $daten{'client_id'} || $gip->get_first_client_id();
my $host_order_by = $daten{'host_order_by'} || "IP_auf";
my $ip_version = $daten{'ip_version'} || "";

my $search_index=$daten{'search_index'} || "";
my $search_hostname=$daten{'search_hostname'} || "";

my $ip_int=$daten{'ip'};
my $red_num=$daten{'red_num'};
my $loc=$daten{'loc'} || "";
$loc = "" if $loc eq "---";

my $text_field_number_given_form = "";
if ( defined($daten{'text_field_number_given'}) ) {
	$text_field_number_given_form="<input name=\"text_field_number_given\" type=\"hidden\" value=\"text_field_number_given\">";
}


my $ip_ad=$gip->int_to_ip("$client_id","$ip_int","$ip_version");

$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{cambiar_host_message} $ip_ad","$vars_file");

my $utype = $daten{'update_type'};
$gip->print_error("$client_id","$$lang_vars{formato_malo_message}") if $daten{'anz_values_hosts'} && $daten{'anz_values_hosts'} !~ /^\d{2,4}||no_value$/;
$gip->print_error("$client_id","$$lang_vars{formato_malo_message}") if $daten{'knownhosts'} && $daten{'knownhosts'} !~ /^all|hosts|libre$/;
$gip->print_error("$client_id","$$lang_vars{formato_malo_message}") if $daten{'start_entry_hosts'} && $daten{'start_entry_hosts'} !~ /^\d{1,20}$/;
#$gip->print_error("$client_id","$$lang_vars{formato_malo_message}") if ! $daten{'host_id'};
my $anz_values_hosts = $daten{'anz_values_hosts'} || "no_value";

my $start_entry_hosts=$daten{'start_entry_hosts'} || '0';
my $knownhosts=$daten{'knownhosts'} || 'all';
my $host_id=$daten{'host_id'} || "";

print "<p>\n";

$daten{'ip'} || $gip->print_error("$client_id","$$lang_vars{una_ip_message}<br>");
my $linked_ip=$daten{'linked_ip'} || "";

if ( $ip_version eq "v4" ) {
	$gip->CheckInIP("$client_id","$ip_ad","$$lang_vars{formato_ip_malo_message} - $$lang_vars{comprueba_ip_message}: <b><i>$ip_ad</i></b><br>");
} else {
	my $valid_v6=$gip->check_valid_ipv6("$ip_ad") || "0";
	$gip->print_error("$client_id","$$lang_vars{formato_ip_malo_message}") if $valid_v6 ne "1";
}

my @values_redes = $gip->get_red("$client_id","$red_num");

my $red = "$values_redes[0]->[0]" || "";
my $BM = "$values_redes[0]->[1]" || "";

my @values_locations=$gip->get_loc("$client_id");
my @values_categorias=$gip->get_cat("$client_id");
my @values_utype=$gip->get_utype();

my @host=$gip->get_host("$client_id","$ip_int","$ip_int");

my $hostname = $host[0]->[1] || "";
if (( ! $hostname || $hostname eq "unknown" ) && $search_hostname ) {
	$hostname = $search_hostname;
}
$hostname = "" if $hostname eq "NULL";
my $host_descr = $host[0]->[2] || "NULL";
my $loc_val = $host[0]->[3] || "$loc";
my $cat_val = $host[0]->[4] || "NULL";
my $int_ad_val = $host[0]->[5] || "n";
my $update_type = $host[0]->[7] || "";
my $comentario = $host[0]->[6] || "";

$host_descr = "" if (  $host_descr eq "NULL" );
$comentario = "" if (  $comentario eq "NULL" ); 
$loc_val = "" if (  $loc_val eq "NULL" ); 
$cat_val = "" if (  $cat_val eq "NULL" );
$update_type = "" if (  $update_type eq "NULL" ); 


print <<EOF;
<script language="JavaScript" type="text/javascript" charset="utf-8">
<!--
function checkhost(IP,HOSTNAME,CLIENT_ID,IP_VERSION)
{
var opciones="toolbar=no,right=100,top=100,width=500,height=300", i=0;
var URL="$server_proto://$base_uri/ip_checkhost.cgi?ip=" + IP + "&hostname=" + HOSTNAME + "&client_id=" + CLIENT_ID  + "&ip_version=" + IP_VERSION;
host_info=window.open(URL,"",opciones);
}
-->
</script>
EOF


print "<form name=\"ip_mod_form\" method=\"POST\" action=\"$server_proto://$base_uri/res/ip_modip.cgi\">\n";
print "<table border=\"0\" cellpadding=\"1\">\n";
print "<font size=\"1\"><tr><td><b>IP</b></td><td><b>  $$lang_vars{hostname_message}</font></b></td><td><b>  $$lang_vars{description_message}</b></td><td><b>  $$lang_vars{loc_message}</b></td><td><b> $$lang_vars{cat_message}</b></td><td><b>AI</b></td><td><b>$$lang_vars{comentario_message}</b></td><td><b>UT</b></td></tr>\n";
print "<tr valign=\"top\"><td class=\"hostcheck\" onClick=\"checkhost(\'$ip_ad\',\'\',\'$client_id\',\'$ip_version\')\" style=\"cursor:pointer;\" title=\"ping\"><font size=\"2\">$ip_ad<input type=\"hidden\" name=\"ip\" value=\"$ip_ad\"></font></td>\n";
print "<td><i><font size=\"2\"><input type=\"text\" size=\"15\" name=\"hostname\" value=\"$hostname\" maxlength=\"75\"></font></i></td>\n";
print "<td><i><font size=\"2\"><input type=\"text\" size=\"15\" name=\"host_descr\" value=\"$host_descr\" maxlength=\"100\"></font></i></td>\n";
print "<td><font size=\"2\"><select name=\"loc\" size=\"1\" value=\"$loc_val\">";
print "<option>$loc_val</option>";
my $j=0;
foreach (@values_locations) {
	$values_locations[$j]->[0] = "" if ($values_locations[$j]->[0] eq "NULL" && $loc_val ne "NULL" );
	print "<option>$values_locations[$j]->[0]</option>" if ( $values_locations[$j]->[0] ne "$loc_val" );
	$j++;
}
print "</select>\n";
print "</td><td><select name=\"cat\" size=\"1\">";
print "<option>$cat_val</option>";
$j=0;
foreach (@values_categorias) {
	$values_categorias[$j]->[0] = "" if ($values_categorias[$j]->[0] eq "NULL" && $cat_val ne "NULL" );
        print "<option>$values_categorias[$j]->[0]</option>" if ($values_categorias[$j]->[0] ne "$cat_val" );
        $j++;
}
print "</select>\n";

print "</font></td><input name=\"red\" type=\"hidden\" value=\"$red\"><input name=\"BM\" type=\"hidden\" value=\"$BM\"><input name=\"red_num\" type=\"hidden\" value=\"$red_num\">\n";

my $int_admin_checked;
if ( $int_ad_val eq "y" ) {
	$int_admin_checked="checked";
} else {
	$int_admin_checked="";
}

print "<td><input type=\"checkbox\" name=\"int_admin\" value=\"y\" $int_admin_checked></td>\n";


print "<td><textarea name=\"comentario\" cols=\"30\" rows=\"5\" wrap=\"physical\" maxlength=\"500\">$comentario</textarea></td>";
print "<td><select name=\"update_type\" size=\"1\">";
print "<option>$update_type</option>";
$j=0;
foreach (@values_utype) {
	$values_utype[$j]->[0] = "" if ( $values_utype[$j]->[0] =~ /NULL/ && $update_type ne "NULL" );
        print "<option>$values_utype[$j]->[0]</option>" if ( $values_utype[$j]->[0] ne "$update_type" );
        $j++;
}
print "</select>\n";
print "</td>";

print "<td><input name=\"entries_per_page_hosts\" type=\"hidden\" value=\"$entries_per_page_hosts\"><input name=\"start_entry_hosts\" type=\"hidden\" value=\"$start_entry_hosts\"><input name=\"knownhosts\" type=\"hidden\" value=\"$knownhosts\"><input name=\"anz_values_hosts\" type=\"hidden\" value=\"$anz_values_hosts\"></td></tr>\n";


print "<br><p>\n";
print "<table border=\"0\" cellpadding=\"1\">\n";

my %cc_value = ();
my @custom_columns = $gip->get_custom_host_columns("$client_id");
%cc_value=$gip->get_custom_host_columns_from_net_id_hash("$client_id","$host_id") if $host_id;

if ( $custom_columns[0] ) {
        print "<b>$$lang_vars{custom_host_columns_message}</b><p>\n";
}

my @vendors = $gip->get_vendor_array();

my $n=0;
foreach my $cc_ele(@custom_columns) {
	my $cc_name = $custom_columns[$n]->[0];
	my $pc_id = $custom_columns[$n]->[3];
	my $cc_id = $custom_columns[$n]->[1];
	my $cc_entry = $cc_value{$cc_id}[1] || "";
	if ( $daten{'OS'} && $cc_name eq "OS" ) {
		$cc_entry = $daten{'OS'};	
	}
	if ( $daten{'OS_version'} && $cc_name eq "OS_version" ) {
		$cc_entry = $daten{'OS_version'};	
	}
	if ( $daten{'MAC'} && $cc_name eq "MAC" ) {
		$cc_entry = $daten{'MAC'};	
	}
	if ( $cc_name ) {
		if ( $cc_name eq "vendor" ) {
			my $knownvendor="0";
			foreach (@vendors) {
				if ( $cc_entry =~ /$_/i ) {
					$knownvendor="1"; 
					last;
				}
			}
			my $checked_known="";
			my $checked_unknown="";
			my $disabled_known="";
			my $disabled_unknown="";
			my $cc_entry_unknown="";
			if ( $knownvendor == 1 ) {
				$checked_known="checked";
				$disabled_unknown="disabled";
			} elsif ( ! $cc_entry  ) {
				$checked_known="checked";
				$disabled_unknown="disabled";
			} else {
				$checked_unknown="checked";
				$disabled_known="disabled";
				$cc_entry_unknown=$cc_entry;
			}
			print "<tr><td><b>$cc_name</b></td><td> <input type=\"radio\" name=\"vendor_radio\" value=\"known\" onclick=\"custom_${n}_value_known.disabled=false;custom_${n}_value_unknown.value='';custom_${n}_value_unknown.disabled=true;\" $checked_known></td><td>\n";
			print "<font size=\"2\"><select name=\"custom_${n}_value_known\" id=\"custom_${n}_value_known\" size=\"1\" $disabled_known>";
			print "<option></option>\n";
			my $j=0;
			foreach (@vendors) {
				my $vendor=$vendors[$j];
				my $vendor_img;
				if ( $vendor =~ /(lucent|alcatel)/i ) {
					$vendor_img="lucent-alcatel";
				} elsif ( $vendor =~ /(borderware)/i ) {
					$vendor_img="watchguard";
				} elsif ( $vendor =~ /(dlink|d-link)/i ) {
					$vendor_img="dlink";
				} elsif ( $vendor =~ /(cyclades)/i ) {
					$vendor_img="avocent";
				} elsif ( $vendor =~ /(eci telecom)/i ) {
					$vendor_img="eci";
				} elsif ( $vendor =~ /(^hp)/i ) {
					$vendor="hp";
					$vendor_img="hp";
				} elsif ( $vendor =~ /(minolta)/i ) {
					$vendor_img="konica";
				} elsif ( $vendor =~ /(okilan)/i ) {
					$vendor_img="oki";
				} elsif ( $vendor =~ /(phaser)/i ) {
					$vendor_img="xerox";
				} elsif ( $vendor =~ /(tally|genicom)/i ) {
					$vendor_img="tallygenicom";
				} elsif ( $vendor =~ /(seiko|infotec)/i ) {
					$vendor_img="seiko_infotec";
				} elsif ( $vendor =~ /(^palo)/i ) {
					$vendor="paloalto";
					$vendor_img="palo_alto";
				} elsif ( $vendor =~ /(silverpeak)/i ) {
					$vendor_img="silver_peak";
				} else {
					$vendor_img=$vendor;
				}
				if ( $cc_entry && $vendors[$j] =~ /$cc_entry/ ) {
					print "<option value=\"$vendor\" style=\"background: url(../imagenes/vendors/$vendor_img.png) no-repeat top left;\" selected>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; $vendor</option>";
				} else {
					print "<option value=\"$vendor\" style=\"background: url(../imagenes/vendors/$vendor_img.png) no-repeat top left;\">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; $vendor</option>";
				}
				$j++;
			}
			print "</select><input name=\"custom_${n}_name\" type=\"hidden\" value=\"$cc_name\"><input name=\"custom_${n}_id\" type=\"hidden\" value=\"$cc_id\"><input name=\"custom_${n}_pcid\" type=\"hidden\" value=\"$pc_id\"></td></tr>\n";
			print "<tr><td></td><td><input type=\"radio\" name=\"vendor_radio\" value=\"unknown\" onclick=\"custom_${n}_value_known.disabled=true;custom_${n}_value_unknown.disabled=false;document.ip_mod_form.custom_${n}_value_known.options[0].selected = true;\" $checked_unknown></td><td><input type=\"text\" size=\"20\" name=\"custom_${n}_value_unknown\" id=\"custom_${n}_value_unknown\" value=\"$cc_entry_unknown\" maxlength=\"500\" $disabled_unknown></td></tr>\n";

		} elsif ( $cc_name eq "URL" ) {
			print "<tr><td><b>$cc_name</b><br>(service::URL)</td><td colspan='2'><input name=\"custom_${n}_name\" type=\"hidden\" value=\"$cc_name\"><input name=\"custom_${n}_id\" type=\"hidden\" value=\"$cc_id\"><input name=\"custom_${n}_pcid\" type=\"hidden\" value=\"$pc_id\"><textarea name='custom_${n}_value' cols='50' rows='5' wrap='physical' maxlength='500'>$cc_entry</textarea></td></tr>\n";

		} elsif ( $cc_name eq "linked IP" ) {
			$linked_ip=$cc_entry if ! $linked_ip;
			print "<tr><td><b>$cc_name</b></td><td></td><td><input name=\"custom_${n}_name\" type=\"hidden\" value=\"$cc_name\"><input name=\"custom_${n}_id\" type=\"hidden\" value=\"$cc_id\"><input name=\"custom_${n}_pcid\" type=\"hidden\" value=\"$pc_id\"><input type=\"text\" size=\"20\" name=\"custom_${n}_value\" value=\"$linked_ip\" maxlength=\"500\"></td></tr>\n";

		} else {
			print "<tr><td><b>$cc_name</b></td><td></td><td><input name=\"custom_${n}_name\" type=\"hidden\" value=\"$cc_name\"><input name=\"custom_${n}_id\" type=\"hidden\" value=\"$cc_id\"><input name=\"custom_${n}_pcid\" type=\"hidden\" value=\"$pc_id\"><input type=\"text\" size=\"20\" name=\"custom_${n}_value\" value=\"$cc_entry\" maxlength=\"500\"></td></tr>\n";
		}
	$n++;
	}
}

print "<tr><td><br><p><input type=\"hidden\" name=\"host_id\" value=\"$host_id\"><input name=\"host_order_by\" type=\"hidden\" value=\"$host_order_by\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"hidden\" name=\"ip_version\" value=\"$ip_version\"><input type=\"hidden\" name=\"search_index\" value=\"$search_index\"><input type=\"hidden\" name=\"search_hostname\" value=\"$search_hostname\">$text_field_number_given_form<input type=\"submit\" value=\"$$lang_vars{cambiar_message}\" name=\"B1\" class=\"input_link_w_net\"></td><td></td></tr>\n";
print "</form>\n";
print "</table>\n";


print "<script type=\"text/javascript\">\n";
print "document.ip_mod_form.hostname.focus();\n";
print "</script>\n";

$gip->print_end("$client_id","$vars_file");
