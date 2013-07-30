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
use POSIX qw(strftime);
use POSIX;
use lib './modules';
use GestioIP;
use Net::IP qw(:PROC);

my $daten=<STDIN>;
my $gip = GestioIP -> new();
my %daten=$gip->preparer("$daten") if $daten;

my $lang = $daten{'lang'} || "";
my ($lang_vars,$vars_file)=$gip->get_lang("","$lang");
my $server_proto=$gip->get_server_proto();

my $client_id = $daten{'client_id'} || $gip->get_first_client_id();
my $ip_version = $daten{'ip_version'} || '';

if ( $daten{'ip'} !~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}(\/\d{1,2})?$/ && $ip_version eq "v4" ) {
	$gip->print_init("gestioip","$$lang_vars{historia_message}","$$lang_vars{historia_message}","$vars_file","$client_id");
	$gip->print_error("$client_id","$$lang_vars{formato_ip_malo_message}") ;
} elsif  ( $ip_version eq "v6" ) {
	my $valid_v6_check=$daten{'ip'};
	$valid_v6_check =~ s/\/\d{1,3}//;
	my $valid_v6 = $gip->check_valid_ipv6("$valid_v6_check") || "0";
	if ( $valid_v6 ne 1 ) {
		$gip->print_init("gestioip","$$lang_vars{historia_message}","$$lang_vars{historia_message}","$vars_file","$client_id");
		$gip->print_error("$client_id","$$lang_vars{formato_ip_malo_message} $daten{'ip'}") ;
	}
#} else {
#	$gip->print_init("gestioip","$$lang_vars{historia_message}","$$lang_vars{historia_message}","$vars_file","$client_id");
#	$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (0)") ;
}


my $ip=$daten{'ip'} || '';

### PING HISTORY PATCH to add ping status changes to host history####
### require new event_type: INSERT INTO event_types (id,event_type) VALUES (100,"ping status changed");
### disabled 0; enabled 1;
my $enable_ping_history=0;
my $ping_status_only=$daten{'ping_status_only'} || '';

$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{historia_message} $ip","$vars_file");

$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (1)") if $ip_version !~ /^(v4|v6)$/;

my $entries_per_page=$daten{'entries_per_page'} || '100';
$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (2)") if $entries_per_page !~ /^\d{1,4}$/;
my $start_entry=$daten{'start_entry'} || '0';
$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (3)") if $start_entry !~ /^\d{1,4}$/;


my $datetime = time();
my $time_range_search = "a.date BETWEEN 1253243098 AND " . $datetime;

my @search;
$ip = ip_expand_address ($ip,6) if $ip_version eq "v6";
my $ip_search_expr=$ip;
$ip_search_expr =~ s/\./\\\\./g;

#my $ip_search = "REGEXP \"\[\[:<:\]\]$ip_search_expr\[\[:>:\]\]\"";
my $ip_search = "REGEXP \"^(mass update.+)*$ip_search_expr\[\[:>:\]\]\"";

my $ping_status_checked="";
$search[0]="search_string:X-X:$ip_search";
if ( $ping_status_only eq "yes" ) {
	$search[1]="event_type:X-X:ping status changed";
	$ping_status_checked="checked";
}
my @values_audit;

my $update_type_audit=$daten{'update_type_audit'} || "all";
$update_type_audit="all" if $update_type_audit !~ /[a-z]{3}/;

@values_audit=$gip->search_db_audit("$client_id","$time_range_search",\@search,$start_entry,$entries_per_page,$update_type_audit);
my $anz_values_audit = pop(@values_audit);

my $pages_links;
my $l = "0";
my $m = "0";
my $n = "1";
my $start_title;
my $cgi = "$ENV{SERVER_NAME}" . "$ENV{SCRIPT_NAME}";
if ( $anz_values_audit > $entries_per_page ) {
	while ( $l <= $anz_values_audit ) {
		$m = $l + $entries_per_page;
		$start_title = $l +1;
		if ( $n >= 100 ) {
 			$pages_links = $pages_links . "&nbsp;<span class=\"audit_page_link\" title=\"RESULT LIMITED TO $l ENTRIES\">$n</span>&nbsp;\n";
 			last;
 		}

		if ( $pages_links  && $l != $start_entry ) {
			$pages_links = $pages_links . "<form name=\"printredtabheadform\" method=\"POST\" action=\"$server_proto://$cgi\" style=\"display:inline\"><input type=\"submit\" value=\"$n\" name=\"B2\" class=\"audit_page_link\" title=\"$start_title-$m\"><input name=\"ip\" type=\"hidden\" value=\"$ip\"><input name=\"entries_per_page\" type=\"hidden\" value=\"$entries_per_page\"><input name=\"start_entry\" type=\"hidden\" value=\"$l\"><input name=\"update_type_audit\" type=\"hidden\" value=\"$update_type_audit\"><input name=\"ip_version\" type=\"hidden\" value=\"$ip_version\"></form>";
		} elsif ( $pages_links  && $l == $start_entry ) {
			$pages_links = $pages_links . "&nbsp;<span class=\"audit_page_link_actual\" title=\"$start_title-$m\">$n</span>&nbsp;";
		} elsif ( ! $pages_links  && $l == $start_entry ) {
			$pages_links = "&nbsp;<span class=\"audit_page_link_actual\" title=\"$start_title-$m\">$n</span>&nbsp;";
		} elsif ( ! $pages_links  && $l != $start_entry ) {
			$pages_links = "<form name=\"printredtabheadform\" method=\"POST\" action=\"$server_proto://$cgi\" style=\"display:inline\"><input type=\"submit\" value=\"$n\" name=\"B2\" class=\"audit_page_link\" title=\"$start_title-$m\"><input name=\"ip\" type=\"hidden\" value=\"$ip\"><input name=\"entries_per_page\" type=\"hidden\" value=\"$entries_per_page\"><input name=\"start_entry\" type=\"hidden\" value=\"$l\"><input name=\"update_type_audit\" type=\"hidden\" value=\"$update_type_audit\"><input name=\"ip_version\" type=\"hidden\" value=\"$ip_version\"></form>";
		}
		$l = $l + $entries_per_page;
		$n++;
	}
}
$pages_links = "&nbsp;" if ! $pages_links;


my @values_entries_per_page = ("10","50","100","250");
my @update_types_audit = $gip->get_audit_update_types("$client_id");

if ( $values_audit[0] ) {
	print "<p>\n";
	print "<form name=\"printredtabheadform\" method=\"POST\" action=\"$server_proto://$cgi\"><input name=\"ip\" type=\"hidden\" value=\"$ip\">\n";
	print "<table cellspacing=\"0\" cellpadding=\"0\" border=\"0\" style=\"border-collapse:collapse\"><tr>\n";
	print "<td height=\"20px\">$$lang_vars{entradas_por_pagina_message} </td><td>";
	print "&nbsp;<select name=\"entries_per_page\" size=\"1\">";
	my $i = "0";
	foreach (@values_entries_per_page) {
		if ( $_ eq $entries_per_page ) {
			print "<option selected>$values_entries_per_page[$i]</option>";
		} else {
			print "<option>$values_entries_per_page[$i]</option>";
		}
		$i++;
	}
	print "</select>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td>\n";
#	print "<td>\n";
#	print "$$lang_vars{update_types_message}</td><td>\n";
#	print "&nbsp;<select name=\"update_type_audit\" size=\"1\">\n";
#	print "<option></option>\n";
#	$i = "0";
#	foreach (@update_types_audit) {
#		if ( $update_types_audit[$i]->[0] eq $update_type_audit ) {
#			print "<option selected>$update_types_audit[$i]->[0]</option>";
#			$i++;
#			next;
#		}
#		print "<option>$update_types_audit[$i]->[0]</option>";
#		$i++;
#	}
#	print "</select>&nbsp;</td>\n";

	if ( $enable_ping_history == 1 ) {
		print "<td>$$lang_vars{ping_events_only_message}<input type=\"checkbox\" name=\"ping_status_only\" value=\"yes\" $ping_status_checked></td>\n";
	}
	print "<td><input name=\"ip_version\" type=\"hidden\" value=\"$ip_version\">\n";
	print "<input type=\"submit\" value=\"\" title=\"$$lang_vars{submit_message}\" name=\"B2\" class=\"filter_button\"></td></form>\n";
	print "</tr></table>\n";
	print "<table cellspacing=\"0\" cellpadding=\"0\" border=\"0\" style=\"border-collapse:collapse\"><tr><td>$pages_links</td></tr>\n";
	print "</table>\n";
	print "<br>\n" if $pages_links ne "&nbsp;";


	print "<table cellspacing=\"0\" cellpadding=\"0\" border=\"0\" style=\"border-collapse:collapse\" width=\"100%\"><tr><td><b>$$lang_vars{date_message}&nbsp;</b></td><td>&nbsp;<b>$$lang_vars{user_message}</b>&nbsp;</td><td>&nbsp;<b>$$lang_vars{event_type_message}</b>&nbsp;</td><td>&nbsp;<b>$$lang_vars{class_message}</b>&nbsp;</td><td>&nbsp;<b>$$lang_vars{event_message}</b>&nbsp;&nbsp;</td><td>&nbsp;<b>$$lang_vars{value_message}</b></td></tr>\n";

	my $color="white";
	my $k="0";
	foreach (@values_audit) {
		if ( $color eq "white" ) {
			$color = "#f2f2f2";
		} else {
			$color = "white";
		}
		my $event_value=$values_audit[$k]->[0];
		my $user=$values_audit[$k]->[1];
		my $date=scalar localtime ($values_audit[$k]->[2]);
		my $event_class=$values_audit[$k]->[3];
		my $event=$values_audit[$k]->[4];
		my $event_type=$values_audit[$k]->[5];
		print "<tr bgcolor=\"$color\"><td nowrap>$date&nbsp;</td><td nowrap>&nbsp;$user&nbsp;</td><td nowrap>&nbsp;$event_type&nbsp;</td><td nowrap>&nbsp;$event_class&nbsp;</td><td nowrap>&nbsp;$event&nbsp;&nbsp;</td><td>$event_value</td></tr>\n";
		$k++;
	}
	print "</table>\n";
} else {
	print "<p class=\"NotifyText\">$$lang_vars{no_entradas_historia}</p>\n";
}

print "<p><br><p><FORM><INPUT TYPE=\"BUTTON\" VALUE=\"$$lang_vars{atras_message}\" ONCLICK=\"history.go(-1)\" class=\"error_back_link\"></FORM>\n";

$gip->print_end("$client_id");
