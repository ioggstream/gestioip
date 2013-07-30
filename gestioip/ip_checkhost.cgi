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
use Net::Ping::External qw(ping);
use Socket;
use Net::IP;
use Net::IP qw(:PROC);
use Net::DNS;
use Net::DNS::RR;


$ENV{'PATH'} = '/bin:/usr/bin';
delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV'};

my $gip = GestioIP -> new();
my ($lang_vars,$vars_file)=$gip->get_lang();

my $close="<span class=\"close_window\" onClick=\"window.close()\" style=\"cursor:pointer;\"> close </span>"; 

if ( $ENV{'QUERY_STRING'} !~ /^.{1,500}$/ ) {
        print_html($$lang_vars{max_signos_message}, $close);
	exit 1;
}

my $QUERY_STRING = $ENV{'QUERY_STRING'};

if ( $ENV{'QUERY_STRING'} =~ /[;`'\\<>^%#*]/ ) {
        print_html($$lang_vars{max_signos_message}, $close);
	exit 1;
}

$QUERY_STRING =~ /ip=(.*)&hostname=(.*)&client_id=(.*)&ip_version=(.*)$/;

my $ip_ad=$1;
my $name=$2 || "";
my $client_id=$3 || "";
my $ip_version=$4 || "";

if ( $ip_ad =~ /^\d{6,40}$/ ) {
	$ip_ad = $gip->int_to_ip("$client_id","$ip_ad","$ip_version");
}

if ( $ip_version eq "v4" ) {
	if ( $ip_ad !~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/ ) {
		print_html("<b>ERROR</b><p>$$lang_vars{ip_invalid_message}: $ip_ad","");
		exit 1;
	}
} elsif ( $ip_version eq "v6" ) {
	my $ip_ad_expand = ip_expand_address ($ip_ad,6);
	if ( $ip_ad_expand !~ /^\w+:\w+:\w+:\w+:\w+:\w+:\w+:\w+$/ ) {
		print_html("<b>ERROR</b><p>$$lang_vars{ip_invalid_message} $ip_ad","");
	}
}

if ( $client_id !~ /^\d{1,4}$/ ) {
	print_html("<b>ERROR</b><p>$$lang_vars{client_id_invalid_message}","");
	exit 1;
}

### PING HISTORY PATCH to add ping status changes to host history####
### require new event_type: INSERT INTO event_types (id,event_type) VALUES (100,"ping status changed");
### disabled 0; enabled 1;
my $enable_ping_history=0;
my $update_type_audit="6";


my @config = $gip->get_config("$client_id");
my @client_entries=$gip->get_client_entries("$client_id");

my $module = "Net::DNS";
my $module_check=$gip->check_module("$module") || "0";
$gip->print_error("$client_id","$$lang_vars{net_dns_not_found_message}") if $module_check != "1";

my $default_resolver = $client_entries[0]->[20];

my $ping_timeout = $config[0]->[6] || "2";

my $message_ping;
my @dns_servers =("$client_entries[0]->[21]","$client_entries[0]->[22]","$client_entries[0]->[23]");
my $dns_servers_string="";
foreach ( @dns_servers ) {
	next if ! $_;
	if ( $dns_servers_string ) {
		$dns_servers_string=$dns_servers_string . ", " . $_;
	} else {
		$dns_servers_string = $_;
	}
}
$dns_servers_string =~ s/,$//;


my ($a_query,$ptr_query,$dns_result_name_address,$dns_result_ip,$dns_result_cname_address);
my $dns_error="";


my $res_dns;

if ( $default_resolver eq "yes" ) {
	$res_dns = Net::DNS::Resolver->new(
	retry       => 2,
	udp_timeout => 5,
	recurse     => 1,
	debug       => 0,
	);
} else {
	$res_dns = Net::DNS::Resolver->new(
	retry       => 2,
	udp_timeout => 5,
	nameservers => [@dns_servers],
	recurse     => 1,
	debug       => 0,
	);
}


if ( $name =~ /\w+/ ) {
	if ( $ip_version eq "v4" ) {
		$a_query = $res_dns->query("$name");
	} else {
		$a_query = $res_dns->query("$name","AAAA");
	}


	if ($a_query) {
		foreach my $rr ($a_query->answer) {
			next unless $rr->type eq "A";
			$dns_result_name_address = $rr->address;
		}
		foreach my $rr ($a_query->answer) {
			next unless $rr->type eq "AAAA";
			$dns_result_name_address = $rr->address;
		}
		foreach my $rr ($a_query->answer) {
			next unless $rr->type eq "CNAME";
			$dns_result_cname_address = $rr->cname;
		}
	} else {
		$dns_error=$res_dns->errorstring;
	}
}



if ( $dns_error =~ /(query timed out|no nameservers)/ ) {
	print_html("$$lang_vars{no_answer_from_dns_message}: $dns_servers_string", $close);
	exit 1;
}
	


if ( $ip_ad =~ /\w+/ ) {
	$ptr_query = $res_dns->query("$ip_ad");

	if ($ptr_query) {
		foreach my $rr ($ptr_query->answer) {
			next unless $rr->type eq "PTR";
			$dns_result_ip = $rr->ptrdname;
		}
	} else {
		$dns_error = $res_dns->errorstring;
	}
}



my $ping_result;
if ( $ip_version eq "v4" ) {
	if ( $ip_ad ) {
		my $p = ping(host => "$ip_ad", timeout => $ping_timeout);
		if ( $p ) {
			$message_ping="<b>ping $ip_ad</b>:<br>$ip_ad <span style=\"color:green;\">$$lang_vars{esta_levantada}</span>";
			$ping_result="1";
		} else {
			$message_ping="<b>ping $ip_ad</b>:<br>$ip_ad $$lang_vars{no_ping_message}";
			$ping_result="0";
		}
	}
} else {
	if ( $ip_ad ) {
		my $command='ping6 -c 1 ' .  $ip_ad;
		my $result=$gip->ping6_system("$command","0");
		if ( $result == "0" ) {
			$message_ping="<b>ping $ip_ad</b>:<br>$ip_ad $$lang_vars{esta_levantada}";
			$ping_result="1";
		} else {
			$message_ping="<b>ping $ip_ad</b>:<br>$ip_ad $$lang_vars{no_ping_message}";
			$ping_result="0";
		}
	}
}

my $ipob;
if ( $ip_version eq "v4" ) {
	$ipob = new Net::IP ("$ip_ad/32") || print_html("Can not create ip object (v4): $!<br>", $close);
} else {
	$ipob = new Net::IP ("$ip_ad/128") || print_html("Can not create ip object (v6): $!<br>", $close);
}
my $ip_int=($ipob->intip());

$gip->update_host_ping_info("$client_id","$ip_int","$ping_result","$enable_ping_history","$ip_ad","$update_type_audit","$vars_file");


my $message_ip;
my $message_name="";
if ( $ip_ad ) {
	if ( $dns_result_ip ) {
		$message_ip="<b>PTR query</b>: $ip_ad<br>$dns_result_ip";
	} else {
		$message_ip="<b>PTR query</b>: $ip_ad<br>$$lang_vars{no_resultado_message}";
	}
}
if ( $name && $name ne "unknown" ) {
	$message_name="<b>A query</b>: $name<br>";
	if ($dns_result_name_address) {
		$message_name="$message_name $dns_result_name_address";
		$message_name="$message_name<br>$name $$lang_vars{es_un_alias_message} $dns_result_cname_address" if ($dns_result_cname_address);
	} else {
		$message_name="<b>A query</b>: $name<br>$$lang_vars{no_resultado_message}";
	}
	
}



my $message="$message_ping <p> $message_name <p> $message_ip <p>\n";

if ( $default_resolver ne "yes" ) {
	$message="$message <p> <span class=\"close_window\"> ( $$lang_vars{using_nameservers_message}: $dns_servers_string )</span>";
}	
	


print_html($message, $close);

sub print_html {
	my ( $message, $close ) = @_;
print <<EOF;
Content-type: text/html\n
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
"http://www.w3.org/TR/html4/loose.dtd">
<HTML>
<head><title>GestioIP Checkhost</title>
<meta http-equiv="content-type" content="text/html; charset=UTF-8">
<link rel="stylesheet" type="text/css" href="./stylesheet.css">
<link rel="shortcut icon" href="/favicon.ico">
</head>

<body>
<div id="TopBoxCalc">
<table border="0" width="100%"><tr height="50px" valign="middle"><td>
  <span class="TopTextGestio">Gesti&oacute;IP</span></td>
  <td><span class="TopText">Host Check</span></td><tr>
</td></table>
</div>
<p>
$message
<p><br><p>
$close
</body>
</html>
EOF
}
