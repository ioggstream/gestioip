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
use lib '../modules';
use GestioIP;

my $daten=<STDIN>;
my $gip = GestioIP -> new();
my %daten=$gip->preparer("$daten") if $daten;

my $lang = $daten{'lang'} || "";
my ($lang_vars,$vars_file)=$gip->get_lang("","$lang");
my $server_proto=$gip->get_server_proto();

my $client_id = $daten{'client_id'} || $gip->get_first_client_id();

$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{audit_message}","$vars_file");

my $align="align=\"right\"";
my $align1="";
my $ori="left";
my $rtl_helper="<font color=\"white\">x</font>";
if ( $vars_file =~ /vars_he$/ ) {
	$align="align=\"left\"";
	$align1="align=\"right\"";
	$ori="right";
}


my $time_range=$daten{'time_range'} || "4 weeks";
my $search=$daten{'search_string'} || 'NULL';
$search =~ s/^\+//;
$search =~ s/^\s*//;
my $all_clients=$daten{'all_clients'} || 'nn';
my $start_date=$daten{'start_date'} || '';
my $end_date=$daten{'end_date'} || '';
my $event_class=$daten{'event_class'} || 'NULL';
my $event=$daten{'event_type'} || 'NULL';
my $time_radio=$daten{'time_radio'} || "time_range";
my $entries_per_page=$daten{'entries_per_page'} || '100';
my $start_entry=$daten{'start_entry'} || '0';
my $update_type_audit=$daten{'update_type_audit'} || "all";
$update_type_audit="all" if $update_type_audit !~ /[a-z]{3,10}/;


my $datetime = time();
my $range_sec = $datetime;
my $datetime_start = $datetime - 1209600;
my $start_date_form = strftime "%d/%m/%Y %H:%M", localtime($datetime_start);
my $end_date_form = strftime "%d/%m/%Y %H:%M", localtime($datetime);
my ($time_range_start,$time_range_search,$time_range_audit_head);
if ( $time_radio eq "time_range" ) { 
	$time_range_audit_head = $time_range;
	if ( $time_range eq "1 hour" ) {
		$range_sec="3600";
	} elsif ( $time_range eq "6 hours" ) {
		$range_sec="21600";
	} elsif ( $time_range eq "1 day" ) {
		$range_sec="86400";
	} elsif ( $time_range eq "3 days" ) {
		$range_sec="259200";
	} elsif ( $time_range eq "7 days" ) {
		$range_sec="604800";
	} elsif ( $time_range eq "2 weeks" ) {
		$range_sec="1209600";
	} elsif ( $time_range eq "4 weeks" ) {
		$range_sec="2419200";
	} elsif ( $time_range eq "3 month" ) {
		$range_sec="7257600";
	} elsif ( $time_range eq "6 month" ) {
		$range_sec="14515200";
	} elsif ( $time_range eq "1 year" ) {
		$range_sec="29030400";
	} elsif ( $time_range eq "all" ) {
		$range_sec=time();
	} else {
		$gip->print_error("$client_id","$$lang_vars{formato_malo_message}")
	}
	$time_range_start = $datetime - $range_sec;
	$time_range_search = "a.date BETWEEN " . $time_range_start . " AND " . $datetime;
} elsif ( $time_radio eq "start_end_time" ) {
	$time_range_audit_head = "4 weeks";
	$start_date_form=$start_date;
	$end_date_form=$end_date;
	$gip->print_error("$client_id","$$lang_vars{audit_date_mal_message}") if $start_date !~ /\d{2}\/\d{2}\/\d{4}\s\d{2}:\d{2}/; 
	$start_date =~ /(\d{2})\/(\d{2})\/(\d{4})\s(\d{2}):(\d{2})/; 
	my $s_day=$1;
	my $s_month=$2 -1;
	my $s_year=$3 - 1900;
	my $s_hour=$4;
	my $s_minute=$5;
	my $s_sec="00";
	my $start_date_unix = mktime ($s_sec, $s_minute, $s_hour, $s_day, $s_month, $s_year, "0", "0");
	$end_date =~ /(\d{2})\/(\d{2})\/(\d{4})\s(\d{2}):(\d{2})/;
	my $e_day=$1;
	my $e_month=$2 - 1;
	my $e_year=$3 - 1900;
	my $e_hour=$4;
	my $e_minute=$5;
	my $e_sec="00";
	my $end_date_unix = mktime ($e_sec, $e_minute, $e_hour, $e_day, $e_month, $e_year, "0", "0");
	$time_range_search = "a.date BETWEEN " . $start_date_unix . " AND " . $end_date_unix;
} else {
	$time_range_audit_head = "4 weeks";
	$time_range_start = $datetime - 2419200;
	$time_range_search = "a.date BETWEEN " . $time_range_start . " AND " . $datetime;
}



no strict 'refs';
my @search;
foreach my $loc (keys %daten) {
        my $dat = $daten{$loc}; 
        if ( ! $dat || $dat eq "NULL" ) { next; }
#        if ( $dat !~ /../ && $loc ne "B2" ) {
	if ( $loc eq "client_id" || $loc eq "B1" ) {
		next;
	}
        if ( $dat !~ /../ && $loc ne "B2"  ) {
                $gip->print_init("search ip","$$lang_vars{busqueda_red_message}","$$lang_vars{dos_signos_message}","$vars_file","$client_id");
                $gip->print_end("$client_id");
                exit 1;
        }
        if ( $dat =~ /$$lang_vars{buscar_message}/ || $dat =~ /date/ ) {
                next;
        }
        $dat = "$loc:X-X:$dat";
        push @search, $dat;
}
use strict 'refs';


print "<p>\n";


my $anz_values_audit;
my $anz_values_audit_test;
my @values_audit;

if ( $time_radio ) {
	@values_audit=$gip->search_db_audit("$client_id","$time_range_search",\@search,$start_entry,$entries_per_page,$update_type_audit,$all_clients);
	$anz_values_audit = pop(@values_audit);
	$anz_values_audit_test = @values_audit;
#	$anz_values_audit = $#values_audit;
} else {
	@values_audit=$gip->get_all_audit_events("$client_id",$all_clients);
	$anz_values_audit = $#values_audit;
}


my $pages_links;
my $l = "0";
my $m = "0";
my $n = "1";
my $start_title;
my $cgi = "$ENV{SERVER_NAME}" . "$ENV{SCRIPT_NAME}";
if ( $anz_values_audit > $entries_per_page ) {
	while ( $l <= $anz_values_audit ) {
		if ( $n >= 100 ) {
			$pages_links = $pages_links . "&nbsp;<span class=\"audit_page_link_last\" title=\"$$lang_vars{'resultado_limitado_message'} $l $$lang_vars{'paginas_message'}\">...</span>&nbsp;\n";
			last;
		}
			
		$m = $l + $entries_per_page;
		$start_title = $l +1;
		if ( $pages_links  && $l != $start_entry ) {
			$pages_links = $pages_links . "<form name=\"printredtabheadform\" method=\"POST\" action=\"$server_proto://$cgi\" style=\"display:inline\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input type=\"submit\" value=\"$n\" name=\"B2\" class=\"audit_page_link\" title=\"$start_title-$m\"><input name=\"time_range\" type=\"hidden\" value=\"$time_range\"><input name=\"search_string\" type=\"hidden\" value=\"$search\"><input name=\"start_date\" type=\"hidden\" value=\"$start_date\"><input name=\"end_date\" type=\"hidden\" value=\"$end_date\"><input name=\"event_class\" type=\"hidden\" value=\"$event_class\"><input name=\"event_type\" type=\"hidden\" value=\"$event\"><input name=\"time_radio\" type=\"hidden\" value=\"$time_radio\"><input name=\"entries_per_page\" type=\"hidden\" value=\"$entries_per_page\"><input name=\"start_entry\" type=\"hidden\" value=\"$l\"><input name=\"update_type_audit\" type=\"hidden\" value=\"$update_type_audit\"><input name=\"all_clients\" type=\"hidden\" value=\"$all_clients\"></form>\n";
		} elsif ( $pages_links  && $l == $start_entry ) {
			$pages_links = $pages_links . "&nbsp;<span class=\"audit_page_link_actual\" title=\"$start_title-$m\">$n</span>&nbsp;\n";
		} elsif ( ! $pages_links  && $l == $start_entry ) {
			$pages_links = "&nbsp;<span class=\"audit_page_link_actual\" title=\"$start_title-$m\">$n</span>&nbsp;\n";
		} elsif ( ! $pages_links  && $l != $start_entry ) {
			$pages_links = "<form name=\"printredtabheadform\" method=\"POST\" action=\"$server_proto://$cgi\" style=\"display:inline\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input type=\"submit\" value=\"$n\" name=\"B2\" class=\"audit_page_link\" title=\"$start_title-$m\"><input name=\"time_range\" type=\"hidden\" value=\"$time_range\"><input name=\"search_string\" type=\"hidden\" value=\"$search\"><input name=\"start_date\" type=\"hidden\" value=\"$start_date\"><input name=\"end_date\" type=\"hidden\" value=\"$end_date\"><input name=\"event_class\" type=\"hidden\" value=\"$event_class\"><input name=\"event_type\" type=\"hidden\" value=\"$event\"><input name=\"time_radio\" type=\"hidden\" value=\"$time_radio\"><input name=\"entries_per_page\" type=\"hidden\" value=\"$entries_per_page\"><input name=\"start_entry\" type=\"hidden\" value=\"$l\"><input name=\"update_type_audit\" type=\"hidden\" value=\"$update_type_audit\"><input name=\"all_clients\" type=\"hidden\" value=\"$all_clients\"></form>\n";
		}
		$l = $l + $entries_per_page;
		$n++;
	}
}
$pages_links = "&nbsp;" if ! $pages_links;


$gip->PrintAuditTabHead("$client_id","$time_range_audit_head","$start_date_form","$end_date_form","$search","$event_class","$event","$time_radio","$start_entry","$entries_per_page","$pages_links","$update_type_audit","$all_clients","$vars_file");

print <<EOF;

<SCRIPT LANGUAGE="Javascript" TYPE="text/javascript">
<!--

function scrollToTop() {
  var x = '0';
  var y = '0';
  window.scrollTo(x, y);
  eraseCookie('net_scrollx')
  eraseCookie('net_scrolly')
}

// -->
</SCRIPT>

EOF

my $client_title_td="";
$client_title_td="<td><b>$$lang_vars{client_message}</b></td>" if $all_clients eq "yy";

if ( $values_audit[0] ) {
	print "<table cellspacing=\"0\" cellpadding=\"0\" border=\"0\" style=\"border-collapse:collapse\" width=\"100%\"><tr>$client_title_td<td><b>$$lang_vars{date_message}&nbsp;</b></td><td>&nbsp;<b>$$lang_vars{user_message}</b>&nbsp;</td><td>&nbsp;<b>$$lang_vars{event_type_message}</b>&nbsp;</td><td>&nbsp;<b>$$lang_vars{class_message}</b>&nbsp;</td><td>&nbsp;<b>$$lang_vars{event_message}</b>&nbsp;</td><td><b>$$lang_vars{value_message}</b></td></tr>\n";

	my $color="white";
	my $k="0";
	foreach (@values_audit) {
		if ( $color eq "white" ) {
			$color = "#f2f2f2";
		} else {
			$color = "white";
		}
		my $event_value=$values_audit[$k]->[0] || "N/A";
		my $user=$values_audit[$k]->[1] || "N/A";
		my $date=scalar localtime ($values_audit[$k]->[2]) || "N/A";
		my $event_class=$values_audit[$k]->[3] || "N/A";
		my $event=$values_audit[$k]->[4] || "N/A";
		my $event_type=$values_audit[$k]->[5] || "N/A";
		my $client_name=$values_audit[$k]->[6] || "N/A";
		$client_name="---" if $client_name eq "9999";
		my $client_name_td="";
		$client_name_td="<td nowrap>$client_name&nbsp;&nbsp;&nbsp;</td>" if $all_clients eq "yy";
		print "<tr bgcolor=\"$color\">$client_name_td<td nowrap>$date&nbsp;&nbsp;&nbsp;</td><td nowrap>$user&nbsp;&nbsp;&nbsp;</td><td nowrap>$event_type&nbsp;&nbsp;&nbsp;</td><td nowrap>$event_class&nbsp;</td><td nowrap>&nbsp;$event&nbsp;</td><td>$rtl_helper${event_value}${rtl_helper}</td></tr>\n";
		$k++;
	}
	print "</table>\n";
} else {
	print "<p class=\"NotifyText\">$$lang_vars{no_resultado_message}</p>\n";
}
$gip->print_end("$client_id","$vars_file","go_to_top");
