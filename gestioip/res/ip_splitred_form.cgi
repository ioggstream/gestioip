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

my $daten=<STDIN>;
my $gip = GestioIP -> new();
my %daten=$gip->preparer($daten) if $daten;

my $base_uri = $gip->get_base_uri();
my $server_proto=$gip->get_server_proto();

my $lang = $daten{'lang'} || "";
my ($lang_vars,$vars_file)=$gip->get_lang("","$lang");

my $client_id = $daten{'client_id'} || $gip->get_first_client_id();

if ( $client_id !~ /^\d{1,4}$/ ) {
	$client_id = 1;
	$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{redes_message}","$vars_file");
	$gip->print_error("$client_id","$$lang_vars{formato_malo_message}");
}

my $ip_version_ele = $daten{'ip_version_ele'} || $gip->get_ip_version_ele();

my $red_num = "";
$red_num=$daten{'red_num'} if $daten{'red_num'};

if ( $red_num !~ /^\d{1,5}$/ ) {
        $gip->print_init("gestioip","$$lang_vars{split_red_message}","$$lang_vars{split_red_message}","$vars_file","$client_id");
        $gip->print_error("$client_id",$$lang_vars{formato_red_malo_message}) ;
}

my @values_redes = $gip->get_red("$client_id","$red_num");
my $red = "$values_redes[0]->[0]" || "";
my $BM = "$values_redes[0]->[1]" || "";
my $descr = "$values_redes[0]->[2]" || "";
my $loc_id = "$values_redes[0]->[3]" || "";
my $loc = $gip->get_loc_from_id("$client_id","$loc_id") || "NULL";
my $cat_id = "$values_redes[0]->[6]" || "";
my $cat = $gip->get_cat_net_from_id("$client_id","$cat_id") || "NULL";
my $ip_version = "$values_redes[0]->[7]" || "";
my $order_by=$daten{'order_by'} || 'red_auf';

$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{split_red_message} $red/$BM","$vars_file");

$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (version_ele)") if $ip_version_ele !~ /^(v4|v6|46)$/;

if ( $BM >= 32  && $ip_version eq "v4") {
        $gip->print_error("$client_id","$$lang_vars{bm_no_split_message}");
} elsif ( $BM >= 126  && $ip_version eq "v6") {
        $gip->print_error("$client_id","$$lang_vars{bm_no_split_ipv6_message}");
}


my $start_entry=$daten{'start_entry'} || '0';
$gip->print_error("$client_id",$$lang_vars{formato_malo_message}) if $start_entry !~ /^\d{1,4}$/;

print "<p><b>$$lang_vars{split_net_same_bm}</b><p>\n";

my $smallest_valid_BM = $BM + 1;
my %anz_hosts_bm = $gip->get_anz_hosts_bm_hash("$client_id","$ip_version");
my $anz_hosts_freerange=$anz_hosts_bm{"$BM"};
$anz_hosts_freerange =~ s/,//g;
$anz_hosts_freerange = Math::BigInt->new("$anz_hosts_freerange");
my ($anz_host_freerange_part,$BM_freerange,$anz_possible_nets,$bm_i_message);
my %possible_nets;
foreach my $key (sort {$a <=> $b} keys %anz_hosts_bm ) {
	my $anz_host_freerange_key = $anz_hosts_bm{$key};
	$anz_host_freerange_key =~ s/,//g;
	$anz_host_freerange_key = Math::BigInt->new("$anz_host_freerange_key");
#	next if $anz_hosts_freerange <= $anz_host_freerange_key;
	next if $anz_hosts_freerange < $anz_host_freerange_key;
	if ( $key == 31 ) {
		$possible_nets{$key} = $anz_hosts_freerange / 2;
	} elsif ( $key == 32 ) {
		$possible_nets{$key} = $anz_hosts_freerange / $anz_host_freerange_key;
		$anz_host_freerange_key=2 if $BM == 31;
	} else {
		$possible_nets{$key} = $anz_hosts_freerange / $anz_host_freerange_key;
		$possible_nets{$key} =~ s/\..*//;
	}
}


my $BM_message="$$lang_vars{BM_message}";
$BM_message="$$lang_vars{prefix_length_message}" if $ip_version eq "v6";

print "<p><form name=\"splitred_form\" method=\"POST\" action=\"$server_proto://$base_uri/res/ip_splitred_check.cgi\">\n";
print "<table border=\"0\">\n";
print "<tr><td align=\"right\">$BM_message</td><td><select name=\"new_bm\" size=\"1\">\n";
if ( $ip_version eq "v4" ) {
	for (my $i = $smallest_valid_BM; $i <=32; $i++) {
		if ( $i =~ /^\d$/ ) {
			$bm_i_message = "bm_0" . $i . "_message";
		} else {
			$bm_i_message = "bm_" . $i . "_message";
		}

		last if $possible_nets{$i} > 50;

		if ( $i eq $smallest_valid_BM ) {
			print "<option value=\"$i:$possible_nets{$i}\" selected>$i ($$lang_vars{$bm_i_message}) $possible_nets{$i} $$lang_vars{redes_dispo_message}</option>";
			next;
		}
		print "<option value=\"$i:$possible_nets{$i}\">$i ($$lang_vars{$bm_i_message}) $possible_nets{$i} $$lang_vars{redes_dispo_message}</option>";
	}
} else {
	for (my $i = $smallest_valid_BM; $i < 127; $i++) {
#		if ( $i =~ /^\d$/ ) {
#			$bm_i_message = "bm_0" . $i . "_message";
#		} else {
#			$bm_i_message = "bm_" . $i . "_message";
#		}

		my $possible_nets=$possible_nets{$i};
		$possible_nets =~ s/,//g;
		$possible_nets = Math::BigInt->new("$possible_nets");
		last if $possible_nets > 50;

		if ( $i eq $smallest_valid_BM ) {
			print "<option value=\"$i:$possible_nets{$i}\" selected>$i ($anz_hosts_bm{$i} hosts) $possible_nets{$i} $$lang_vars{redes_dispo_message}</option>";
			next;
		}
		print "<option value=\"$i:$possible_nets{$i}\">$i ($anz_hosts_bm{$i} hosts) $possible_nets{$i} $$lang_vars{redes_dispo_message}</option>";
	}
}
print "</select></td></tr>\n";
print "</table>\n";

print "<br><input name=\"split_type\" type=\"hidden\" value=\"same_bm\"><input name=\"red\" type=\"hidden\" value=\"$red/$BM\"><input name=\"start_entry\" type=\"hidden\" value=\"$start_entry\"><input name=\"loc\" type=\"hidden\" value=\"$loc\"><input name=\"cat\" type=\"hidden\" value=\"$cat\"><input name=\"order_by\" type=\"hidden\" value=\"$order_by\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input name=\"ip_version\" type=\"hidden\" value=\"$ip_version\"><input name=\"ip_version_ele\" type=\"hidden\" value=\"$ip_version_ele\"><input type=\"submit\" value=\"$$lang_vars{next_message}\" name=\"B2\" class=\"input_link_w\">&nbsp;&nbsp;&nbsp;&nbsp<input type=\"checkbox\" name=\"keep_loc\" value=\"y\" checked><span class=\"HintText\">$$lang_vars{keep_loc_message}</span>&nbsp;&nbsp;&nbsp;&nbsp<input type=\"checkbox\" name=\"keep_cat\" value=\"y\" checked><span class=\"HintText\">$$lang_vars{keep_cat_message}</span>\n";
print "</form>\n";

print "<p><br><p><b>$$lang_vars{split_net_different_bm}</b><p>\n";

my $bitmasks_message=$$lang_vars{bitmasks_message};
$bitmasks_message="$$lang_vars{prefix_lengths_message}" if $ip_version eq "v6";

print "<p><form name=\"splitred_form\" method=\"POST\" action=\"$server_proto://$base_uri/res/ip_splitred_check.cgi\">\n";
print "<table border=\"0\">\n";
print "<tr><td>$bitmasks_message <input name=\"bitmasks\" type=\"text\"  size=\"20\" maxlength=\"200\"></td></tr>\n";
print "</table>\n";
print "<br><input name=\"split_type\" type=\"hidden\" value=\"different_bm\"><input name=\"red\" type=\"hidden\" value=\"$red/$BM\"><input name=\"start_entry\" type=\"hidden\" value=\"$start_entry\"><input name=\"loc\" type=\"hidden\" value=\"$loc\"><input name=\"cat\" type=\"hidden\" value=\"$cat\"><input name=\"order_by\" type=\"hidden\" value=\"$order_by\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input name=\"ip_version\" type=\"hidden\" value=\"$ip_version\"><input name=\"ip_version_ele\" type=\"hidden\" value=\"$ip_version_ele\"><input type=\"submit\" value=\"$$lang_vars{next_message}\" name=\"B2\" class=\"input_link_w\">&nbsp;&nbsp;&nbsp;&nbsp<input type=\"checkbox\" name=\"keep_loc\" value=\"y\" checked><span class=\"HintText\">$$lang_vars{keep_loc_message}</span>&nbsp;&nbsp;&nbsp;&nbsp<input type=\"checkbox\" name=\"keep_cat\" value=\"y\" checked><span class=\"HintText\">$$lang_vars{keep_cat_message}</span>\n";
print "</form>\n";
print "<table><tr><td>\n";
if ( $ip_version eq "v4" ) {
	print "<p><br>$$lang_vars{bitmasks_expl_message}<p>\n";
} else {
	print "<p><br>$$lang_vars{bitmasks_v6_expl_message}<p>\n";
}
print "</table>\n";


print "<script type=\"text/javascript\">\n";
print "document.splitred_form.bitmasks.focus();\n";
print "</script>\n";

$gip->print_end("$client_id","$vars_file");
