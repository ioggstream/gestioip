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

#my $ip_int=$daten{'ip'};
my $red_num=$daten{'red_num'};
$red_num = "" if $search_index eq "true";
my $loc=$daten{'loc'} || "";
$loc = "" if $loc eq "---";

my $text_field_number_given_form = "";
if ( defined($daten{'text_field_number_given'}) ) {
	$text_field_number_given_form="<input name=\"text_field_number_given\" type=\"hidden\" value=\"text_field_number_given\">";
}


#my $ip_ad=$gip->int_to_ip("$client_id","$ip_int","$ip_version");

$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{host_mass_update_message}","$vars_file");






my $mass_update_type=$daten{'mass_update_type'};
$gip->print_error("$client_id","$$lang_vars{select_mass_update_type}") if ! $mass_update_type;
my @mass_update_types=();
if ( $mass_update_type =~ /_/ ) {
	@mass_update_types=split("_",$mass_update_type);
} else {
	$mass_update_types[0]=$mass_update_type;
}
my $anz_hosts=$daten{'anz_hosts'} || "0";


my $k;
my $j=0;
my $mass_update_host_ids="";
for ($k=0;$k<=$anz_hosts;$k++) {
	if ( $daten{"mass_update_host_submit_${k}"} ) {
		$mass_update_host_ids.=$daten{"mass_update_host_submit_${k}"} . "_";
		$j++;
	}
}
$mass_update_host_ids =~ s/_$//;
$gip->print_error("$client_id","$$lang_vars{select_host_message}") if ! $mass_update_host_ids;
$gip->print_error("$client_id","$$lang_vars{formato_malo_message} $mass_update_host_ids (1)") if ($mass_update_host_ids !~ /[0-9_]/ );




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

my @values_redes = $gip->get_red("$client_id","$red_num");

my $red="";
my $BM="";
if ( $values_redes[0]->[0] ) {
	$red = $values_redes[0]->[0] || "";
	$BM = $values_redes[0]->[1] || "";
}

my @values_locations=$gip->get_loc("$client_id");
my @values_categorias=$gip->get_cat("$client_id");
my @values_utype=$gip->get_utype();


print "<form name=\"ip_mod_form\" method=\"POST\" action=\"$server_proto://$base_uri/res/ip_modip_mass_update.cgi\">\n";
print "<table border=\"0\" cellpadding=\"1\">\n";


foreach (@mass_update_types) {
	if ( $_ eq $$lang_vars{hostname_message} ) {
		print "<tr><td>$$lang_vars{hostname_message}</td><td></td><td><i><font size=\"2\"><input type=\"text\" size=\"15\" name=\"hostname\" value=\"\" maxlength=\"75\"></font></i></td></tr>\n";
	}

	if ( $_ eq $$lang_vars{description_message} ) {
		print "<tr><td>$$lang_vars{description_message}</td><td></td><td><i><font size=\"2\"><input type=\"text\" size=\"15\" name=\"host_descr\" value=\"\" maxlength=\"100\"></font></i></td></tr>\n";
	}

	if ( $_ eq $$lang_vars{loc_message} ) {
		print "<tr><td>$$lang_vars{loc_message}</td><td></td><td><font size=\"2\"><select name=\"loc\" size=\"1\" value=\"\">";
		print "<option></option>";
		my $j=0;
		foreach (@values_locations) {
			print "<option>$values_locations[$j]->[0]</option>" if ( $values_locations[$j]->[0] ne "NULL" );
			$j++;
		}
		print "</select></td></tr>\n";
	}

	if ( $_ eq $$lang_vars{tipo_message} ) {
		print "<tr><td>$$lang_vars{tipo_message}</td><td></td><td><select name=\"cat\" size=\"1\">";
		print "<option></option>";
		$j=0;
		foreach (@values_categorias) {
			print "<option>$values_categorias[$j]->[0]</option>" if ($values_categorias[$j]->[0] ne "NULL" );
			$j++;
		}
		print "</select></td></tr>\n";
	}

	if ( $_ eq "AI" ) {
		print "<tr><td>AI</td><td></td><td><input type=\"checkbox\" name=\"int_admin\" value=\"y\"></td></tr>\n";
	}


	if ( $_ eq $$lang_vars{comentario_message} ) {
		print "<tr><td>$$lang_vars{comentario_message}</td><td></td><td><textarea name=\"comentario\" cols=\"30\" rows=\"5\" wrap=\"physical\" maxlength=\"500\"></textarea></td></tr>";
	}
	if ( $_ eq "UT" ) {
		print "<tr><td>UT</td><td></td><td><select name=\"update_type\" size=\"1\">";
		print "<option></option>";
		$j=0;
		foreach (@values_utype) {
			print "<option>$values_utype[$j]->[0]</option>" if ( $values_utype[$j]->[0] ne "NULL" );
			$j++;
		}
		print "</select>\n";
		print "</td></tr>";
	}
}


print "<td><input name=\"entries_per_page_hosts\" type=\"hidden\" value=\"$entries_per_page_hosts\"><input name=\"start_entry_hosts\" type=\"hidden\" value=\"$start_entry_hosts\"><input name=\"knownhosts\" type=\"hidden\" value=\"$knownhosts\"><input name=\"anz_values_hosts\" type=\"hidden\" value=\"$anz_values_hosts\"></td></tr>\n";


my %cc_value = ();
my @custom_columns = $gip->get_custom_host_columns("$client_id");
%cc_value=$gip->get_custom_host_columns_from_net_id_hash("$client_id","$host_id") if $host_id;

my @vendors = $gip->get_vendor_array();

my $n;
foreach my $mass_element(@mass_update_types) {
	$n=0;
	foreach my $cc_ele(@custom_columns) {
		my $cc_name = $custom_columns[$n]->[0];
		my $pc_id = $custom_columns[$n]->[3];
		my $cc_id = $custom_columns[$n]->[1];
#		my $cc_entry = $cc_value{$cc_id}[1] || "";


		if ( $cc_name eq $mass_element ) {


			if ( $cc_name ) {
				if ( $cc_name eq "vendor" ) {
					my $knownvendor="0";
					my $checked_known="";
					my $checked_unknown="";
					my $disabled_known="";
					my $disabled_unknown="";
					my $cc_entry_unknown="";
					if ( $knownvendor == 1 ) {
						$checked_known="checked";
						$disabled_unknown="disabled";
#					} elsif ( ! $cc_entry  ) {
#						$checked_known="checked";
						$disabled_unknown="disabled";
					} else {
						$checked_unknown="checked";
						$disabled_known="disabled";
#						$cc_entry_unknown=$cc_entry;
					}
					print "<tr><td>$cc_name</td><td> <input type=\"radio\" name=\"vendor_radio\" value=\"known\" onclick=\"${cc_name}_value_known.disabled=false;${cc_name}_value_unknown.value='';${cc_name}_value_unknown.disabled=true;\" $checked_known></td><td>\n";
					print "<input name=\"${cc_name}_id\" type=\"hidden\" value=\"$cc_id\"><input name=\"${cc_name}_pcid\" type=\"hidden\" value=\"$pc_id\">";
					print "<font size=\"2\"><select name=\"${cc_name}_value\" id=\"${cc_name}_value_known\" size=\"1\" $disabled_known>";
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
						print "<option style=\"background: url('../imagenes/vendors/${vendor_img}.png') no-repeat top left;\" value=\"$vendor\">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; $vendor</option>";
						$j++;
					}
					print "</select><input name=\"custom_name\" type=\"hidden\" value=\"$cc_name\"></td></tr>\n";
					print "<tr><td></td><td><input type=\"radio\" name=\"vendor_radio\" value=\"unknown\" onclick=\"${cc_name}_value_known.disabled=true;${cc_name}_value_unknown.disabled=false;document.ip_mod_form.${cc_name}_value_known.options[0].selected = true;\" $checked_unknown></td><td><input type=\"text\" size=\"20\" name=\"${cc_name}_value\" id=\"${cc_name}_value_unknown\" value=\"$cc_entry_unknown\" maxlength=\"500\" $disabled_unknown></td></tr>\n";
				} elsif ( $cc_name eq "URL" ) {
					my @values_url=$gip->get_url_values("$client_id","$mass_update_host_ids","$red_num","$cc_id","$pc_id");
					my $refurl=$values_url[0] || "";
					my $same_urls=0;
					my $url_value="";
					foreach ( @values_url ) {
						if ( $_ ne $refurl ) {
							$same_urls=1;
							last;
						}
					}
					$url_value=$refurl if $same_urls == 0;
					
					print "<tr><td>$cc_name<br>(service::URL)</td><td colspan='2'><input name=\"cc_name\" type=\"hidden\" value=\"$cc_name\"><input name=\"${cc_name}_id\" type=\"hidden\" value=\"$cc_id\"><input name=\"${cc_name}_pcid\" type=\"hidden\" value=\"$pc_id\"><textarea name='${cc_name}_value' cols='50' rows='5' wrap='physical' maxlength='500'>$url_value</textarea></td></tr>\n";
				} else {
					print "<tr><td>$cc_name</td><td></td><td><input name=\"cc_name\" type=\"hidden\" value=\"$cc_name\"><input name=\"${cc_name}_id\" type=\"hidden\" value=\"$cc_id\"><input name=\"${cc_name}_pcid\" type=\"hidden\" value=\"$pc_id\"><input type=\"text\" size=\"20\" name=\"${cc_name}_value\" value=\"\" maxlength=\"500\"></td></tr>\n";
				}
			}
		}
	$n++;
	}
}


# Pass search data

my $hidden_form_fields="";

# call from ip_searchip (advanced)
$hidden_form_fields .= "<input type=\"hidden\" name=\"advanced_search_hostname\" value=\"$daten{'hostname'}\">" if $daten{'hostname'};
# call from ip_modip_mass_update after advanced search 
$hidden_form_fields .= "<input type=\"hidden\" name=\"advanced_search_hostname\" value=\"$daten{'advanced_search_hostname'}\">" if $daten{'advanced_search_hostname'};
$hidden_form_fields .= "<input type=\"hidden\" name=\"advanced_search_host_descr\" value=\"$daten{'host_descr'}\">" if $daten{'host_descr'};
$hidden_form_fields .= "<input type=\"hidden\" name=\"advanced_search_host_descr\" value=\"$daten{'advanced_search_host_descr'}\">" if $daten{'advanced_search_host_descr'};
$hidden_form_fields .= "<input type=\"hidden\" name=\"advanced_search_comentario\" value=\"$daten{'comentario'}\">" if $daten{'comentario'};
$hidden_form_fields .= "<input type=\"hidden\" name=\"advanced_search_comentario\" value=\"$daten{'advanced_search_comentario'}\">" if $daten{'advanced_search_comentario'};
$hidden_form_fields .= "<input type=\"hidden\" name=\"advanced_search_ip\" value=\"$daten{'ip'}\">" if $daten{'ip'};
$hidden_form_fields .= "<input type=\"hidden\" name=\"advanced_search_ip\" value=\"$daten{'advanced_search_ip'}\">" if $daten{'advanced_search_ip'};
$hidden_form_fields .= "<input type=\"hidden\" name=\"advanced_search_loc\" value=\"$daten{'loc'}\">" if $daten{'loc'};
$hidden_form_fields .= "<input type=\"hidden\" name=\"advanced_search_loc\" value=\"$daten{'advanced_search_loc'}\">" if $daten{'advanced_search_loc'};
$hidden_form_fields .= "<input type=\"hidden\" name=\"advanced_search_cat\" value=\"$daten{'cat'}\">" if $daten{'cat'};
$hidden_form_fields .= "<input type=\"hidden\" name=\"advanced_search_cat\" value=\"$daten{'advanced_search_cat'}\">" if $daten{'advanced_search_cat'};
$hidden_form_fields .= "<input type=\"hidden\" name=\"advanced_search_int_admin\" value=\"$daten{'int_admin'}\">" if $daten{'int_admin'};
$hidden_form_fields .= "<input type=\"hidden\" name=\"advanced_search_int_admin\" value=\"$daten{'advanced_search_int_admin'}\">" if $daten{'advanced_search_int_admin'};
$hidden_form_fields .= "<input type=\"hidden\" name=\"advanced_search_hostname_exact\" value=\"$daten{'hostname_exact'}\">" if $daten{'hostname_exact'};
$hidden_form_fields .= "<input type=\"hidden\" name=\"advanced_search_hostname_exact\" value=\"$daten{'advanced_search_hostname_exact'}\">" if $daten{'advanced_search_hostname_exact'};
$hidden_form_fields .= "<input type=\"hidden\" name=\"advanced_search_client_independent\" value=\"$daten{'client_independent'}\">" if $daten{'client_independent'};
$hidden_form_fields .= "<input type=\"hidden\" name=\"advanced_search_client_independent\" value=\"$daten{'advanced_search_client_independent'}\">" if $daten{'advanced_search_client_independent'};

for ( my $k = 0; $k < scalar(@custom_columns); $k++ ) {
	$hidden_form_fields .= "<input type=\"hidden\" name=\"cc_id_$custom_columns[$k]->[1]\" value=\"$daten{\"cc_id_$custom_columns[$k]->[1]\"}\">" if $daten{"cc_id_$custom_columns[$k]->[1]"};
}


print "<tr><td><br><p><input type=\"hidden\" name=\"host_id\" value=\"$host_id\"><input name=\"host_order_by\" type=\"hidden\" value=\"$host_order_by\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"hidden\" name=\"ip_version\" value=\"$ip_version\"><input type=\"hidden\" name=\"search_index\" value=\"$search_index\"><input type=\"hidden\" name=\"search_hostname\" value=\"$search_hostname\"><input type=\"hidden\" name=\"anz_hosts\" value=\"$anz_hosts\"><input type=\"hidden\" name=\"mass_update_type\" value=\"$mass_update_type\"><input type=\"hidden\" name=\"mass_update_host_ids\" value=\"$mass_update_host_ids\"><input type=\"hidden\" name=\"red\" value=\"$red\"><input type=\"hidden\" name=\"BM\" value=\"$BM\"><input type=\"hidden\" name=\"red_num\" value=\"$red_num\">$text_field_number_given_form $hidden_form_fields <input type=\"submit\" value=\"$$lang_vars{cambiar_message}\" name=\"B1\" class=\"input_link_w_net\"></td><td></td></tr>\n";
print "</form>\n";
print "</table>\n";


print "<script type=\"text/javascript\">\n";
print "document.ip_mod_form.hostname.focus();\n";
print "</script>\n";

$gip->print_end("$client_id","$vars_file");
