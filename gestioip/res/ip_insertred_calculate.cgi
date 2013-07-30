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
use Socket;
use Math::BigInt;


my $gip = GestioIP -> new();

my ($lang_vars,$vars_file)=$gip->get_lang();

my $close="<span class=\"close_window\" onClick=\"window.close()\" style=\"cursor:pointer;\"> $$lang_vars{close_message} </span>"; 

print_head();

if ( $ENV{'QUERY_STRING'} !~ /^.{1,100}$/ ) {
        print "$$lang_vars{max_signos_message}<p><br>$close<p>\n";
	print_end();
	exit 1;
}

my $QUERY_STRING = $ENV{'QUERY_STRING'};

if ( $ENV{'QUERY_STRING'} =~ /[;`'\\<>^%#*]/ ) {
        print_html($$lang_vars{max_signos_message}, $close);
        exit 1;
}


my $client_id;
my ($intro_message,$ip_ad,$BM,$bitmasks,$anz_BM,$BM_freerange,$ip_version);
my $message="";

my @bitmasks if $QUERY_STRING =~ /&bitmasks=/;

#create_multiple_network_differen_BM
if ( $QUERY_STRING =~ /&bitmasks=/ ) {
	$QUERY_STRING =~ /ip=(.*)&bitmasks=(.*)&BM_freerange=(.*)&client_id=(.*)&ip_version=(.*)$/;
	$ip_ad=$1;
	$bitmasks=$2;
	$client_id=$4;
	$ip_version=$5;
	if ( ! $bitmasks ) {
		print "<b>ERROR</b><p>$$lang_vars{no_bitmasks_message}<p><br>$close";
		print_end();
		exit 1;
	}
	$bitmasks =~ s/[\r\f\n\t\s]//;
#	$BM_freerange=$3;
	$intro_message="$$lang_vars{first_net_message}: $ip_ad, $$lang_vars{bitmasks_message}: $bitmasks<p>\n";
	if ( $bitmasks !~ /^(\/\d{1,2}){2,}$/ ) {
		print "<b>ERROR</b><p>$$lang_vars{bitmasks_malo_message}<p><br>$close\n";
	}
	$bitmasks =~ s/^\///;
	@bitmasks=split('/',$bitmasks);

#create_multiple_network_same_BM_message
} elsif ( $QUERY_STRING =~ /&BM=/ ) {
	$QUERY_STRING =~ /ip=(.*)&BM=(.*)&anz_BM=(.*)&client_id=(.*)&ip_version=(.*)$/;
	$ip_ad=$1;
	$BM=$2;
	$anz_BM=$3;
	$client_id=$4;
	$ip_version=$5;
	$intro_message="$$lang_vars{first_net_message}: $ip_ad/$BM, $$lang_vars{number_of_networks_message}: $anz_BM<p>\n";
} else {
	print "<b>ERROR</b><p>:$$lang_vars{entrada_mala_message}<p><br>$close\n";
	print_end();
	exit 1;
}


if ( $ip_ad =~ /^\d{6,12}$/ && $ip_version eq "v4" ) {
	$ip_ad = $gip->int_to_ip("$client_id","$ip_ad","$ip_version");
} elsif ( $ip_ad =~ /^\d{10,40}$/ && $ip_version eq "v6" ) { 
	$ip_ad = $gip->int_to_ip("$client_id","$ip_ad","$ip_version");
}
if ( ! $ip_ad ) {
	print "<b>ERROR</b><p>$$lang_vars{una_ip_message}<p><br>$close\n";
	print_end();
	exit 1;
}
	
if ( $ip_version eq "v4" ) {
	if ( $ip_ad !~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/ ) {
		print "<b>ERROR</b><p>$$lang_vars{formato_ip_malo_message}: $ip_ad<p><br>$close\n";
		print_end();
		exit 1;
	}
} else {
	my $valid_v6=$gip->check_valid_ipv6("$ip_ad") || "0";
	if ( $valid_v6 != 1 ) {
		print "<b>ERROR</b><p>$$lang_vars{formato_ip_malo_message}: $ip_ad<p><br>$close<br>\n";
		print_end();
		exit 1;
	}
	$ip_ad = ip_expand_address ($ip_ad,6);
}


my @overlap_redes=$gip->get_overlap_red("$ip_version","$client_id");
my $first_ip_new;
my $bm_mess;
my $i="0";
my $redob;

print "<span class=\"create_red_intro_message_text\">$intro_message</span><p>\n";
if ( @bitmasks) {
	foreach (@bitmasks) {
		my $BM_actual = $_;
		my $overlap_check_red;
		my $overlap_check_BM;
		if ( $i == 0 ) {
			$redob="$ip_ad/$BM_actual";
                        $overlap_check_red=$ip_ad;
			$overlap_check_BM=$BM_actual;

		} else {
			$redob="$first_ip_new/$BM_actual";
			$overlap_check_red=$first_ip_new;
			$overlap_check_BM=$BM_actual;

		}
		my $ipob = new Net::IP ($redob);
		if ( ! $ipob ) {
			if ( $message ) {
				$bm_mess="$bm_mess/<font color=\"red\"><u>$bitmasks[$i]</u></font>" if ( $bitmasks[$i] );
                                print "<b>$$lang_vars{error_red_invalido_message}</b><p>$message<font color=\"red\">$redob - NOT OK</font><p>$bm_mess - $$lang_vars{invalid_bitmask_message}<br><p>$close";
			} else {
				$bm_mess="$bm_mess/<font color=\"red\"><u>$bitmasks[$i]</u></font>" if ( $bitmasks[$i] );
				print "<b>$$lang_vars{error_red_invalido_message}</b><p><font color=\"red\">$redob - NOT OK</font><p>$bm_mess - $$lang_vars{invalid_bitmask_message}<br><p><br>";
			}
			print "$close";
			print_end();
			exit 1;
		}
		
		my $last_ip_int = ($ipob->last_int());
		$last_ip_int = Math::BigInt->new("$last_ip_int");
		my $first_ip_int = $last_ip_int + 1;
		$first_ip_new=$gip->int_to_ip("$client_id","$first_ip_int","$ip_version");
		my @overlap_found = $gip->find_overlap_redes("$client_id","$overlap_check_red","$overlap_check_BM",\@overlap_redes,"$ip_version","$vars_file");
		if ( $overlap_found[0] && $overlap_found[0] ne $ip_ad ) {
			print "<p><b>$$lang_vars{overlap_detected_message}</b><p>\n";
			if ( $message ) {
				print "$message<font color=\"red\">$redob - NOT OK</font></b><p>$redob $$lang_vars{overlaps_con_message} $overlap_found[0]<p><br><p>";
			} else {
				print "<font color=\"red\">$redob - NOT OK</font></b><p>$redob $$lang_vars{overlaps_con_message} $overlap_found[0]<p><br><p>";
			}
			print "$close";
			print_end();
			exit 1;
		}
		if ( $BM_actual == "31" ) {
			if ( $message ) {
				print "$message<font color=\"red\">$redob - NOT OK</font><p><b>ERROR</b><p>$$lang_vars{no_bm_31_message}: $redob<br>";
			} else {
				print "<font color=\"red\">$redob - NOT OK</font><p><b>ERROR</b><p>$$lang_vars{no_bm_31_message}: $redob<br>";
			}
			print "$close";
			print_end();
			exit 1;
		}

		if ( $message ) {
			$message = $message . "$redob - OK<br>";
		} else {
			$message = "$redob - OK<br>";
		}
		if ( $bm_mess ) {
			$bm_mess = $bm_mess . "/" . $BM_actual;
		} else {
			$bm_mess = $BM_actual;
		}

		$i++;
	}
} elsif ( $BM ) {
	for (my $i = 1; $i <= $anz_BM; $i++) {
		my $overlap_check_red;
		if ( $i == 1 ) {
			$redob="$ip_ad/$BM";
			$overlap_check_red=$ip_ad;
		} else {
			$redob="$first_ip_new/$BM";
			$overlap_check_red=$first_ip_new;
		}
		my $ipob = new Net::IP ($redob);
		if ( ! $ipob ) {
			if ( $message ) {
				print "$message<p><b>$redob - NOT OK</b><p><b>$$lang_vars{red_invalido_message}</b><p><br>$close<p>";
			} else {
				print "$message<p><b>$redob - NOT OK</b><p><b>$$lang_vars{red_invalido_message}</b><p><br>$close<p>";
			}
			print_end();
			exit 1;
		}
		
		my $last_ip_int = ($ipob->last_int());
		$last_ip_int = Math::BigInt->new("$last_ip_int");
		my $first_ip_int = $last_ip_int + 1;
		$first_ip_new=$gip->int_to_ip("$client_id","$first_ip_int","$ip_version");

		my @overlap_found = $gip->find_overlap_redes("$client_id","$overlap_check_red","$BM",\@overlap_redes,"$ip_version","$vars_file");
		if ( $overlap_found[0] && $overlap_found[0] ne $ip_ad ) {
			print "<p><b>$$lang_vars{overlap_detected_message}</b><p>\n";
			if ( $message ) {
				print "$message<font color=\"red\">$redob - NOT OK</font></b><p>$redob $$lang_vars{overlaps_con_message} $overlap_found[0]<p><br><p>";
			} else {
				print "<font color=\"red\">$redob - NOT OK</font></b><p>$redob $$lang_vars{overlaps_con_message} $overlap_found[0]<p><br><p>";
			}
			print_end();
			print "$close";
			exit 1;
		}

		if ( $message ) {
			$message = $message . "$redob - OK<br>";
		} else {
			$message = "$redob - OK<br>";
		}
	}
}


print "$message<p><br>$close<p>";;

sub print_head {
my ( $message, $close ) = @_;
print <<EOF;
Content-type: text/html\n
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
"http://www.w3.org/TR/html4/loose.dtd">
<HTML>
<head><title>GestioIP Checkhost</title>
<meta http-equiv="content-type" content="text/html; charset=UTF-8">
<link rel="stylesheet" type="text/css" href="../stylesheet.css">
<link rel="shortcut icon" href="/favicon.ico">
</head>

<body>
<div id="TopBoxCalc">
<table border="0" width="100%"><tr height="50px"><td>
  <span class="TopTextGestio">Gesti&oacute;IP</span></td>
  <td><span class="TopText"> $$lang_vars{calcular_nuevas_redes_message}</span></td><tr>
</td></table>
</div>
<p>
EOF
}

sub print_end {
print <<EOF;
<p><br><p>
</body>
</html>
EOF
}
