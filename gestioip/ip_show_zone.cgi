#!/usr/bin/perl -T -w


# Copyright (C) 2012 Marc Uebel

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


use DBI;
use strict;
use lib './modules';
use GestioIP;
use Net::IP;
use Net::IP qw(:PROC);
use Math::BigInt;


my $daten=<STDIN>;
my $gip = GestioIP -> new();
my %daten=$gip->preparer("$daten") if $daten;

my $lang = $daten{'lang'} || "";
my ($lang_vars,$vars_file,$entries_per_page)=$gip->get_lang("","$lang");
my $server_proto=$gip->get_server_proto();
my $base_uri=$gip->get_base_uri();


my $client_id = $daten{'client_id'} || $gip->get_first_client_id();

$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{dns_zone_files_message}","$vars_file");

my $align="align=\"right\"";
my $align1="";
my $ori="left";
my $rtl_helper="<font color=\"white\">x</font>";
if ( $vars_file =~ /vars_he$/ ) {
	$align="align=\"left\"";
	$align1="align=\"right\"";
	$ori="right";
}

my $ip_version=$daten{'ip_version'};
my $red_num=$daten{'red_num'} || $gip->print_error("$client_id","$$lang_vars{formato_malo_message} (1)");
my $domain=$daten{'domain'} || "<font color=\"gray\">example.org</font>";
my $serial=$daten{'serial'} || "<font color=\"gray\">000000001</font>";
my $refresh=$daten{'refresh'} || "1w";
my $retry=$daten{'retry'} || "1d";
my $expire=$daten{'expire'} || "4w";
my $minimum=$daten{'minimum'} || "1d";
my $TTL=$daten{'TTL'} || "86400";
my $nameserver1=$daten{'nameserver1'} || "<font color=\"gray\">ns1.</font>$domain";
my $nameserver2=$daten{'nameserver2'} || "<font color=\"gray\">ns2.</font>$domain";
my $mailserver1=$daten{'mailserver1'} || "<font color=\"gray\">mail1.</font>$domain";
my $mailserver2=$daten{'mailserver2'} || "<font color=\"gray\">mail2.</font>$domain";
#my $dedicated_server=$daten{'dedicated_server'} || "";
my $ignore_unknown=$daten{'ignore_unknown'} || "";
my $ignore_out_of_zone_data=$daten{'ignore_out_of_zone_data'} || "";
my $create_generic=$daten{'create_generic'} || "";
#my $create_generic_all=$daten{'create_generic_all'} || "";
$create_generic="" if $ip_version ne "v4";
#my $multiple_reverse_zones=$daten{'multiple_reverse_zones'} || "";
my $all_reverse_zones=$daten{'all_reverse_zones'} || "";
my $server_type=$daten{'server_type'};

$nameserver1 =~ s/\.$//;
if ( $nameserver1 !~ /\..+/ ) {
	$nameserver1.="." . $domain;
}
$nameserver2 =~ s/\.$//;
if ( $nameserver2 !~ /\..+/ ) {
	$nameserver2.="." .$domain;
}

$mailserver1 =~ s/\.$//;
if ( $mailserver1 =~ /\..+/ ) {
	$mailserver1.='.';
}
$mailserver2 =~ s/\.$//;
if ( $mailserver2 =~ /\..+/ ) {
	$mailserver2.='.';
}


if ( $server_type eq "tinydns" ) {
	$TTL=$gip->convert_to_seconds("$TTL") || $TTL;
	$refresh=$gip->convert_to_seconds("$refresh") || $refresh;
	$retry=$gip->convert_to_seconds("$retry") || $retry;
	$expire=$gip->convert_to_seconds("$expire") || $expire;
	$minimum=$gip->convert_to_seconds("$minimum") || $minimum;
}
		

my @ip=();
my @red=();
@red=$gip->get_red("$client_id","$red_num");

my $red=$red[0]->[0];
my $BM=$red[0]->[1];
my $BM_orig=$BM;
my $rootnet=$red[0]->[9];

print "<br><b>$$lang_vars{redes_message} $red/$BM</b><p>\n";

my @overlap_found=();
if ( $rootnet == 1 && $ip_version eq "v4" && $all_reverse_zones ne "yes" ) {
	my @overlap_redes=$gip->get_overlap_red("$ip_version","$client_id");
	@overlap_found = $gip->find_overlap_redes("$client_id","$red","$BM",\@overlap_redes,"$ip_version","$vars_file","","","1");
	my $m=0;
	foreach ( @overlap_found ) {
		$m++;
	}
} elsif ( $rootnet == 1 && $ip_version eq "v4" && $all_reverse_zones eq "yes" ) {
	$overlap_found[0]="$red/$BM";
} elsif ( $rootnet == 0 && $ip_version eq "v4" ) {
	$overlap_found[0]="$red/$BM";
} elsif ( $rootnet == 1 && $ip_version eq "v6" ) {
	my %bm=$gip->get_anz_hosts_bm_hash("1","$ip_version");

	my $anz_new_redes=1;
	if ( $BM % 4 != 0 ) {
		my $start = $BM+1;
		my $end = $BM+17;
		my $j=0;
		my $new_BM;
		for (my $i=$start; $i<=$end; $i++) {
			$new_BM=$i;
			$overlap_found[0]="$red/${new_BM}";
			$j++;
			if ( $j == 1 ) {
				$anz_new_redes=1;
			} elsif ( $j == 2 ) {
				$anz_new_redes=3;
			} elsif ( $j == 3 ) {
				$anz_new_redes=7;
			}
			if ( $i % 4 == 0 ) {
				last;
			}
		}
		
		my $nextred=$overlap_found[0];
		for (my $i=1; $i<=$anz_new_redes; $i++) {
			my $ipob_red_in = new Net::IP ($nextred) or die "Can not create IP object: $!\n";
			my $last_ip_int = ($ipob_red_in->last_int());
			$last_ip_int = Math::BigInt->new("$last_ip_int");
			my $nextred_int=$last_ip_int+1;
			$nextred = $gip->int_to_ip("1","$nextred_int","v6");
			$nextred.="/" . $new_BM;
			$overlap_found[$i]=$nextred;
		}
	} else {
		$overlap_found[0]="$red/${BM}";
	}



} elsif ( $rootnet == 0 && $ip_version eq "v6" ) {
	$overlap_found[0]="$red/$BM";
}


my $redob="$red/$BM";
my $ipob_red_orig = new Net::IP ($redob) or $gip->print_error("$client_id","$$lang_vars{comprueba_red_BM_message}: <b>$red/$BM</b>");
my $first_ip_int_orig = ($ipob_red_orig->intip());
my $last_ip_int_orig = ($ipob_red_orig->last_int());


if ( $rootnet == 0 ) {
	@ip=$gip->get_host_from_red_num("$client_id","$red_num");
} else {
	@ip=$gip->get_host("$client_id","$first_ip_int_orig","$last_ip_int_orig","","","$ip_version");
}
my $host_hash_ref="";
$host_hash_ref=$gip->get_host_hash_between("$client_id","$first_ip_int_orig","$last_ip_int_orig","$ip_version") if $ip_version eq "v4";

my ($first_oct,$second_oct,$third_oct,$fourth_oct,$arpa_addr);
$red =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/;
$first_oct=$1;
$second_oct=$2;
$third_oct=$3;
$fourth_oct=$4;

my $new_bm="";
my $anz_hosts_net_new="";
my @new_redes=();
my %ip_fi_la_int;

my @overlap_found_bm_lt_24=();
my %anz_hosts_bm = $gip->get_anz_hosts_bm_hash("$client_id","$ip_version");
my $n=0;
my $o=0;
my $p=0;
foreach ( @overlap_found ) {
	my $overlap_red=$overlap_found[$o];
	$overlap_red =~ /^(.+)\/(.+)/;
	$red=$1;
	$BM=$2;
	if ( $ip_version eq "v4" ) {
		if ( $BM < 16 ) {
			### REVERSE ZONES NOT SUPPORTED
#		} elsif ( $BM >= 16 && $BM < 24 && $all_reverse_zones ne "yes" ) {
#			$redob="$red/$BM";
#			$new_redes[$n]="$redob";
#			my $ipob_red = new Net::IP ($redob) or $gip->print_error("$client_id","$$lang_vars{comprueba_red_BM_message}: <b>$red/$BM</b>");
#			my $first_ip_int = ($ipob_red->intip());
#			my $last_ip_int = ($ipob_red->last_int());
#			$ip_fi_la_int{$redob}="$first_ip_int,$last_ip_int";
#			$n++;
#			$o++;
#			next;
#		} elsif ( $BM >= 16 && $BM < 24 && $all_reverse_zones eq "yes") {
		} elsif ( $BM >= 16 && $BM < 24 ) {
			$new_bm=24;
			$redob="$red/$new_bm";
			$anz_hosts_net_new=256;
			$new_redes[$n]=$redob;
			my $ipob_red = new Net::IP ($redob) or $gip->print_error("$client_id","$$lang_vars{comprueba_red_BM_message}: <b>$red/$BM</b>");
			my $first_ip_int = ($ipob_red->intip());
			my $last_ip_int = ($ipob_red->last_int());
			$ip_fi_la_int{$redob}="$first_ip_int,$last_ip_int";
			$n++;
		} elsif ( $BM eq 24 ) {
			$redob="$red/$BM";
			$new_redes[$n]="$redob";
			my $ipob_red = new Net::IP ($redob) or $gip->print_error("$client_id","$$lang_vars{comprueba_red_BM_message}: <b>$red/$BM</b>");
			my $first_ip_int = ($ipob_red->intip());
			my $last_ip_int = ($ipob_red->last_int());
			$ip_fi_la_int{$redob}="$first_ip_int,$last_ip_int";
			$n++;
			$o++;
			next;
		} elsif ( $BM > 24 ) {
			#### REVERSE ZONES NOT SUPPORTED
			$overlap_found_bm_lt_24[$p]="$red/$BM";
			$p++;
			$o++;
			next;
		}
	} else {
		if ( $BM < 64 ) {
			$redob="$red/$BM";
			$new_redes[$n]="$redob";
			my $ipob_red = new Net::IP ($redob) or $gip->print_error("$client_id","$$lang_vars{comprueba_red_BM_message}: <b>$red/$BM</b>");
			my $first_ip_int = ($ipob_red->intip());
			my $last_ip_int = ($ipob_red->last_int());
			$ip_fi_la_int{$redob}="$first_ip_int,$last_ip_int";
			$n++;
			$o++;
			next;
		} elsif ( $BM == 64 ) {
                        $new_redes[0]="$red/$BM";
                        my $ipob_red = new Net::IP ($redob) or $gip->print_error("$client_id","$$lang_vars{comprueba_red_BM_message}: <b>$red/$BM</b>");
                        my $first_ip_int = ($ipob_red->intip());
                        $first_ip_int = Math::BigInt->new("$first_ip_int");
                        my $last_ip_int = ($ipob_red->last_int());
                        $last_ip_int = Math::BigInt->new("$last_ip_int");
                        $ip_fi_la_int{$redob}="$first_ip_int,$last_ip_int";

			next;
		} else {
			#### REVERSE ZONES NOT SUPPORTED
			next;
			
		}
	}

	$anz_hosts_net_new =~ s/,//g;
	$anz_hosts_net_new = Math::BigInt->new("$anz_hosts_net_new") if $ip_version eq "v4";
	my $anz_host_net = $anz_hosts_bm{$BM};
	$anz_host_net =~ s/,//g;
	my $anz_net_new=$anz_host_net / $anz_hosts_net_new;
	$anz_net_new =~ s/\..*//;

	for (my $i=1;$i<$anz_net_new;$i++) {
		my $ipob_red_new = new Net::IP ($redob) or $gip->print_error("$client_id","$$lang_vars{comprueba_red_BM_message}: <b>$red/$BM</b>");
		my $last_ip_int_new = ($ipob_red_new->last_int());
		$last_ip_int_new = Math::BigInt->new("$last_ip_int_new");
		my $first_ip_int_new = $last_ip_int_new + 1;
		my $first_ip_new=$gip->int_to_ip("$client_id","$first_ip_int_new","$ip_version");
		$new_redes[$n]="$first_ip_new/$new_bm";
		$redob = $new_redes[$n];
		my $last_ip_fi=$first_ip_int_new + $anz_hosts_net_new - 1;
		$ip_fi_la_int{$redob}="$first_ip_int_new,$last_ip_fi";
		$n++;
	}
	$o++;
}


my @out_of_zone_hosts=();
my $TTL_name="";
my $new_red;

if ( $server_type eq "BIND" ) {
	print "<p>";
	print "<b>$$lang_vars{forward_zone_message} $domain</b> ($$lang_vars{file_message} $domain)<p>\n";
	my $origin_name='$ORIGIN';
	$TTL_name='$TTL';

print <<EOF;
<PRE>
$TTL_name	$TTL
$origin_name ${domain}.
@           IN SOA  ${nameserver1}. root.${domain}. (
			$serial; serial
			$refresh; refresh
			$retry; retry
			$expire; expire
			$minimum; minimum
			) 

	IN	NS	${nameserver1}.
	IN	NS	${nameserver2}.

$mailserver1	IN	MX 10	${domain}.
$mailserver2	IN	MX 20	${domain}.

EOF

	my $q=0;
	if ( $ip[0] ) {
		my $i=0;
		foreach ( @ip ) {
			my $hostname=$ip[$i]->[1];
			if ( $hostname eq "unknown" && $ignore_unknown eq "yes" ) {
				$i++;
				next;
			}
			my $ip="";
			if ( $ip_version eq "v4" ) {
				$ip=$ip[$i]->[12];
			} else {
				my $ip_int6=$ip[$i]->[0];
				$ip=$gip->int_to_ip("$client_id","$ip_int6","$ip_version");
			}

			if ( $hostname !~ /\./ ) {
	#			$hostname.="." . $domain . ".";
			} elsif  ( $hostname =~ /\./ && $hostname !~ /$domain\.?/ && $ignore_out_of_zone_data eq "yes") {
				$out_of_zone_hosts[$q]="$hostname ($ip)";			
				$i++;
				$q++;
				next;
			}
			$hostname.="." if $hostname =~ /\..+\./ && $hostname !~ /\.$/;
			if ( $hostname eq "unknown" && $ignore_unknown eq "yes" ) {
				$i++;
				next;
			}
			
			if ( $ip_version eq "v4" ) {
				print "$hostname	A $ip\n";
			} else {
				print "$hostname	AAAA $ip\n";
			}
			$i++;
		}
	} else {
	#	print "<p class=\"NotifyText\">$$lang_vars{no_resultado_message}</p><br>\n";
	}

	print "</PRE>\n";
	print "<p><br>";
	print "<b>named.conf</b><p>\n";

print <<EOF;
<PRE>
zone "$domain" {
	type master;
	file "$domain";
	allow-update { none; };
};
</PRE>
EOF

} elsif ( $server_type eq "tinydns" ) {
my $j=0;
my $at='@';
print <<EOF;
<PRE>
### SOA $domain
Z${domain}:${nameserver1}:root.${domain}.:${serial}:${refresh}:${retry}:${expire}:${minimum}:${TTL}
### Nameserver $domain
&${domain}::${nameserver1}:${TTL}
&${domain}::${nameserver2}:${TTL}
### Mailserver $domain
${at}${domain}::${mailserver1}:10:${TTL}
${at}${domain}::${mailserver2}:20:${TTL}
EOF
my $q=0;
foreach (@new_redes) {
	if ( $ip_version eq "v4" ) {
		$new_red=$new_redes[$j];
		$new_red =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\/.+/;
		$first_oct=$1;
		$second_oct=$2;
		$third_oct=$3;
		$fourth_oct=$4;
		if ( $BM == 16 ) {
			$arpa_addr=$second_oct . "." . $first_oct . ".in-addr.arpa";
		} else {
			$arpa_addr=$third_oct . "." . $second_oct . "." . $first_oct . ".in-addr.arpa";
		}
	} else {
		$new_red=$new_redes[$j];
		my $nibbles_pre=$new_red;
		$nibbles_pre =~ s/\/.+$//;
		$nibbles_pre =~ s/://g;
		my @nibbles=split(//,$nibbles_pre);
		my @nibbles_reverse=reverse @nibbles;
		my $nibbles="";
		my $rest=128-$BM;
		my $red_part_helper = ($rest-1)/4;
		my $bc="1";
		if ( $red_part_helper =~ /\./ ) {
			$red_part_helper =~ /\d\.(\d)/;
			$bc=$1;
		}

		$red_part_helper =~ s/\.\d*//;
		$red_part_helper++ if $bc > 5;

		my $i=1;
		my $prefix_part="";
		my $host_part="";
		foreach my $num (@nibbles_reverse ) {
			if ( $i==$red_part_helper && $nibbles =~ /\w/) {
				$host_part=$nibbles . "." . $num;
				$nibbles.="." . $num;
			} elsif ( $i==$red_part_helper && $nibbles eq "") {
				$host_part=$num;
				$nibbles=$num;
			} elsif ( $nibbles =~ /\w/) {
				$nibbles .= "." . $num;
			} else {
				$nibbles = $num;
			}
			$i++;
		}
		$prefix_part=$nibbles;
		$prefix_part =~ s/$host_part//;
		$prefix_part =~ s/^\.//;

		$nibbles .= ".ip6.arpa.";
		$arpa_addr=$prefix_part . ".ip6.arpa";
	}
	print "\n### SOA ${arpa_addr}\n";
	print "Z${arpa_addr}:${nameserver1}:root.${domain}:${serial}:${refresh}:${retry}:${expire}:${minimum}:${TTL}\n";
	print "### Nameserver ${arpa_addr}\n";
	print "&${arpa_addr}::${nameserver1}:${TTL}\n";
	print "&${arpa_addr}::${nameserver2}:${TTL}\n";
	
	my $fi_la=$ip_fi_la_int{$new_red};
	my ($fi_ip_int,$la_ip_int)=split(",",$fi_la);
	$fi_ip_int=Math::BigInt->new("$fi_ip_int");
	$la_ip_int=Math::BigInt->new("$la_ip_int");

	my $i=0;
	my $firstrun=0;
	if ( $ip_version eq "v4" ) {
		for (my $k=$fi_ip_int+1;$k<$la_ip_int;$k++) {
			my $ip_int=$k;
			if ( defined($host_hash_ref->{$k}[0]) && ( ! $create_generic || $create_generic eq "free") ) {
				print "### A/PTR entries\n" if $firstrun==0;
				$firstrun=1;
				my $hostname=$host_hash_ref->{$k}[1];
				my $ip=$host_hash_ref->{$k}[0];

				if ( $hostname eq "unknown" && $ignore_unknown eq "yes" && ! $create_generic ) {
					next;
				} elsif ( $hostname eq "unknown" && $ignore_unknown eq "yes" && $create_generic ) {
					my $ip_generic=$gip->int_to_ip("$client_id","$k","$ip_version");
					$ip_generic =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/;
					$first_oct=$1;
					$second_oct=$2;
					$third_oct=$3;
					$fourth_oct=$4;
					my $arpa_name_generic=$fourth_oct . "-" . $third_oct . "-" . $second_oct . "-" . $first_oct . "." . "$domain.";
					my $fqdn= $fourth_oct . "." . $third_oct . "." . $second_oct . "." . $first_oct . "." . "in-addr.arpa";
					print "^${fqdn}:${arpa_name_generic}:${TTL}\n";
					next;
				}

				if ( $hostname !~ /\..+\./ ) {
					$hostname.="." . $domain;
				} elsif  ( $hostname =~ /\./ && $hostname !~ /$domain\.?/ && $ignore_out_of_zone_data eq "yes") {
					$out_of_zone_hosts[$q]="$hostname ($ip)";			
					if ( $create_generic ) {
						my $ip_generic=$gip->int_to_ip("$client_id","$k","$ip_version");
						$ip_generic =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/;
						$first_oct=$1;
						$second_oct=$2;
						$third_oct=$3;
						$fourth_oct=$4;
						my $arpa_name_generic=$fourth_oct . "-" . $third_oct . "-" . $second_oct . "-" . $first_oct . "." . "$domain.";
						my $fqdn= $fourth_oct . "." . $third_oct . "." . $second_oct . "." . $first_oct . "." . "in-addr.arpa";
						print "^${fqdn}:${arpa_name_generic}:${TTL}\n";
					}
					$q++;
					next;
				}
				
				if ( $ip_int >= $fi_ip_int && $ip_int < $la_ip_int ) {
					print "=${hostname}:${ip}:${TTL}\n";
				}

			} elsif ( $create_generic ) {
				print "### A/PTR entries\n" if $firstrun==0;
				$firstrun=1;
				my $ip_generic=$gip->int_to_ip("$client_id","$k","$ip_version");
				$ip_generic =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/;
				$first_oct=$1;
				$second_oct=$2;
				$third_oct=$3;
				$fourth_oct=$4;
				my $arpa_name_generic=$fourth_oct . "-" . $third_oct . "-" . $second_oct . "-" . $first_oct . "." . "$domain.";
				my $fqdn= $fourth_oct . "." . $third_oct . "." . $second_oct . "." . $first_oct . "." . "in-addr.arpa";
				if ( defined($host_hash_ref->{$k}[0]) && $create_generic eq "all" ) {
					my $hostname=$host_hash_ref->{$k}[1];
					my $ip=$host_hash_ref->{$k}[0];
					if ( $hostname eq "unknown" && $ignore_unknown eq "yes" ) {
						print "^${fqdn}:${arpa_name_generic}:${TTL}\n";
						next;
					}

					if ( $hostname !~ /\..+\./ ) {
						$hostname.="." . $domain;
					} elsif  ( $hostname =~ /\./ && $hostname !~ /$domain\.?/ && $ignore_out_of_zone_data eq "yes") {
						$out_of_zone_hosts[$q]="$hostname ($ip)";			
						print "^${fqdn}:${arpa_name_generic}:${TTL}\n";
						$q++;
						next;
					}
					
					if ( $ip_int >= $fi_ip_int && $ip_int < $la_ip_int ) {
						print "+${hostname}:${ip}:${TTL}\n";
					}
				}

				print "^${fqdn}:${arpa_name_generic}:${TTL}\n";
			}
		}
	} else {
		foreach ( @ip ) {
			my $ip_int=$ip[$i]->[0];
			my $hostname=$ip[$i]->[1];

			$ip_int=Math::BigInt->new("$ip_int");
			if ( $ip_int < $fi_ip_int || $ip_int >= $la_ip_int ) {
				$i++;
				next;
			}

			print "### A/PTR entries\n" if $firstrun==0;
			$firstrun=1;

			if ( $hostname eq "unknown" && $ignore_unknown eq "yes" ) {
				$i++;
				next;
			}

			my $ip="";
			$ip=$gip->int_to_ip("$client_id","$ip_int","$ip_version");

			if ( $hostname !~ /\..+\./ ) {
				$hostname.="." . $domain . ".";
			} elsif  ( $hostname =~ /\./ && $hostname !~ /$domain\.?/ && $ignore_out_of_zone_data eq "yes") {
				$out_of_zone_hosts[$q]="$hostname ($ip)";			
				$i++;
				$q++;
				next;
			}
#			$hostname.="." if $hostname =~ /\..+\./ && $hostname !~ /\.$/;
			if ( $hostname eq "unknown" && $ignore_unknown eq "yes" ) {
				$i++;
				next;
			}
			
#			if ( $ip_int >= $fi_ip_int && $ip_int < $la_ip_int ) {
				$ip =~ s/://g;
				print "6${hostname}:${ip}:${TTL}\n";
#			}
			$i++;
		}
	}
	$j++;
}
print "</pre>\n";
}

if ( $out_of_zone_hosts[0] ) {
	my $out_of_zone_data="";
	foreach (@out_of_zone_hosts) {
		$out_of_zone_data.=", $_";
	}
	$out_of_zone_data =~ s/^,//;
	print "<br><p><b>$$lang_vars{note_message}</b><br>$$lang_vars{out_of_zone_data_message}:<br>\n";
	print "<i>$out_of_zone_data</i><p>\n";
}

if ( $server_type eq "tinydns" ) {
	print "<p><br><p><span style=\"float: $ori\"><FORM><INPUT TYPE=\"BUTTON\" VALUE=\"$$lang_vars{atras_message}\" ONCLICK=\"history.go(-1)\" class=\"error_back_link\"></FORM></span>\n";
	$gip->print_end("$client_id","$vars_file","go_to_top");
}

print "<p><br>==================================================================================\n";

if ( $BM_orig > 24 && $ip_version eq "v4" ) {
	print "<p>$$lang_vars{reverse_zone_gt_24_message}<p><br>\n";
	$gip->print_end("$client_id","$vars_file","go_to_top");
}


if ( $overlap_found_bm_lt_24[0] ) {
	my $ignored_reverse_zone_networks="";
	foreach (@overlap_found_bm_lt_24) {
		$ignored_reverse_zone_networks.=", $_";
	}
	print "<p><b>$$lang_vars{note_message}</b><br>$$lang_vars{reverse_zone_lt_24_not_supported_message}:<br>\n";
	$ignored_reverse_zone_networks =~ s/^,//;
	print "<i>$ignored_reverse_zone_networks</i><br>\n";
#	if ( $server_type eq "BIND" ) {
#		print "<i>$ignored_reverse_zone_networks</i><br>$$lang_vars{BIND_try_without_option_create_multiple_reverse_zones_message}<br>\n";
#	} elsif ( $server_type eq "tinydns" ) {
#		print "<i>$ignored_reverse_zone_networks</i><br>$$lang_vars{tinydns_try_without_option_create_multiple_reverse_zones_message}<br>\n";
#	}
}

my $j=0;
my $anz_new_redes=scalar(@new_redes);
my $BM_check;

if ( $server_type eq "BIND" ) {
	foreach (@new_redes) {
		if ( $ip_version eq "v4" ) {
			$new_red=$new_redes[$j];
			$new_red =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\/(\d{1,2})$/;
			$first_oct=$1;
			$second_oct=$2;
			$third_oct=$3;
			$fourth_oct=$4;
			$BM_check=$5;

			if ( $BM_check == 16 ) {
				$arpa_addr=$second_oct . "." . $first_oct . ".in-addr.arpa";
			} else {
				$arpa_addr=$third_oct . "." . $second_oct . "." . $first_oct . ".in-addr.arpa";
			}
		} else {
			$new_red=$new_redes[$j];
			my $nibbles_pre=$new_red;
			$nibbles_pre =~ s/\/.+$//;
			$nibbles_pre =~ s/://g;
			my @nibbles=split(//,$nibbles_pre);
			my @nibbles_reverse=reverse @nibbles;
			my $nibbles="";
			my $rest=128-$BM;
			my $red_part_helper = ($rest-1)/4;
			my $bc="1";
			if ( $red_part_helper =~ /\./ ) {
				$red_part_helper =~ /\d\.(\d)/;
				$bc=$1;
			}

			$red_part_helper =~ s/\.\d*//;
			$red_part_helper++ if $bc > 5;

			my $i=1;
			my $prefix_part="";
			my $host_part="";
			foreach my $num (@nibbles_reverse ) {
				if ( $i==$red_part_helper && $nibbles =~ /\w/) {
					$host_part=$nibbles . "." . $num;
					$nibbles.="." . $num;
				} elsif ( $i==$red_part_helper && $nibbles eq "") {
					$host_part=$num;
					$nibbles=$num;
				} elsif ( $nibbles =~ /\w/) {
					$nibbles .= "." . $num;
				} else {
					$nibbles = $num;
				}
				$i++;
			}
			$prefix_part=$nibbles;
			$prefix_part =~ s/$host_part//;
			$prefix_part =~ s/^\.//;

			$nibbles .= ".ip6.arpa.";
			$arpa_addr=$prefix_part . ".ip6.arpa";
		}

		print "<p><br>";
		print "<b>$$lang_vars{reverse_zone_message} $arpa_addr</b> ($$lang_vars{file_message} $arpa_addr)<p>\n";
		
	my $origin_name='$ORIGIN';

print <<EOF;
<PRE>
$TTL_name	$TTL
$origin_name ${arpa_addr}.
@           IN SOA  ${nameserver1}. root.${domain}. (
			$serial; serial
			$refresh; refresh
			$retry; retry
			$expire; expire
			$minimum; minimum
			) 

	IN	NS	${nameserver1}.
	IN	NS	${nameserver2}.

EOF
		my $fi_la=$ip_fi_la_int{$new_red};
		my ($fi_ip_int,$la_ip_int)=split(",",$fi_la);
		my $i=0;
		if ( $ip_version eq "v4" ) {
			for (my $k=$fi_ip_int+1;$k<=$la_ip_int;$k++) {
				my $ip_int=$k;
				if ( $ip_int >= $fi_ip_int && $ip_int < $la_ip_int ) {
					if ( defined($host_hash_ref->{$k}[0]) && ( ! $create_generic || $create_generic eq "free" ) ) {
						my $hostname=$host_hash_ref->{$k}[1];
						$hostname.="." . $domain . "." if $hostname !~ /\./;
						$hostname.="." if $hostname =~ /\..+\./ && $hostname !~ /\.$/;
						if ( ($hostname eq "unknown.${domain}." && $ignore_unknown eq "yes") || ($hostname =~ /\./ && $hostname !~ /$domain\.?/ && $ignore_out_of_zone_data eq "yes") ) {
							if ( $create_generic ) {
								my $ip_generic=$host_hash_ref->{$k}[0];
								$ip_generic =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/;
								$first_oct=$1;
								$second_oct=$2;
								$third_oct=$3;
								$fourth_oct=$4;
								my $arpa_name_generic=$fourth_oct . "-" . $third_oct . "-" . $second_oct . "-" . $first_oct . "." . "$domain.";
								my $host_oct;
								if ( $BM_check == 16 ) {
									$host_oct=$fourth_oct . "." . $third_oct;
								} else {
									$host_oct=$fourth_oct;
								}
								print "$host_oct	IN PTR $arpa_name_generic\n";
							} else {
								next;
							}
							next;
						}
						my $ip=$host_hash_ref->{$k}[0];
						my $host_oct;
						$ip =~ /\.(\d{1,3})\.(\d{1,3})$/;
						if ( $BM_check == 16 ) {
							$host_oct=$2 . "." . $1;
						} else {
							$host_oct=$2;
						}
						print "$host_oct	IN PTR $hostname\n";
					} else {
						if ( $create_generic ) {
							my $ip_generic=$gip->int_to_ip("$client_id","$k","$ip_version");
							$ip_generic =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/;
							$first_oct=$1;
							$second_oct=$2;
							$third_oct=$3;
							$fourth_oct=$4;
							my $arpa_name_generic=$fourth_oct . "-" . $third_oct . "-" . $second_oct . "-" . $first_oct . "." . "$domain.";
							my $host_oct;
							if ( $BM_check == 16 ) {
								$host_oct=$fourth_oct . "." . $third_oct;
							} else {
								$host_oct=$fourth_oct;
							}
							print "$host_oct	IN PTR $arpa_name_generic\n";
						}
					}
				}
			}
		} else {
			if ( $ip[0] ) {
				my $i=0;
				foreach ( @ip ) {
					my $hostname=$ip[$i]->[1];
					$hostname.="." . $domain . "." if $hostname !~ /\./;
					$hostname.="." if $hostname =~ /\..+\./ && $hostname !~ /\.$/;
					if ( ($hostname eq "unknown.${domain}." && $ignore_unknown eq "yes") || ($hostname =~ /\./ && $hostname !~ /$domain\.?/ && $ignore_out_of_zone_data eq "yes") ) {
						$i++;
						next;
					}

					my $ip_int6=$ip[$i]->[0];
					my $fi_la=$ip_fi_la_int{$new_red};
					my ($fi_ip_int,$la_ip_int)=split(",",$fi_la);
					$fi_ip_int=Math::BigInt->new("$fi_ip_int");
					$la_ip_int=Math::BigInt->new("$la_ip_int");
					$ip_int6=Math::BigInt->new("$ip_int6");
					if ( $ip_int6 >= $fi_ip_int && $ip_int6 < $la_ip_int ) {
						my $ip=$gip->int_to_ip("$client_id","$ip_int6","$ip_version");

						my $nibbles_pre=$ip;
						$nibbles_pre =~ s/://g;
						my @nibbles=split(//,$nibbles_pre);
						my @nibbles_reverse=reverse @nibbles;
						my $nibbles="";
						my $rest=128-$BM;
						my $red_part_helper = ($rest-1)/4;
						my $bc="1";
						if ( $red_part_helper =~ /\./ ) {
							$red_part_helper =~ /\d\.(\d)/;
							$bc=$1;
						}

						$red_part_helper =~ s/\.\d*//;
						$red_part_helper++ if $bc > 5;

						my $j=1;
						my $prefix_part="";
						my $host_part="";
						foreach my $num (@nibbles_reverse ) {
							if ( $j==$red_part_helper && $nibbles =~ /\w/) {
								$host_part=$nibbles . "." . $num;
								$nibbles.="." . $num;
							} elsif ( $j==$red_part_helper && $nibbles eq "") {
								$host_part=$num;
								$nibbles=$num;
							} elsif ( $nibbles =~ /\w/) {
								$nibbles .= "." . $num;
							} else {
								$nibbles = $num;
							}
							$j++;
						}
						$prefix_part=$nibbles;
						$prefix_part =~ s/$host_part//;
						$prefix_part =~ s/^\.//;

						$nibbles .= ".ip6.arpa.";
						$arpa_addr=$prefix_part . ".ip6.arpa";


						print "$host_part	IN PTR $hostname\n";
					}
					$i++;
				}
			}
		}
		print "</PRE>\n";

		print "<p><br>";
		print "<b>named.conf</b><p>\n";

	print <<EOF;
<PRE>
zone "$arpa_addr" {
	type master;
	file "$arpa_addr";
	allow-update { none; };
};
</PRE>
EOF


		$j++;

		print "<p><br>==================================================================================\n" if $j < $anz_new_redes;

	}

} elsif ( $server_type eq "tinydns" ) {
}

print "<p><br><p><br><p>";

print "<span style=\"float: $ori\"><FORM><INPUT TYPE=\"BUTTON\" VALUE=\"$$lang_vars{atras_message}\" ONCLICK=\"history.go(-1)\" class=\"error_back_link\"></FORM></span>\n";

$gip->print_end("$client_id","$vars_file","go_to_top");

