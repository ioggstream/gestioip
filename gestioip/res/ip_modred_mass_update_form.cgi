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
my %daten=$gip->preparer($daten);

my $base_uri = $gip->get_base_uri();
my $server_proto=$gip->get_server_proto();

my $lang = $daten{'lang'} || "";
my ($lang_vars,$vars_file)=$gip->get_lang("","$lang");

my $order_by=$daten{'order_by'} || "red_auf";


my $client_id = $daten{'client_id'} || $gip->get_first_client_id();
my $ip_version_ele = $daten{'ip_version_ele'} || $gip->get_ip_version_ele();


$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{network_mass_update_message}","$vars_file");

my $mass_update_type=$daten{'mass_update_type'};
$gip->print_error("$client_id","$$lang_vars{select_mass_update_type}") if ! $mass_update_type;
my @mass_update_types=();
if ( $mass_update_type =~ /_/ ) {
	@mass_update_types=split("_",$mass_update_type);
} else {
	$mass_update_types[0]=$mass_update_type;
}
my $anz_nets=$daten{'anz_nets'} || "0";


my $k;
my $j=0;
my $mass_update_network_ids="";
for ($k=0;$k<=$anz_nets;$k++) {
	if ( $daten{"mass_update_red_submit_${k}"} ) {
		$mass_update_network_ids.=$daten{"mass_update_red_submit_${k}"} . "_";
		$j++;
	}
}
$mass_update_network_ids =~ s/_$//;
$gip->print_error("$client_id","$$lang_vars{select_network_message}") if ! $mass_update_network_ids;
$gip->print_error("$client_id","$$lang_vars{formato_malo_message} $mass_update_network_ids (1)") if ($mass_update_network_ids !~ /[0-9_]/ );

$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (2)") if $ip_version_ele !~ /^(v4|v6|46)$/ ;

my $start_entry=$daten{'start_entry'} || '0';
$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (3)") if $start_entry !~ /^\d{1,4}$/;

my @values_locations=$gip->get_loc("$client_id");
my @values_utype=$gip->get_utype();
my @values_cat_net=$gip->get_cat_net("$client_id");

my $color = "white";
print "<p><br>\n";
print "<form  method=\"POST\" action=\"$server_proto://$base_uri/res/ip_modred_mass_update.cgi\">\n";
print "<table border=\"0\" cellpadding=\"1\">\n";

foreach (@mass_update_types) {
	if ( $_ eq $$lang_vars{description_message} ) {
		print "<tr><td>$$lang_vars{description_message}</td><td><input type=\"text\" size=\"25\" name=\"descr\" value=\"\" maxlength=\"100\">\n";
	}
	if ( $_ eq $$lang_vars{loc_message} ) {
		print "<tr><td>$$lang_vars{loc_message}</td><td><select name=\"loc\" size=\"1\">\n";
		print "<option></option>"; 
			
		my $j=0;
		foreach (@values_locations) {
			if ( $values_locations[$j]->[0] eq "NULL") {
				$j++;
				next;
			}
			print "<option>$values_locations[$j]->[0]</option>";
			$j++;
		}
		print "</select>\n";
		print "</td></tr>";
	}
	if ( $_ eq $$lang_vars{cat_message} ) {
		print "<tr><td>$$lang_vars{cat_message}</td><td><select name=\"cat_net\" size=\"1\">\n";
		print "<option></option>"; 

		my $j=0;
		foreach (@values_cat_net) {
			if ( $values_cat_net[$j]->[0] eq "NULL") {
				$j++;
				next;
			}
			print "<option>$values_cat_net[$j]->[0]</option>";
			$j++;
		}
		print "</select>\n";
		print "</td></tr>";
	}
	if ( $_ eq $$lang_vars{comentario_message} ) {
		print "<tr><td>$$lang_vars{comentario_message}</td><td><textarea name=\"comentario\" cols=\"30\" rows=\"5\" wrap=\"physical\" maxlength=\"500\"></textarea>";
		print "</td></tr>";
	}
	if ( $_ eq $$lang_vars{sinc_message} ) {
		print "<tr><td>$$lang_vars{sinc_message}</td><td><input type=\"checkbox\" name=\"vigilada\" value=\"y\"></td></tr>\n";
	}
}


print "</table>\n";


print "<table border=\"0\" cellpadding=\"1\">\n";

my @custom_columns = $gip->get_custom_columns("$client_id");

my $n;
foreach my $mass_element(@mass_update_types) {
	$n=0;
	foreach my $cc_ele(@custom_columns) {
		my $cc_name = $custom_columns[$n]->[0];
		my $cc_id = $custom_columns[$n]->[1];
		if ( $cc_name eq $mass_element ) {
			if ( $cc_name eq "vlan" ) {
				$n++;
				next;
			}
	
			print "<tr><td><b>$cc_name</b></td><td><input name=\"cc_name\" type=\"hidden\" value=\"$cc_name\"><input name=\"custom_${n}_id\" type=\"hidden\" value=\"$cc_id\"><input type=\"text\" size=\"20\" name=\"${cc_name}_value\" value=\"\" maxlength=\"500\"></td></tr>\n";
		}
		$n++;
	}
}

my $cc_anz=$n;

print "<tr><td><p><br><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"hidden\" name=\"ip_version_ele\" value=\"$ip_version_ele\"><input type=\"hidden\" name=\"anz_nets\" value=\"$j\"><input type=\"hidden\" name=\"mass_update_type\" value=\"$mass_update_type\"><input type=\"hidden\" name=\"cc_anz\" value=\"$cc_anz\"><input type=\"hidden\" name=\"start_entry\" value=\"$start_entry\">\n";
print "<input type=\"hidden\" name=\"mass_update_network_ids\" value=\"$mass_update_network_ids\">\n";
print "<input type=\"submit\" value=\"$$lang_vars{cambiar_message}\" name=\"B1\" class=\"input_link_w_net\"></td><td></td></tr>\n";
print "</table>\n";
print "</form>\n";

$gip->print_end("$client_id","$vars_file");
