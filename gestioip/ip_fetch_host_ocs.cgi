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
my %daten=$gip->preparer($daten) if $daten;

my $base_uri = $gip->get_base_uri();
my ($lang_vars,$vars_file)=$gip->get_lang();
my $server_proto=$gip->get_server_proto();

my $client_id = $daten{'client_id'} || $gip->get_first_client_id();
if ( $client_id !~ /^\d{1,4}$/ ) {
        $client_id = 1;
        $gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{fetch_from_ocs_message}","$vars_file");
        $gip->print_error("$client_id","$$lang_vars{formato_malo_message}");
}

my $ip_address=$daten{'ip'};
my $ip_version=$daten{'ip_version'};
my $red_num=$daten{'red_num'};
my $host_id=$daten{'host_id'} || "";
#my $BM=$daten{'BM'};

$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{ocs_data_for_message} $ip_address","$vars_file");

$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (2)") if $ip_version !~ /^(v4|v6)$/;

my ($values_networks,$values_softwares,$values_memories,$values_inputs,$values_storages,$values_videos,$values_sounds,$values_modems,$ocs_MAC)=$gip->get_ocs_values("$client_id","$ip_address","$vars_file");

if ( ! $values_networks ) {
	print "<p class=\"NotifyText\">$$lang_vars{no_ocs_data_message} $ip_address</p>\n";
	$gip->print_end("$client_id");
}


$ocs_MAC="N/A" if ! $ocs_MAC;
my $ocs_name = "N/A";
my $ocs_osname = "N/A";
my $ocs_osversion = "N/A";
my $ocs_workgroup = "N/A";
my $ocs_winowner = "N/A";
my $ocs_wincompany = "N/A";
my $ocs_winprodid = "N/A";
my $ocs_processort = "N/A";
my $ocs_processorn = "N/A";
my $ocs_processors = "N/A";
my $ocs_descr = "N/A";
my $lastdate = "N/A";
$ocs_name = ${$values_networks}{'NAME'} if ${$values_networks}{'NAME'};
$ocs_osname = ${$values_networks}{'OSNAME'} if ${$values_networks}{'OSNAME'};
$ocs_osversion = ${$values_networks}{'OSVERSION'} if ${$values_networks}{'OSVERSION'};
$ocs_workgroup = ${$values_networks}{'WORKGROUP'} if ${$values_networks}{'WORKGROUP'};
$ocs_winowner = ${$values_networks}{'WINOWNER'} if ${$values_networks}{'WINOWNER'};
$ocs_wincompany = ${$values_networks}{'WINCOMPANY'} if ${$values_networks}{'WINCOMPANY'};
$ocs_winprodid = ${$values_networks}{'WINPRODID'} if ${$values_networks}{'WINPRODID'};
$ocs_processort = ${$values_networks}{'PROCESSORT'} if ${$values_networks}{'PROCESSORT'};
$ocs_processorn = ${$values_networks}{'PROCESSORN'} if ${$values_networks}{'PROCESSORN'};
$ocs_processors = ${$values_networks}{'PROCESSORS'} if ${$values_networks}{'PROCESSORS'};
$ocs_descr = ${$values_networks}{'DESCRIPTION'} if ${$values_networks}{'DESCRIPTION'};
$lastdate = ${$values_networks}{'LASTDATE'} if ${$values_networks}{'LASTDATE'};

my $ip_address_int=$gip->ip_to_int("$client_id","$ip_address","$ip_version");

print "<div id=\"OCS_fetch\">\n";

print "<i>$$lang_vars{ocs_data_from_message}: $lastdate</i>\n";

my $hostname_form ="";
my $OS_form ="";
my $OS_version_form ="";
my $MAC_form ="";
my $host_id_form ="";
$hostname_form="<input type=\"hidden\" name=\"hostname\" value=\"$ocs_name\">" if $ocs_osname ne "N/A";
$OS_form="<input type=\"hidden\" name=\"OS\" value=\"$ocs_osname\">" if $ocs_osname ne "N/A";
$OS_version_form="<input type=\"hidden\" name=\"OS_version\" value=\"$ocs_osversion\">" if $ocs_osname ne "N/A";
$MAC_form="<input type=\"hidden\" name=\"MAC\" value=\"$ocs_MAC\">" if $ocs_MAC ne "N/A";
$host_id_form="<input type=\"hidden\" name=\"host_id\" value=\"$host_id\">" if $host_id;

#my %predef_host_columns=$gip->get_predef_host_column_all_hash("$client_id");


print "<form name=\"add_host_form\" method=\"POST\" action=\"$server_proto://$base_uri/res/ip_modip_form.cgi\" style='display:inline;'>\n";
print "<input type=\"hidden\" name=\"ip\" value=\"$ip_address_int\"><input type=\"hidden\" name=\"ip_version\" value=\"$ip_version\"><input type=\"hidden\" name=\"red_num\" value=\"$red_num\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\">${host_id_form} ${hostname_form} ${OS_form} ${OS_version_form} ${MAC_form}<input type=\"submit\" value=\"$$lang_vars{update_entry_message}\" name=\"B2\" class=\"input_link_w_right\"></form><br>\n";


print "<p class=\"headline_ocs_fetch\">$$lang_vars{redes_message}</p>\n";
print <<EOF;
<table cellpadding="10" border="1">
<tr class="ocs_table_head_text"><td>$$lang_vars{name_message}</td><td>$$lang_vars{ip_address_message}</td><td>$$lang_vars{MAC_message}</td></tr>
<tr><td>$ocs_name</td><td>$ip_address</td><td>$ocs_MAC</td></tr>
</table>
EOF


print "<br><p class=\"headline_ocs_fetch\">OS</p>";
print <<EOF;
<table border="1" cellpadding="20">
<tr class="ocs_table_head_text"><td>$$lang_vars{ocs_osname_message}</td><td>$$lang_vars{ocs_osversion_message}</td></tr>
<tr><td>$ocs_osname</td><td>$ocs_osversion</td></tr>
</table>
EOF

if ( $ocs_osname =~ /windows/i ) {
	print "<br><p class=\"headline_ocs_fetch\">$$lang_vars{windows_info_message}</p>";
print <<EOF;
	<table border="1" cellpadding="20">
	<tr class="ocs_table_head_text"><td>$$lang_vars{ocs_workgroup_message}</td><td>$$lang_vars{ocs_winowner_message}</td><td>$$lang_vars{ocs_wincompany_message}</td><td>$$lang_vars{ocs_winprodid_message}</td></tr>
	<tr><td>$ocs_workgroup</td><td>$ocs_winowner</td><td>$ocs_wincompany</td><td>$ocs_winprodid</td></tr>
	</table>
EOF
}



print "<br><p class=\"headline_ocs_fetch\">$$lang_vars{processors_message}</p>";
print <<EOF;
<table border="1" cellpadding="20">
<tr class="ocs_table_head_text"><td>$$lang_vars{description_message}</td><td>$$lang_vars{speed_message}</td><td>$$lang_vars{number_message}</td></tr>
<tr><td>$ocs_processort</td><td>$ocs_processors</td><td>$ocs_processorn</td></tr>
</table>
EOF


print "<br><p class=\"headline_ocs_fetch\">$$lang_vars{memory_message}</p>";

if ( @{$values_memories}[0]->[0] ne "NOVAL"  ) {
print <<EOF;
	<table border="1" cellpadding="20">
	<tr class="ocs_table_head_text"><td>$$lang_vars{description_message}</td><td>$$lang_vars{capacity_message}</td><td>$$lang_vars{tipo_message}</td><td>$$lang_vars{speed_message}</td><td>$$lang_vars{slot_message}</td></tr>
EOF
	my $anz_values_memories=@{$values_memories};
	for (my $i = 0; $i < $anz_values_memories; $i++) {
		my $mem_descr="N/A";
		my $mem_cap="N/A";
		my $mem_tipo="N/A";
		my $mem_speed="N/A";
		my $mem_slot="N/A";
		$mem_descr=${$values_memories}[$i]->[1] if defined(${$values_inputs}[$i]->[1]);
		$mem_cap=${$values_memories}[$i]->[2] if defined(${$values_inputs}[$i]->[2]);
		$mem_tipo=${$values_memories}[$i]->[3] if defined(${$values_inputs}[$i]->[3]);
		$mem_speed=${$values_memories}[$i]->[4] if defined(${$values_inputs}[$i]->[4]);
		$mem_slot=${$values_memories}[$i]->[5] if defined(${$values_inputs}[$i]->[5]);
		print "<tr><td>$mem_descr</td><td>$mem_cap</td><td>$mem_tipo</td><td>$mem_speed</td><td>$mem_slot</td></tr>\n";
	}
	print "</table>\n";
} else {
	print "N/A<br>\n"
}




print "<br><p class=\"headline_ocs_fetch\">$$lang_vars{input_devices_message}</p>";
if ( @{$values_inputs}[0]->[0] ne "NOVAL"  ) {
print <<EOF;
	<table border="1" cellpadding="20">
	<tr class="ocs_table_head_text"><td>$$lang_vars{tipo_message}</td><td>$$lang_vars{manufacturer_message}</td><td>$$lang_vars{description_message}</td><td>INTERFACE</td><td>POINTTYPE $$lang_vars{slot_message}</td></tr>
EOF
	my $anz_values_inputs=@{$values_inputs};
	for (my $i = 0; $i < $anz_values_inputs; $i++) {
		my $inp_tipo="N/A";
		my $inp_manufacturer="N/A";
		my $inp_desc="N/A";
		my $inp_interface="N/A";
		my $inp_ptipo="N/A";
		$inp_tipo=${$values_inputs}[$i]->[1] if defined(${$values_inputs}[$i]->[1]);
		$inp_manufacturer=${$values_inputs}[$i]->[2] if defined(${$values_inputs}[$i]->[2]);
		$inp_desc=${$values_inputs}[$i]->[3] if defined(${$values_inputs}[$i]->[3]);
		$inp_interface=${$values_inputs}[$i]->[4] if defined(${$values_inputs}[$i]->[4]);
		$inp_ptipo=${$values_inputs}[$i]->[5] if defined(${$values_inputs}[$i]->[5]);

		print "<tr><td>$inp_tipo</td><td>$inp_manufacturer</td><td>$inp_desc</td><td>$inp_interface</td><td>$inp_ptipo</td></tr>\n";
	}
	print "</table>\n";
} else {
	print "N/A<br>\n"
}



print "<br><p class=\"headline_ocs_fetch\">$$lang_vars{storage_devices_message}</p>";
if ( @{$values_storages}[0]->[0] ne "NOVAL"  ) {
print <<EOF;
	<table border="1" cellpadding="20">
	<tr class="ocs_table_head_text"><td>$$lang_vars{manufacturer_message}</td><td>$$lang_vars{name_message}</td><td>$$lang_vars{model_message}</td><td>$$lang_vars{description_message}</td><td>$$lang_vars{tipo_message}</td><td>$$lang_vars{size_message}</td></tr>
EOF
	my $anz_values_storages=@{$values_storages};
	for (my $i = 0; $i < $anz_values_storages; $i++) {
		my $sto_manufacturer="N/A";
		my $sto_name="N/A";
		my $sto_model="N/A";
		my $sto_desc="N/A";
		my $sto_tipo="N/A";
		my $sto_size="N/A";
		$sto_manufacturer="@{$values_storages}[$i]->[1]" if defined(@{$values_storages}[$i]->[1]);
		$sto_name="@{$values_storages}[$i]->[2]" if defined(@{$values_storages}[$i]->[2]);
		$sto_model="@{$values_storages}[$i]->[3]" if defined(@{$values_storages}[$i]->[3]);
		$sto_desc="@{$values_storages}[$i]->[4]" if defined(@{$values_storages}[$i]->[4]);
		$sto_tipo="@{$values_storages}[$i]->[5]" if defined(@{$values_storages}[$i]->[5]);
		$sto_size="@{$values_storages}[$i]->[6]" if defined(@{$values_storages}[$i]->[6]);
		$sto_manufacturer="N/A" if $sto_manufacturer =~ /unidades/i;
		print "<tr><td>$sto_manufacturer</td><td>$sto_name</td><td>$sto_model</td><td>$sto_desc</td><td>$sto_tipo</td><td>$sto_size</td></tr>\n";
	}
	print "</table>\n";
} else {
	print "N/A<br>\n"
}

print "<br><p class=\"headline_ocs_fetch\">$$lang_vars{video_devices_message}</p>";
if ( @{$values_videos}[0]->[0] ne "NOVAL"  ) {
print <<EOF;
	<table border="1" cellpadding="20">
	<tr class="ocs_table_head_text"><td>$$lang_vars{name_message}</td><td>$$lang_vars{memory_message}</td><td>$$lang_vars{chipset_message}</td><td>$$lang_vars{resolution_message}</td></tr>
EOF
	my $anz_values_videos=@{$values_videos};
	for (my $i = 0; $i < $anz_values_videos; $i++) {
		my $vid_name="N/A";
		my $vid_memory="N/A";
		my $vid_chipset="N/A";
		my $vid_res="N/A";
		$vid_name=@{$values_videos}[$i]->[1] if defined(@{$values_videos}[$i]->[1]);
		$vid_memory=@{$values_videos}[$i]->[2] if defined(@{$values_videos}[$i]->[2]);
		$vid_chipset=@{$values_videos}[$i]->[3] if defined(@{$values_videos}[$i]->[3]);
		$vid_res=@{$values_videos}[$i]->[4] if defined(@{$values_videos}[$i]->[4]);
		print "<tr><td>$vid_name</td><td>$vid_memory</td><td>$vid_chipset</td><td>$vid_res</td></tr>\n";
	}
	print "</table>\n";
} else {
	print "N/A<br>\n"
}


print "<br><p class=\"headline_ocs_fetch\">$$lang_vars{sound_devices_message}</p>";
if ( @{$values_sounds}[0]->[0] ne "NOVAL"  ) {
print <<EOF;
	<table border="1" cellpadding="20">
	<tr class="ocs_table_head_text"><td>$$lang_vars{manufacturer_message}</td><td>$$lang_vars{name_message}</td><td>$$lang_vars{description_message}</td></tr>
EOF
	my $anz_values_sounds=@{$values_sounds};
	for (my $i = 0; $i < $anz_values_sounds; $i++) {
		my $so_manufacturer="N/A";
		my $so_name="N/A";
		my $so_desc="N/A";
		$so_manufacturer=@{$values_sounds}[$i]->[1] if defined(@{$values_sounds}[$i]->[1]);
		$so_name=@{$values_sounds}[$i]->[2] if defined(@{$values_sounds}[$i]->[2]);
		$so_desc=@{$values_sounds}[$i]->[3] if defined(@{$values_sounds}[$i]->[3]);

		print "<tr><td>$so_manufacturer</td><td>$so_name</td><td>$so_desc</td></tr>\n";
	}
	print "</table>\n";
} else {
	print "N/A<br>\n"
}

print "<br><p class=\"headline_ocs_fetch\">$$lang_vars{modems_message}</p>";
if ( @{$values_modems}[0]->[0] ne "NOVAL"  ) {
print <<EOF;
	<table border="1" cellpadding="20">
	<tr class="ocs_table_head_text"><td>$$lang_vars{name_message}</td><td>$$lang_vars{model_message}</td><td>$$lang_vars{description_message}</td><td>$$lang_vars{tipo_message}</td></tr>
EOF
	my $anz_values_modems=@{$values_modems};
	for (my $i = 0; $i < $anz_values_modems; $i++) {
		my $mo_name="N/A";
		my $mo_model="N/A";
		my $mo_desc="N/A";
		my $mo_tipo="N/A";
		$mo_name=@{$values_modems}[$i]->[1] if defined(@{$values_modems}[$i]->[1]);
		$mo_model=@{$values_modems}[$i]->[2] if defined(@{$values_modems}[$i]->[2]);
		$mo_desc=@{$values_modems}[$i]->[3] if defined(@{$values_modems}[$i]->[3]);
		$mo_tipo=@{$values_modems}[$i]->[4] if defined(@{$values_modems}[$i]->[4]);
		print "<tr><td>$mo_name</td><td>$mo_model</td><td>$mo_desc</td><td>$mo_tipo</td></tr>\n";
	}
	print "</table>\n";
} else {
	print "N/A<br>\n"
}

print "<br><p class=\"headline_ocs_fetch\">$$lang_vars{installed_software_message}</p>";
if ( @{$values_softwares}[0]->[0] ne "NOVAL"  ) {
print <<EOF;
	<table border="1" cellpadding="20">
	<tr class="ocs_table_head_text"><td>$$lang_vars{name_message}</td><td>$$lang_vars{version_message}</td></tr>
EOF
	my $anz_values_softwares=@{$values_softwares};
	for (my $i = 0; $i < $anz_values_softwares; $i++) {
		my $soft_name="N/A";
		my $soft_version="N/A";
		$soft_name=@{$values_softwares}[$i]->[1] if defined(@{$values_softwares}[$i]->[2]);
		$soft_version=@{$values_softwares}[$i]->[2] if defined(@{$values_softwares}[$i]->[2]);
		print "<tr><td>$soft_name</td><td>$soft_version</td></tr>\n";
	}
	print "</table>\n";
} else {
	print "N/A<br>\n"
}

print "</div>\n";

$gip->print_end("$client_id");
