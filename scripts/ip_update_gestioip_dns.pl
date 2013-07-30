#!/usr/bin/perl -w


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


# ip_update_gestioip_dns.pl Version 3.0.0

# script para actualizar la BBDD del sistema GestioIP against the DNS

# This scripts synchronizes only the networks of GestioIP with marked "sync"-field
# see documentation for further information (www.gestioip.net)

# 20130528 v3 p22

# Usage: ./ip_update_gestioip_dns.pl --help

# execute it from cron. Example crontab:
# 30 10 * * * /usr/share/gestioip/bin/ip_update_gestioip_dns.pl -o -m > /dev/null 2>&1


use strict;
use Getopt::Long;
Getopt::Long::Configure ("no_ignore_case");
use DBI;
use Time::Local;
use Time::HiRes qw(sleep);
use Date::Calc qw(Add_Delta_Days); 
use Date::Manip qw(UnixDate);
use Net::IP;
use Net::IP qw(:PROC);
use Net::Ping::External qw(ping);
use Mail::Mailer;
use Socket;
use Parallel::ForkManager;
use FindBin qw($Bin);
use Fcntl qw(:flock);
use Net::DNS;
use POSIX;


my $VERSION="3.0.0";

	 
my $dir = $Bin;

$dir =~ /^(.*)\/bin/;
my $base_dir=$1;



# my $dir = "/apsolute/path/to/$config_name";


my ( $disable_audit, $test, $verbose, $log, $mail, $help, $version_arg, $location_args );
my $config_name="";

GetOptions(
	"verbose!"=>\$verbose,
	"Version!"=>\$version_arg,
	"test!"=>\$test,
	"log=s"=>\$log,
	"config_file_name=s"=>\$config_name,
	"Location=s"=>\$location_args,
	"disable_audit!"=>\$disable_audit,
	"mail!"=>\$mail,
	"help!"=>\$help
) or print_help();

$config_name="ip_update_gestioip.conf" if ! $config_name;
if ( ! -r "${base_dir}/etc/${config_name}" ) {
	print "\nCan't find configuration file \"$config_name\"\n";
	print "\n\"$dir/$config_name\" doesn't exists\n";
	exit 1;
}
my $conf = $base_dir . "/etc/" . $config_name;


my $enable_audit = "1";
$enable_audit = "0" if $test || $disable_audit;

if ( $help ) { print_help(); }
if ( $version_arg ) { print_version(); }
if ( $test && ! $verbose ) { print_help(); }

my %params;

open(VARS,"<$conf") or die "Can not open $conf: $!\n";
while (<VARS>) {
chomp;
s/#.*//;
s/^\s+//;
s/\s+$//;
next unless length;
my ($var, $value) = split(/\s*=\s*/, $_, 2);
$params{$var} = $value;
}
close VARS;

my $lang=$params{lang} || "en";
my $vars_file=$base_dir . "/etc/vars/vars_update_gestioip_" . "$lang";

my $gip_version=get_version();

if ( $VERSION !~ /$gip_version/ ) {
print "Script and GestioIP version are not compatible\n\nGestioIP version: $gip_version - script version: $VERSION\n\n";
exit;
}

my %lang_vars;

open(LANGVARS,"<$vars_file") or die "Can no open $vars_file: $!\n";
while (<LANGVARS>) {
chomp;
s/#.*//;
s/^\s+//;
s/\s+$//;
next unless length;
my ($var, $value) = split(/\s*=\s*/, $_, 2);
$lang_vars{$var} = $value;
}
close LANGVARS;


if ( $params{pass_gestioip} !~ /.+/ ) {
print  "\nERROR\n\n$lang_vars{no_pass_message} $conf)\n\n";
exit 1;
}

### PING HISTORY PATCH to add ping status changes to host history####
### require new event_type: INSERT INTO event_types (id,event_type) VALUES (100,"ping status changed");
### disabled 0; enabled 1;
my $enable_ping_history=0;
my $update_type_audit="4";


my $client_name_conf = $params{client} || "";
my $client_count = count_clients();
my $client_id;
if ( $client_count == "1" ) {
my $one_client_name = check_one_client_name("$client_name_conf") || "";
if ( $one_client_name eq $client_name_conf || $client_name_conf eq "DEFAULT" ) {
	$client_id=get_client_id_one() || "";
}
} else {
$client_id=get_client_id_from_name("$client_name_conf") || "";
}

if ( ! $client_id ) {
print "$client_name_conf: $lang_vars{client_not_found_message} $conf\n";
exit 1;
}

my $ipv4="yes";
$ipv4="" if $params{actualize_ipv4_dns} eq "no";
my $ipv6="yes";
$ipv6="" if $params{actualize_ipv6_dns} eq "no";

my $lockfile = $base_dir . "/var/run/" . $client_name_conf . "_ip_update_gestioip_dns.lock";

no strict 'refs';
open($lockfile, '<', $0) or die("Unable to create lock file: $!\n");
use strict;

unless (flock($lockfile, LOCK_EX|LOCK_NB)) {
print "$0 is already running. Exiting.\n";
exit(1);
}

my $start_time=time();


my $logfile_name;
if ( $client_count == "1" ) {
	$logfile_name = "ip_update_gestioip_dns.log";
} else {
	$logfile_name = $client_name_conf . "_ip_update_gestioip_dns.log";
}

if ( ! $log ) {
	my $logdir="";
	$logdir="$params{logdir}" if $params{logdir};
	if ( ! -d $logdir ) {
		print "$lang_vars{logdir_not_found_message}: $logdir - using $log\n";
		$log=$base_dir . "/var/log/" . $logfile_name;
	} else {
		$log=$logdir . "/" . $logfile_name;
	}
}

my $generic_dyn_host_name=$params{'generic_dyn_host_name'} || "_NO_GENERIC_DYN_NAME_";
$generic_dyn_host_name =~ s/,/|/g;

my $mail_destinatarios="";
my $mail_from="";
if ( $mail ) {
	if ( ! $params{mail_destinatarios} ) {
		print "Please specify the recipients to send the mail to (\"mail_destinatarios\") in $conf\n\n";
		print_help();
		exit 1;
	} elsif ( ! $params{mail_from} ) {
		print "Please specify the mail sender address (\"mail_from\") in $conf\n\n";
		print_help();
		exit 1;
	}
	$mail_destinatarios = \$params{mail_destinatarios};
	$mail_from = \$params{mail_from};
}

my ($s, $mm, $h, $d, $m, $y) = (localtime) [0,1,2,3,4,5];
$m++;
$y+=1900;
if ( $d =~ /^\d$/ ) { $d = "0$d"; }
if ( $s =~ /^\d$/ ) { $s = "0$s"; }
if ( $m =~ /^\d$/ ) { $m = "0$m"; }
if ( $mm =~ /^\d$/ ) { $mm = "0$mm"; }
my $mydatetime = "$y-$m-$d $h:$mm:$s";



open(LOG,">$log") or die "$log: $!\n";


my $count_entradas_dns=0;
my $count_entradas_dns_timeout=0;

print LOG "\n######## Synchronization against DNS ($mydatetime) ########\n\n";
if ( $test ) {
	print LOG "\n--- $lang_vars{test_mod_message} ---\n";
	print "\n--- $lang_vars{test_mod_message} ---\n";
}

my @vigilada_redes=();
if ( $ipv4 && ! $ipv6 ) {
	@vigilada_redes=get_vigilada_redes("$client_id","","v4");
} elsif ( ! $ipv4 && $ipv6 ) {
	@vigilada_redes=get_vigilada_redes("$client_id","","v6");
} else {
	@vigilada_redes=get_vigilada_redes("$client_id");
}


my %location_ids_args=();
my @location_array_names=();
my $db_locations="";
$location_args="" if ! $location_args;
my $locations_conf=$params{process_only_locations} || "";
my $process_locations=$location_args || "";
if ( $process_locations ) {
	$process_locations=$process_locations . ","  . $locations_conf if $process_locations;
} else {
	$process_locations=$locations_conf if $locations_conf;
}


$process_locations =~ s/^\s+//g if $process_locations;
$process_locations =~ s/\s+$//g if $process_locations;
$process_locations =~ s/,\s+/,/g if $process_locations;
if ( $process_locations ) {
	my $db_locations = get_loc_hash("$client_id");
	my @location_array_names = split /,/, $process_locations;
	foreach ( @location_array_names ) {
		if ( ! defined($db_locations->{$_} )) {
			print "\nLocation \"$_\" doesn't exists - location must be equal to the location in the GestioIP database\n";
			print "\n$lang_vars{exiting_message}\n";
			exit 1;
		}
		$location_ids_args{$db_locations->{$_}}="1";
	}

	my @vigilada_redes_new=();
	foreach my $ele(@vigilada_redes) {
		my $loc_id_check=@{$ele}[3];
		if ( exists($location_ids_args{$loc_id_check}) ) {
			push @vigilada_redes_new,$ele;
		}
		
	}
	@vigilada_redes=@vigilada_redes_new;
}


if ( ! $vigilada_redes[0] ) {
	my $location_arg_message="";
	$location_arg_message="(for locations \"$location_args\")" if $location_args;
	print "\n--- $lang_vars{no_sync_redes} $location_arg_message ---\n\n";
	print "\n$lang_vars{mark_red_message}\n";
	print "\n$lang_vars{mark_red_explic_message}\n\n";
	exit 1;
}

my @values_ignorar;
if ( $params{'ignorar'} ) {
	@values_ignorar=split(",",$params{'ignorar'});
} else {
	$values_ignorar[0]="__IGNORAR__";
}



my @linked_cc_id=get_custom_host_column_ids_from_name("$client_id","linked IP");
my $linked_cc_id=$linked_cc_id[0]->[0] || "";

my @client_entries=get_client_entries("$client_id");
my $default_resolver = $client_entries[0]->[20];
my @dns_servers =("$client_entries[0]->[21]","$client_entries[0]->[22]","$client_entries[0]->[23]");


my %res_sub;
my %res;
#my ($first_ip_int,$last_ip_int);
my @zone_records;
my $zone_name;

my $l=0;
foreach (@vigilada_redes) {

	my $red_num="$vigilada_redes[$l]->[2]";

	print "\n$vigilada_redes[$l]->[0]/$vigilada_redes[$l]->[1]\n" if $verbose;
	print LOG "\n$vigilada_redes[$l]->[0]/$vigilada_redes[$l]->[1]\n";

	if ( $params{dyn_rangos_only} eq "yes" ) {
		print "\n($lang_vars{sync_only_rangos_message})\n\n" if $verbose;
		print LOG "\n($lang_vars{sync_only_rangos_message})\n\n";
	} else {
		print "\n" if $verbose;
	}

	my @reserved_ranges_found = ();
	if ( $params{dyn_rangos_only} eq "yes" ) {
		 @reserved_ranges_found=check_for_reserved_range("$client_id","$red_num");
	}

	if ( ! $reserved_ranges_found[0] && $params{dyn_rangos_only} eq "yes" ) {
		print "$lang_vars{no_range_message}\n\n";
		$l++;
		next;
	}

	my @values_redes = get_red("$client_id","$red_num");
	my %cc_values=get_custom_host_column_values_host_hash("$client_id","$red_num");

	if ( ! $values_redes[0] ) {
		print "$lang_vars{algo_malo_message}\n";
		print LOG "$lang_vars{algo_malo_message}\n";
	}

	my $red = "$values_redes[0]->[0]" || "";
	my $BM = "$values_redes[0]->[1]" || "";
	my $descr = "$values_redes[0]->[2]" || "";
	my $loc_id = "$values_redes[0]->[3]" || "";
	my $ip_version = "$values_redes[0]->[7]" || "";

	if ( ! $ipv4 && $ip_version eq "v4" ) {
		$l++;
		next;
	} elsif ( ! $ipv6 &&  $ip_version eq "v6" ) {
		$l++;
		next;
	}


	if ( $BM > 30 && $ip_version eq "v4" ) {
		print "Bitmask > 30 - $lang_vars{ignorado_message}\n" if $verbose;
		print LOG "Bitmask > 30 - $lang_vars{ignorado_message}\n";
		$l++;
		next;
	}

	my $audit_type="23";
	my $audit_class="2";
	my $event="$red/$BM";
	insert_audit_auto("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file") if $enable_audit == "1";

	my $smallest_bm4="16";
	my $smallest_bm6="64";

#	print LOG "\n$red/$BM\n";

	if ( $ip_version eq "v6" ) {
		my ($nibbles, $rest);
		my $red_exp = ip_expand_address ($red,6) if $ip_version eq "v6";
		my $nibbles_pre=$red_exp;
		$nibbles_pre =~ s/://g;
		my @nibbles=split(//,$nibbles_pre);
		my @nibbles_reverse=reverse @nibbles;
		$nibbles="";
		$rest=128-$BM;
		my $red_part_helper = ($rest+1)/4;
		$red_part_helper = ceil($red_part_helper);
		my $n=1;
		foreach my $num (@nibbles_reverse ) {
			if ( $n<$red_part_helper ) {
				$n++;
				next;		
			} elsif ( $nibbles =~ /\w/) {
				$nibbles .= "." . $num;
			} else {
				$nibbles = $num;
			}
			$n++;
		}
		$nibbles .= ".ip6.arpa.";
		$zone_name=$nibbles;
		@zone_records=fetch_zone("$zone_name","$default_resolver",\@dns_servers);
	}

	if ( ! $zone_records[0] && $ip_version eq "v6" ) {
		print LOG "$lang_vars{no_zone_data_message} $zone_name\n";
		print "$lang_vars{no_zone_data_message} $zone_name\n" if $verbose;
		$l++;
		next;
	}



	if ( $ip_version eq "v4" && $BM < $smallest_bm4 ) {
		print LOG "$lang_vars{smalles_bm_manage_message} - Smallest allowed Bitmask: $smallest_bm4 - $lang_vars{ignorado_message}\n\n";
		print "$lang_vars{smalles_bm_manage_message} - Smallest allowed Bitmask: $smallest_bm4 $lang_vars{ignorado_message}\n\n" if $verbose;
		$l++;
		next;
	} elsif ( $ip_version eq "v6" && $BM < $smallest_bm6 ) {
		print LOG "$lang_vars{smalles_bm_manage_message} - Smallest allowed Bitmask: $smallest_bm6 $lang_vars{ignorado_message}\n\n";
		print "$lang_vars{smalles_bm_manage_message} - Smallest allowed Bitmask: $smallest_bm6 $lang_vars{ignorado_message}\n\n" if $verbose;
		$l++;
		next;
	}

	my $redob = "$red/$BM";
	my $host_loc = get_loc_from_redid("$client_id","$red_num");
	$host_loc = "---" if $host_loc eq "NULL";
	my $host_cat = "---";


	if ( $params{dyn_rangos_only} eq "yes" ) {
		print LOG "\n($lang_vars{sync_only_rangos_message})\n\n";
		print "\n($lang_vars{sync_only_rangos_message})\n\n" if $verbose;;
	} else {
		print LOG "\n";
	}


	my $ipob = new Net::IP ($redob) or print LOG "error: $lang_vars{comprueba_red_BM_message}: $red/$BM\n";
	my $redint=($ipob->intip());
	$redint = Math::BigInt->new("$redint");
	my $first_ip_int = $redint + 1;
	$first_ip_int = Math::BigInt->new("$first_ip_int");
	my $last_ip_int = ($ipob->last_int());
	$last_ip_int = Math::BigInt->new("$last_ip_int");
	$last_ip_int = $last_ip_int - 1;


#	if ( $ip_version eq "v6" ) {
#		$first_ip_int--;
#		$last_ip_int++;
#	}

        #check if DNS servers are alive

	my $res_dns;
	my $dns_error = "";

	if ( $default_resolver eq "yes" ) {
		$res_dns = Net::DNS::Resolver->new(
		retry       => 2,
		udp_timeout => 5,
		tcp_timeout => 5,
		recurse     => 1,
		debug       => 0,
                );
	} else {
		$res_dns = Net::DNS::Resolver->new(
		retry       => 2,
		udp_timeout => 5,
		tcp_timeout => 5,
		nameservers => [@dns_servers],
		recurse     => 1,
		debug       => 0,
		);
	}

	my $test_ip_int=$first_ip_int;
	my $test_ip=int_to_ip("$test_ip_int","$ip_version");

	my $ptr_query=$res_dns->query("$test_ip");

	if ( ! $ptr_query) {
		if ( $res_dns->errorstring eq "query timed out" ) {
			print LOG "$lang_vars{no_dns_server_message} (1): " . $res_dns->errorstring . "\n\n";
			print "$lang_vars{no_dns_server_message} (1): " . $res_dns->errorstring . "\n\n" if $verbose;
			$l++;
			next;
		}
	}

	my $used_nameservers = $res_dns->nameservers;

	my $all_used_nameservers = join (" ",$res_dns->nameserver());

	if ( $used_nameservers eq "0" ) {
		print LOG "$lang_vars{no_dns_server_message} (2)\n\n";
		print "$lang_vars{no_dns_server_message} (2)\n\n" if $verbose;
		$l++;
		next;
	}

	if ( $all_used_nameservers eq "127.0.0.1" && $default_resolver eq "yes" ) {
		print LOG "$lang_vars{no_answer_from_dns_message} - $lang_vars{nameserver_localhost_message}\n\n$lang_vars{exiting_message}\n\n";
		print "$lang_vars{no_answer_from_dns_message} - $lang_vars{nameserver_localhost_message}\n\n$lang_vars{exiting_message}\n\n" if $verbose;
		$l++;
		next;
	}

	my $mydatetime = time();

	my $j=0;
#	my $hostname;
	my ( $ip_int, $ip_bin, $ip_ad, $pm, $res, $pid, $ip );
	my ( %res_sub, %res, %result);

	my $MAX_PROCESSES=$params{max_sinc_procs} || "254";
	$pm = new Parallel::ForkManager($MAX_PROCESSES);

	$pm->run_on_finish(
		sub { my ($pid, $exit_code, $ident) = @_;
			$res_sub{$pid}=$exit_code;
		}
	);
	$pm->run_on_start(
		sub { my ($pid,$ident)=@_;
			$res{$pid}="$ident";
		}
	);



        my @ip;
        if ( $params{dyn_rangos_only} eq "yes" ) {
                @ip=get_host_range("$client_id","$first_ip_int","$last_ip_int","$ip_version");
                my $first_ip_int_check = $ip[0]->[0];
                my $last_ip_int_check = $ip[-1]->[0];
                if ( ! $first_ip_int || ! $last_ip_int ) {
                        print LOG "$lang_vars{no_range_message}\n\n";
                        $l++;
                        next;
                }
        } else {
                if ( $ip_version eq "v4" ) {
                        @ip=get_host("$client_id","$first_ip_int","$last_ip_int","$ip_version");
                } else {
                        @ip=get_host_from_red_num("$client_id","$red_num");
                }
        }



	my @found_ip;
	my $p=0;
	foreach my $found_ips (@ip) {
		if ( $found_ips->[0] ) {
			$found_ips->[0]=int_to_ip("$found_ips->[0]","$ip_version");
			$found_ip[$p]=$found_ips->[0];
		}
		$p++;
	}


	my @records=();
	if ( $ip_version eq "v4" ) {
		for (my $m = $first_ip_int; $m <= $last_ip_int; $m++) {
			push (@records,"$m");
		}
	} else {
		@records=@zone_records;
		my @records_new=();
		my $n=0;
		foreach (@zone_records) {
			if ( $_ =~ /(IN.?SOA|IN.?NS)/ ) {
				next;
			}
			$_=/^(.*)\.ip6.arpa/;
			my $nibbles=$1;
			my @nibbles=split('\.',$nibbles);
			@nibbles=reverse(@nibbles);
			my $ip_nibbles="";
			my $o=0;
			foreach (@nibbles) {
				if ( $o == 4 || $o==8 || $o==12 || $o==16 || $o==20 || $o==24 || $o==28 ) {
					$ip_nibbles .= ":" . $_;
				} else {
					$ip_nibbles .= $_;
				}
				$o++;
			}
			$records_new[$n]=$ip_nibbles;
			$n++;
		}
		
		@records=@records_new;
		@records=(@records,@found_ip);
		my %seen;
		for ( my $q = 0; $q <= $#records; ) {
			splice @records, --$q, 1
			if $seen{$records[$q++]}++;
		}
		@records=sort(@records)
	}

	my @records_check=();
	foreach ( @records ) {
		next if ! $_;
		next if $_ !~ /\w+/;
		push (@records_check,"$_");
	}
	@records=sort(@records_check);


	my $i;
	foreach ( @records ) {

		next if ! $_;
		$i=$_;

		$count_entradas_dns++;
		my $exit;

		if ( $ip_version eq "v4" ) {
			$ip_ad=int_to_ip("$i","$ip_version");
		} else {
			$ip_ad=$_;
		}

		
		##fork
		$pid = $pm->start("$ip_ad") and next;
			#child

			my $p;
			if ( $ip_version eq "v4" ) {
				$p = ping(host => "$ip_ad", timeout => 2);
			} else {
				my $command='ping6 -c 1 ' .  $ip_ad;
				my $result=ping6_system("$command","0");
				$p=1 if $result == "0";
			}
			if ( $p ) {
				$exit=0;
			} else {
				$exit=1;
			}

			my $ptr_query="";
			my $dns_result_ip="";

			if ( $default_resolver eq "yes" ) {
				$res_dns = Net::DNS::Resolver->new(
				retry       => 2,
				udp_timeout => 5,
				tcp_timeout => 5,
				recurse     => 1,
				debug       => 0,
				);
			} else {
				$res_dns = Net::DNS::Resolver->new(
				retry       => 2,
				udp_timeout => 5,
				tcp_timeout => 5,
				nameservers => [@dns_servers],
				recurse     => 1,
				debug       => 0,
				);
			}

			$ptr_query = $res_dns->send("$ip_ad");

			$dns_error = $res_dns->errorstring;

			if ( $dns_error eq "NOERROR" ) {
				if ($ptr_query) {
					foreach my $rr ($ptr_query->answer) {
						next unless $rr->type eq "PTR";
						$dns_result_ip = $rr->ptrdname;
					}
				}
			}

			if ( $dns_result_ip && $exit == 0 ) {
				$exit=2;
			} elsif ( $dns_result_ip && $exit == 1 ) {
				$exit=3;
			} elsif ( ! $dns_result_ip && $exit == 0 ) {
				$exit=4;
			}


		$pm->finish($exit); # Terminates the child process

	}

	$pm->wait_all_children;


	while (($pid,$ip) = each ( %res )) {
		$result{$ip}=$res_sub{$pid};
	}

	my $k = 0;
	$i=$first_ip_int;
	my $ip_ad_int="";


	my $host_hash_ref=get_host_hash_check("$client_id","$first_ip_int","$last_ip_int","$red_num");

	foreach ( @records ) {
		if ( ! $_ ) {
			$i++;
			next;
		}

		if ( $ip_version eq "v4" ) {
			$ip_ad_int=$i;
			$ip_ad = int_to_ip("$i","$ip_version");
		} else {
			$ip_ad=$_;
			$ip_ad_int = ip_to_int("$ip_ad","$ip_version");
		}


		my $exit=$result{$ip_ad}; 

		my $range_id="-1";
		$range_id= $ip[$k]->[10] if $ip[$k]->[10] && $ip_ad eq $ip[$k]->[0];

		if ( defined($ip[$k]->[0]) ) {
			if ( $params{dyn_rangos_only} eq "yes" && $range_id == "-1" && $ip_ad eq $ip[$k]->[0] ) {
				$k++;
				$i++;
				next;
			} elsif ( $params{dyn_rangos_only} eq "yes" && $range_id == "-1" && $ip_ad ne $ip[$k]->[0] ) {
				$i++;
				next;
			}
		} elsif ( ! defined($ip[$k]->[0]) && $params{dyn_rangos_only} eq "yes" ) {
			$i++;
			next;
		}

		my $hostname_bbdd;
		my $cat_id="-1";
		my $int_admin="n";
		my $utype="dns";
		my $utype_id;
		my $host_descr = "NULL";
		my $comentario = "NULL";


		if ( defined($ip[$k]->[0]) ) {
			if ( ( $ip[$k]->[1] || $ip[$k]->[10] ne "-1" ) && $ip_ad eq $ip[$k]->[0] ) {
				$hostname_bbdd = $ip[$k]->[1];
				$host_descr = $ip[$k]->[2] if $ip[$k]->[2];
				$cat_id=get_cat_id("$ip[$k]->[4]") if $ip[$k]->[4];
				$int_admin=$ip[$k]->[5] if $ip[$k]->[5];
				$comentario = $ip[$k]->[6] if $ip[$k]->[6];
				$utype=$ip[$k]->[7] if $ip[$k]->[7];
				$utype= "---" if $utype eq "NULL"; 
				$utype_id=get_utype_id("$utype") || "-1";
				$range_id = $ip[$k]->[10] if $ip[$k]->[10];
				
			}
		}


		print "$ip_ad: " if $verbose; 
		print LOG "$ip_ad: "; 

		$utype_id=get_utype_id("$utype") if ! $utype_id;

		my $ping_result=0;
		$ping_result=1 if $exit == "0" || $exit == "2" || $exit == "4";

		# Ignor IP if update type has higher priority than "dns" 
		if ( $utype ne "dns" && $utype ne "---" ) {
			if ( $hostname_bbdd || $range_id ne "-1" ) {
				$k++;
			}
			if ( $hostname_bbdd ) {
				print "$hostname_bbdd - update type: $utype - $lang_vars{ignorado_message}\n" if $verbose;
				print LOG "$hostname_bbdd - update type: $utype - $lang_vars{ignorado_message}\n";
				update_host_ping_info("$client_id","$ip_ad_int","$ping_result","$enable_ping_history","$ip_ad","$update_type_audit","$vars_file") if ! $test;
			} else {
				print "update type: $utype - $lang_vars{ignorado_message}\n" if $verbose;
				print LOG "update type: $utype - $lang_vars{ignorado_message}\n";
			}
			$i++;
			next;
		}
			
		my $ignor_reason=0; # 1: no dns entry; 2: generic auto name; 3: hostname matches ignore-string
		                                        # 1: no dns entry; 2: hostname matches generic-auto-name; 3: hostname matches ignore-string 4: hostname matches generic-dynamic name
		my @dns_result_ip;
		my $hostname;
		if ( $exit == 2 || $exit == 3 ) {

			my $ptr_query="";
			my $dns_result_ip="";

			if ( $default_resolver eq "yes" ) {
				$res_dns = Net::DNS::Resolver->new(
				retry       => 2,
				udp_timeout => 5,
				tcp_timeout => 5,
				recurse     => 1,
				debug       => 0,
				);
			} else {
				$res_dns = Net::DNS::Resolver->new(
				retry       => 2,
				udp_timeout => 5,
				tcp_timeout => 5,
				nameservers => [@dns_servers],
				recurse     => 1,
				debug       => 0,
				);
			}

			$ptr_query = $res_dns->send("$ip_ad");

			$dns_error = $res_dns->errorstring;

			if ( $dns_error eq "NOERROR" ) {
				if ($ptr_query) {
					foreach my $rr ($ptr_query->answer) {
						next unless $rr->type eq "PTR";
						$dns_result_ip = $rr->ptrdname;
					}
				}
			}

			$hostname = $dns_result_ip || "unknown";

			if ( $hostname eq "unknown" ) {
				$count_entradas_dns_timeout++;
				$ignor_reason=1;
			}
		} else {
			$hostname = "unknown";
			$ignor_reason=1;
		}


		my $ptr_name = $ip_ad;
		my $generic_auto="";
		if ( $ip_version eq "v4" ) {
			$ptr_name =~ /(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})/;
			$generic_auto = "$2-$3-$4|$4-$3-$2|$1-$2-$3|$3-$2-$1";
		} else {
			$ptr_name =~ /^(\w+):(\w+):(\w+):(\w+):(\w+):(\w+):(\w+):(\w+)$/;
			$generic_auto = "$2-$3-$4|$4-$3-$2|$1-$2-$3|$3-$2-$1";
		}

		my $igno_name;
		my $igno_set = 0;

		if ( $hostname =~ /$generic_auto/ && $params{ignore_generic_auto} eq "yes" ) {
			$igno_set = 1;
			$hostname="unknown";
			$igno_name="$generic_auto";
			$ignor_reason=2;
		}

		foreach my $ignorar_val(@values_ignorar) {
			if ( $hostname =~ /$ignorar_val/ ) {
				$igno_set = 1;
				$hostname="unknown";
				$igno_name="$_";
				$ignor_reason=3;
			}
			next;
		}

		if ( $hostname =~ /$generic_dyn_host_name/ ) {
			$igno_set = 1;
			$hostname="unknown";
			$igno_name="$generic_dyn_host_name";
			$ignor_reason=4;
		}

		my $duplicated_entry=0;

		if ( $hostname_bbdd ) {

			if ( $hostname_bbdd eq $hostname && $hostname ne "unknown" && $igno_set == "0") {
				print "$lang_vars{tiene_entrada_message}: $hostname_bbdd - $lang_vars{ignorado_message}\n" if $verbose;
				print LOG "$lang_vars{tiene_entrada_message}: $hostname_bbdd - $lang_vars{ignorado_message}\n";
				update_host_ping_info("$client_id","$ip_ad_int","$ping_result","$enable_ping_history","$ip_ad","$update_type_audit","$vars_file") if ! $test;

			} else {
				if ( $params{delete_dns_hosts_down_all} eq "yes" && $hostname eq "unknown" && $hostname_bbdd !~ /$generic_dyn_host_name/ && $ping_result == "0" ) {
					if ( $range_id eq "-1" ) {
						my $host_id=get_host_id_from_ip_int("$client_id","$ip_ad_int");
						delete_custom_host_column_entry("$client_id","$host_id");
						if ( exists $cc_values{"${linked_cc_id}_${host_id}"} ) {
							my $linked_ips=$cc_values{"${linked_cc_id}_${host_id}"}[0];
							my @linked_ips=split(",",$linked_ips);
							foreach my $linked_ip_delete(@linked_ips){
								delete_linked_ip("$client_id","$ip_version","$linked_ip_delete","$ip_ad") if ! $test;
							}
						}
						delete_ip("$client_id","$ip_ad_int","$ip_ad_int","$ip_version") if ! $test;
					} else {
						my $host_id=get_host_id_from_ip_int("$client_id","$ip_ad_int");
						delete_custom_host_column_entry("$client_id","$host_id");
						if ( exists $cc_values{"${linked_cc_id}_${host_id}"} ) {
							my $linked_ips=$cc_values{"${linked_cc_id}_${host_id}"}[0];
							my @linked_ips=split(",",$linked_ips);
							foreach my $linked_ip_delete(@linked_ips){
								delete_linked_ip("$client_id","$ip_version","$linked_ip_delete","$ip_ad") if ! $test;
							}
						}
						clear_ip("$client_id","$ip_ad_int","$ip_ad_int","$ip_version") if ! $test;
					}
					# no dns entry
					if ( $ignor_reason == "1" ) {
						print "$lang_vars{entrada_borrado_message}: $hostname_bbdd ($lang_vars{no_dns_message} + $lang_vars{no_ping_message})\n" if $verbose;
						print LOG "$lang_vars{entrada_borrado_message}: $hostname_bbdd ($lang_vars{no_dns_message} + $lang_vars{no_ping_message})\n";
					# hostname matches generic man auto name
					} elsif ( $ignor_reason == "2" ) {
						print "$lang_vars{entrada_borrado_message}: $hostname_bbdd ($lang_vars{auto_generic_name_message} + $lang_vars{no_ping_message})\n" if $verbose;
						print LOG "$lang_vars{entrada_borrado_message}: $hostname_bbdd ($lang_vars{auto_generic_name_message} + $lang_vars{no_ping_message})\n";
					# hostname matches ignore-string
					} elsif ( $ignor_reason == "3" ) {
						print "$lang_vars{entrada_borrado_message}: $hostname_bbdd ($lang_vars{tiene_man_string_no_ping_message})\n" if $verbose;
						print LOG "$lang_vars{entrada_borrado_message}: $hostname_bbdd ($lang_vars{tiene_man_string_no_ping_message})\n";
					} else {
						print "$lang_vars{entrada_borrado_message}: $hostname_bbdd ($lang_vars{no_ping_message})\n" if $verbose;
						print LOG "$lang_vars{entrada_borrado_message}: $hostname_bbdd ($lang_vars{no_ping_message})\n";
					}
					$k++;
					my $audit_type="14";
					my $audit_class="1";
					my $host_descr_audit = $host_descr;
					$host_descr_audit = "---" if $host_descr_audit eq "NULL";
					my $comentario_audit = $comentario;
					$comentario_audit = "---" if $comentario_audit eq "NULL";
					my $event="$ip_ad,$hostname_bbdd,$host_descr_audit,$host_loc,$host_cat,$comentario_audit";
					insert_audit_auto("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file") if $enable_audit == "1";
					$i++;
					next;
				} elsif ( $hostname eq "unknown" && $hostname_bbdd =~ /$generic_dyn_host_name/ && $ping_result == "0" ) {
					if ( $range_id eq "-1" ) {
						my $host_id=get_host_id_from_ip_int("$client_id","$ip_ad_int");
						delete_custom_host_column_entry("$client_id","$host_id");
						if ( exists $cc_values{"${linked_cc_id}_${host_id}"} ) {
							my $linked_ips=$cc_values{"${linked_cc_id}_${host_id}"}[0];
							my @linked_ips=split(",",$linked_ips);
							foreach my $linked_ip_delete(@linked_ips){
								delete_linked_ip("$client_id","$ip_version","$linked_ip_delete","$ip_ad") if ! $test;
							}
						}
						delete_ip("$client_id","$ip_ad_int","$ip_ad_int","$ip_version") if ! $test;
					} else {
						my $host_id=get_host_id_from_ip_int("$client_id","$ip_ad_int");
						delete_custom_host_column_entry("$client_id","$host_id");
						if ( exists $cc_values{"${linked_cc_id}_${host_id}"} ) {
							my $linked_ips=$cc_values{"${linked_cc_id}_${host_id}"}[0];
							my @linked_ips=split(",",$linked_ips);
							foreach my $linked_ip_delete(@linked_ips){
								delete_linked_ip("$client_id","$ip_version","$linked_ip_delete","$ip_ad") if ! $test;
							}
						}
						clear_ip("$client_id","$ip_ad_int","$ip_ad_int","$ip_version") if ! $test;
					}
					print "$lang_vars{entrada_borrado_message}: $hostname_bbdd ($lang_vars{generic_dyn_host_message} + $lang_vars{no_ping_message})\n" if $verbose;
					print LOG "$lang_vars{entrada_borrado_message}: $hostname_bbdd ($lang_vars{generic_dyn_host_message} + $lang_vars{no_ping_message})\n";
					$k++;
					my $audit_type="14";
					my $audit_class="1";
					my $host_descr_audit = $host_descr;
					$host_descr_audit = "---" if $host_descr_audit eq "NULL";
					my $comentario_audit = $comentario;
					$comentario_audit = "---" if $comentario_audit eq "NULL";
					my $event="$ip_ad,$hostname_bbdd,$host_descr_audit,$host_loc,$host_cat,$comentario_audit";
					insert_audit_auto("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file") if $enable_audit == "1";
					$i++;
					next;
				} elsif ( $hostname eq "unknown" && $ping_result == "1" ) {
					# no dns entry
					if ( $ignor_reason == "1" ) {
						print "$lang_vars{tiene_entrada_message}: $hostname_bbdd ($lang_vars{no_dns_message}) - $lang_vars{ignorado_message}\n" if $verbose;
						print LOG "$lang_vars{tiene_entrada_message}: $hostname_bbdd ($lang_vars{no_dns_message}) - $lang_vars{ignorado_message}\n";
					# generic auto name
					} elsif ( $ignor_reason == "2" ) {
						print "$lang_vars{tiene_entrada_message}: $hostname_bbdd - $lang_vars{ignorado_message}\n" if $verbose;
						print LOG "$lang_vars{tiene_entrada_message}: $hostname_bbdd - $lang_vars{ignorado_message}\n";
					# hostname matches ignore-string
					} elsif ( $ignor_reason == "3" ) {
						print "$lang_vars{tiene_entrada_message}: $hostname_bbdd - $lang_vars{ignorado_message}\n" if $verbose;
						print LOG "$lang_vars{tiene_entrada_message}: $hostname_bbdd - $lang_vars{ignorado_message}\n";
					# hostname matches generic-dynamic name
					} elsif ( $ignor_reason == "4" ) {
						print "$lang_vars{tiene_entrada_message}: $hostname_bbdd - $lang_vars{ignorado_message}<br>\n";
					}
 
					update_host_ping_info("$client_id","$ip_ad_int","$ping_result","$enable_ping_history","$ip_ad","$update_type_audit","$vars_file") if ! $test;
					$k++;
					$i++;
					next;
				}

				if ( $hostname_bbdd ne $hostname ) {
						update_ip_mod("$client_id","$ip_ad_int","$hostname","$host_descr","$loc_id","$int_admin","$cat_id","$comentario","$utype_id","$mydatetime","$red_num","$ping_result") if ! $test;
						print "$lang_vars{entrada_actualizada_message}: $hostname ($lang_vars{entrada_antigua_message}: $hostname_bbdd)\n" if $verbose;
						print LOG "$lang_vars{entrada_actualizada_message}: $hostname ($lang_vars{entrada_antigua_message}: $hostname_bbdd)\n";

					my $audit_type="1";
					my $audit_class="1";
					my $host_descr_audit = $host_descr;
					$host_descr_audit = "---" if $host_descr_audit eq "NULL";
					my $comentario_audit = $comentario;
					$comentario_audit = "---" if $comentario_audit eq "NULL";
					my $event="$ip_ad,$hostname,$host_descr_audit,$host_loc,$host_cat,$comentario_audit";
					insert_audit_auto("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file") if $enable_audit == "1";

				} elsif ( $ping_result == 1 && $hostname_bbdd eq "unknown" && $hostname eq "unknown" ) {
					print "$lang_vars{tiene_entrada_message}: $hostname_bbdd - ($lang_vars{generico_message}) $lang_vars{ignorado_message}\n" if $verbose;
					print LOG "$lang_vars{tiene_entrada_message}: $hostname_bbdd - $lang_vars{ignorado_message}\n";
					update_host_ping_info("$client_id","$ip_ad_int","$ping_result","$enable_ping_history","$ip_ad","$update_type_audit","$vars_file") if ! $test;

				} else {
					update_host_ping_info("$client_id","$ip_ad_int","$ping_result","$enable_ping_history","$ip_ad","$update_type_audit","$vars_file") if ! $test;
					print "$hostname_bbdd: $lang_vars{entrada_cambiado_message} (DNS: $hostname) - $lang_vars{ignorado_message} ($lang_vars{update_type_message}: $utype)\n" if $verbose;
					print LOG "$hostname_bbdd: $lang_vars{entrada_cambiado_message} (DNS: $hostname) - $lang_vars{ignorado_message} ($lang_vars{update_type_message}: $utype)\n";
				}
			}
			$k++;
			$i++;
			next;
		}

		# no hostname_bbdd; 2: dns ok, ping ok; 3: dns ok, ping failed, 4: DNS not ok, ping OK
		if ( $exit eq 2 || $exit eq 3 || $exit eq 4 ) {
			if ( $exit eq 3 && $hostname eq "unknown" && $igno_set == "1" ) {
				if ( $ignor_reason == "2" ) {
					print "$lang_vars{tiene_string_no_ping_message} - $lang_vars{ignorado_message}\n" if $verbose;
					print LOG "$lang_vars{tiene_string_no_ping_message} - $lang_vars{ignorado_message}\n";
				} else {
					print "$lang_vars{tiene_man_string_no_ping_message} - $lang_vars{ignorado_message}\n" if $verbose;
					print LOG "$lang_vars{tiene_man_string_no_ping_message} - $lang_vars{ignorado_message}\n";
				}
				if ( $range_id ne "-1" ) {
					$k++;
				}
				$i++;
				next;
			}
			if ( $range_id eq "-1" ) {
				if ( ! exists $host_hash_ref->{$ip_ad_int} ) {
					insert_ip_mod("$client_id","$ip_ad_int","$hostname","$host_descr","$loc_id","$int_admin","$cat_id","$comentario","$utype_id","$mydatetime","$red_num","$ping_result","$ip_version") if ! $test;
				} else {
					print LOG "DUPLICATED ENTRY IGNORED: $host_hash_ref->{$ip_ad_int}[0], $host_hash_ref->{$ip_ad_int}[1] - $ip_ad, $hostname\n";
					$duplicated_entry=1;
				}
			} else {
				update_ip_mod("$client_id","$ip_ad_int","$hostname","$host_descr","$loc_id","$int_admin","$cat_id","$comentario","$utype_id","$mydatetime","$red_num","$ping_result") if ! $test;
				$k++;
			}
			if ( $duplicated_entry == 0 ) {
				if ( $exit eq 2 && $hostname eq "unknown" && $igno_set == "1") {
					if ( $ignor_reason == "2" ) {
						print "$lang_vars{auto_generic_name_message} - $lang_vars{host_anadido_message}: unknown\n" if $verbose;
						print LOG "$lang_vars{auto_generic_name_message} - $lang_vars{host_anadido_message}: unknown\n";
					} else {
						print "$lang_vars{generic_dyn_host_message} - $lang_vars{host_anadido_message}: unknown\n" if $verbose;
						print LOG "$lang_vars{generic_dyn_host_message} - $lang_vars{host_anadido_message}: unknown\n";
					}
				} else {
					print "$lang_vars{host_anadido_message}: $hostname\n" if $verbose;
					print LOG "$lang_vars{host_anadido_message}: $hostname\n";
				}
				my $audit_type="15";
				my $audit_class="1";
				my $host_descr_audit = $host_descr;
				$host_descr_audit = "---" if $host_descr_audit eq "NULL";
				my $comentario_audit = $comentario;
				$comentario_audit = "---" if $comentario_audit eq "NULL";
				my $event="$ip_ad,$hostname,$host_descr_audit,$host_loc,$host_cat,$comentario_audit";
				insert_audit_auto("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file") if $enable_audit == "1";
			}
		} else {
			print "$lang_vars{no_dns_message} + $lang_vars{no_ping_message} - $lang_vars{ignorado_message}\n" if $verbose;
			print LOG "$lang_vars{no_dns_message} + $lang_vars{no_ping_message} - $lang_vars{ignorado_message}\n";
			if ( $range_id ne "-1" ) {
				$k++;
			}
		} 
		$i++;
	}
$l++;
}

close LOG;

$count_entradas_dns ||= "0";

my $count_entradas = $count_entradas_dns;

my $end_time=time();
my $duration=$end_time - $start_time;
my @parts = gmtime($duration);
my $duration_string = "";
$duration_string = $parts[2] . "h, " if $parts[2] != "0";
$duration_string = $duration_string . $parts[1] . "m";
$duration_string = $duration_string . " and " . $parts[0] . "s";

send_mail() if $mail;

print "\nExecution time: $duration_string\n" if $verbose;

#######################
# Subroutiens
#######################

sub get_vigilada_redes {
	my ( $client_id,$red,$ip_version ) = @_;
	my $ip_ref;
	$ip_version="" if ! $ip_version;
	my $ip_version_expr="";
	if ( $ip_version eq "v4" ) {
		$ip_version_expr="AND ip_version='v4'";
	} elsif ( $ip_version eq "v6" ) {
		$ip_version_expr="AND ip_version='v6'";
	}
	my @vigilada_redes;
        my $dbh = mysql_connection();
        my $sth = $dbh->prepare("SELECT red, BM, red_num, loc FROM net WHERE vigilada=\"y\" AND client_id=\"$client_id\" $ip_version_expr ORDER BY ip_version,red");
        $sth->execute() or print "error while prepareing query: $DBI::errstr\n";
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
		push @vigilada_redes, [ @$ip_ref ];
        }
	$sth->finish();
        $dbh->disconnect;
        return @vigilada_redes;
}

sub check_for_reserved_range {
	my ( $client_id,$red_num ) = @_;
	my $ip_ref;
	my @ranges;
        my $dbh = mysql_connection();
        my $sth = $dbh->prepare("SELECT red_num FROM ranges WHERE red_num = \"$red_num\" AND client_id=\"$client_id\"");
        $sth->execute() or print "error while prepareing query: $DBI::errstr\n";
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
		push @ranges, [ @$ip_ref ];
        }
	$sth->finish();
        $dbh->disconnect;
        return @ranges;
}

sub print_help {
	print "\nusage: ip_update_gestioip.pl [OPTIONS...]\n\n";
	print "-t, --test		testing mode - no database changes would be made (needs option -v)\n";
	print "-v, --verbose 		verbose\n";
	print "-V, --Version 		print version and exit\n";
	print "-l, --log=logfile	logfile\n";
	print "-c, --config_file_name=config_file_name	name of the configuration file (without path)\n";
	print "-L, --Location=locations		coma separted list of locations\n";
	print "-d, --disable_audit	disable audit\n";
	print "-m, --mail		send the result by mail (mail_destinatarios)\n";
	print "-h, --help		help\n\n";
	print "\n\nconfiguration file: $conf\n\n";
	exit;
}

sub print_version {
	print "\n$0 Version $VERSION\n\n";
	exit 0;
}


sub send_mail {
	my $mailer;
	if ( $params{smtp_server} ) {
		$mailer = Mail::Mailer->new('smtp', Server => $params{smtp_server});
	} else {
		$mailer = Mail::Mailer->new("");
	}
	$mailer->open({	From	=> "$$mail_from",
			To	=> "$$mail_destinatarios",
			Subject	=> "Resultado update BBDD GestioIP DNS"
		     }) or die "error while sending mail: $!\n";
	open (LOG_MAIL,"<$log") or die "can not open log file: $!\n";
	while (<LOG_MAIL>) {
		print $mailer $_ if $_ !~ /$lang_vars{ignorado_message}|^$/;
	}
	print $mailer "\n\n$count_entradas $lang_vars{entries_processed_message} (DNS Timeouts: $count_entradas_dns_timeout)\n";
	print $mailer "\n\nExecution time: $duration_string\n";
	print $mailer "\n\n\n\n\n\n\n\n\n--------------------------------\n\n";
	print $mailer "$lang_vars{auto_mail_message}\n";
	$mailer->close;
	close LOG;
}

sub int_to_ip {
	my ($ip_int,$ip_version)=@_;
	my ( $ip_bin, $ip_ad);
	if ( $ip_version eq "v4" ) {
		$ip_bin = ip_inttobin ($ip_int,4);
		$ip_ad = ip_bintoip ($ip_bin,4);
	} else {
		$ip_bin = ip_inttobin ($ip_int,6);
		$ip_ad = ip_bintoip ($ip_bin,6);
	}
	return $ip_ad;
}

sub ip_to_int {
        my ($ip,$ip_version)=@_;
        my ( $ip_bin, $ip_int);
        if ( $ip_version eq "v4" ) {
                $ip_bin = ip_iptobin ($ip,4);
                $ip_int = new Math::BigInt (ip_bintoint($ip_bin));
        } else {
                my $ip=ip_expand_address ($ip,6);
                $ip_bin = ip_iptobin ($ip,6);
                $ip_int = new Math::BigInt (ip_bintoint($ip_bin));
        }
        return $ip_int;
}


sub mysql_connection {
    my $dbh = DBI->connect("DBI:mysql:$params{sid_gestioip}:$params{bbdd_host_gestioip}:$params{bbdd_port_gestioip}",$params{user_gestioip},$params{pass_gestioip}) or
    die "Cannot connect: ". $DBI::errstr;
    return $dbh;
}

sub insert_audit_auto {
        my ($client_id,$event_class,$event_type,$event,$update_type_audit,$vars_file) = @_;
	my $user=$ENV{'USER'};
        my $mydatetime=time();
        my $dbh = mysql_connection();
        my $qevent_class = $dbh->quote( $event_class );
        my $qevent_type = $dbh->quote( $event_type );
        my $qevent = $dbh->quote( $event );
        my $quser = $dbh->quote( $user );
        my $qupdate_type_audit = $dbh->quote( $update_type_audit );
        my $qmydatetime = $dbh->quote( $mydatetime );
        my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("INSERT INTO audit_auto (event,user,event_class,event_type,update_type_audit,date,client_id) VALUES ($qevent,$quser,$qevent_class,$event_type,$qupdate_type_audit,$qmydatetime,$qclient_id)") or die "Can not execute statement: $dbh->errstr";
        $sth->execute() or die "Can not execute statement: $dbh->errstr";
        $sth->finish();
}

sub get_red {
        my ( $client_id, $red_num ) = @_;
        my $ip_ref;
        my @values_redes;
        my $dbh = mysql_connection();
        my $qred_num = $dbh->quote( $red_num );
        my $sth = $dbh->prepare("SELECT red, BM, descr, loc, vigilada, comentario, categoria, ip_version FROM net WHERE red_num=$qred_num  AND client_id=\"$client_id\"") or die "Can not execute statement: $dbh->errstr";
        $sth->execute() or die "Can not execute statement: $dbh->errstr";
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
        push @values_redes, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @values_redes;
}

sub get_loc_from_redid {
        my ( $client_id, $red_num ) = @_;
        my @values_locations;
        my ( $ip_ref, $red_loc );
        my $dbh = mysql_connection();
        my $qred_num = $dbh->quote( $red_num );
        my $sth = $dbh->prepare("SELECT l.loc FROM locations l, net n WHERE n.red_num = $qred_num AND n.loc = l.id AND n.client_id=\"$client_id\"") or die "Can not execute statement: $dbh->errstr";
        $sth->execute() or die "Can not execute statement: $dbh->errstr";
        $red_loc = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $red_loc;
}

sub get_loc_hash {
	my ( $client_id ) = @_;
	my %values;
	my $ip_ref;
	my $dbh = mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );
	my $sth = $dbh->prepare("SELECT id,loc FROM locations WHERE ( client_id = $qclient_id OR client_id = '9999' )") or die "Can not execute statement: $dbh->errstr";
	$sth->execute() or die "Can not execute statement: $dbh->errstr";
		
	while ( $ip_ref = $sth->fetchrow_hashref ) {
		my $id = $ip_ref->{'id'};
		my $loc = $ip_ref->{'loc'};
		$values{$loc}="$id";
	}

	$dbh->disconnect;

	return \%values;
}


sub get_host {
        my ( $client_id, $first_ip_int, $last_ip_int,$ip_version ) = @_;
        my @values_ip;
        my $ip_ref;
        my $dbh = mysql_connection();
        my $qfirst_ip_int = $dbh->quote( $first_ip_int );
        my $qlast_ip_int = $dbh->quote( $last_ip_int );

	my $match="h.ip BETWEEN $qfirst_ip_int AND $qlast_ip_int";
	if ( $ip_version eq "v4" ) {
		$match="CAST(h.ip AS UNSIGNED) BETWEEN $qfirst_ip_int AND $qlast_ip_int";
	}

        my $sth = $dbh->prepare("SELECT h.ip, h.hostname, h.host_descr, l.loc, c.cat, h.int_admin, h.comentario, ut.type, h.alive, h.last_response, h.range_id FROM host h, locations l, categorias c, update_type ut WHERE $match AND h.loc = l.id AND h.categoria = c.id AND h.update_type = ut.id AND h.client_id=\"$client_id\" ORDER BY h.ip") or die "Can not execute statement: $dbh->errstr";
        $sth->execute() or die "Can not execute statement: $dbh->errstr";
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
        push @values_ip, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @values_ip;
}

sub get_host_range {
        my ( $client_id,$first_ip_int, $last_ip_int,$ip_version ) = @_;
        my @values_ip;
        my $ip_ref;
        my $dbh = mysql_connection();
        my $qfirst_ip_int = $dbh->quote( $first_ip_int );
        my $qlast_ip_int = $dbh->quote( $last_ip_int );

	my $match="h.ip BETWEEN $qfirst_ip_int AND $qlast_ip_int";
	if ( $ip_version eq "v4" ) {
		$match="CAST(h.ip AS UNSIGNED) BETWEEN $qfirst_ip_int AND $qlast_ip_int";
	}

        my $sth = $dbh->prepare("SELECT h.ip, h.hostname, h.host_descr, l.loc, c.cat, h.int_admin, h.comentario, ut.type, h.alive, h.last_response, h.range_id FROM host h, locations l, categorias c, update_type ut WHERE $match AND h.loc = l.id AND h.categoria = c.id AND h.update_type = ut.id AND range_id != '-1' AND h.client_id=\"$client_id\" ORDER BY h.ip") or die "Can not execute statement: $dbh->errstr";
        $sth->execute() or die "Can not execute statement: $dbh->errstr";
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
        push @values_ip, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @values_ip;
}


sub get_cat_id {
        my ( $cat ) = @_;
        my $cat_id;
        my $dbh = mysql_connection();
        my $qcat = $dbh->quote( $cat );
        my $sth = $dbh->prepare("SELECT id FROM categorias WHERE cat=$qcat
                        ") or die "Can not execute statement: $dbh->errstr";
        $sth->execute() or die "Can not execute statement: $dbh->errstr";
        $cat_id = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $cat_id;
}

sub get_utype_id {
        my ( $utype ) = @_;
        my $utype_id;
        my $dbh = mysql_connection();
        my $qutype = $dbh->quote( $utype );
        my $sth = $dbh->prepare("SELECT id FROM update_type WHERE type=$qutype
                        ") or die "Can not execute statement: $dbh->errstr";
        $sth->execute() or die "Can not execute statement: $dbh->errstr";
        $utype_id = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $utype_id;
}


sub update_host_ping_info {
	my ( $client_id,$ip_int,$ping_result_new,$enable_ping_history,$ip_ad,$update_type_audit,$vars_file) = @_;

	$enable_ping_history="" if ! $enable_ping_history;
	$update_type_audit="4" if ! $update_type_audit;
	my $ping_result_old;

        my $dbh = mysql_connection();
	my $qip_int = $dbh->quote( $ip_int );

	my $qmydatetime = $dbh->quote( time() );
	my $alive = $dbh->quote( $ping_result_new );
        my $qclient_id = $dbh->quote( $client_id );

	my $sth;

	$sth = $dbh->prepare("SELECT alive FROM host WHERE ip=$qip_int AND client_id = $qclient_id
		") or die "Can not execute statement: $dbh->errstr";
	$sth->execute();
	$ping_result_old = $sth->fetchrow_array || "";
	$ping_result_old = 0 if ! $ping_result_old || $ping_result_old eq "NULL";

	$sth = $dbh->prepare("UPDATE host SET alive=$alive, last_response=$qmydatetime WHERE ip=$qip_int AND client_id = $qclient_id") or die "Can not execute statement: $dbh->errstr";
	$sth->execute() or die "Can not execute statement: $dbh->errstr";
	$sth->finish();
	$dbh->disconnect;

	if ( $enable_ping_history eq 1 && $ping_result_old ne $ping_result_new ) {
		my $ping_state_old;
		my $ping_state_new;
		if ( $ping_result_old eq 1 ) {
			$ping_state_old="up";
			$ping_state_new="down";
		} else {
			$ping_state_old="down";
			$ping_state_new="up";
		}
		
		
		my $audit_type="100";
		my $audit_class="1";
		my $event="$ip_ad: $ping_state_old -> $ping_state_new";
		insert_audit_auto("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");
	}
}

sub delete_ip {
        my ( $client_id,$first_ip_int, $last_ip_int,$ip_version ) = @_;
        my $dbh = mysql_connection();
        my $qfirst_ip_int = $dbh->quote( $first_ip_int );
        my $qlast_ip_int = $dbh->quote( $last_ip_int );

	my $match="ip BETWEEN $qfirst_ip_int AND $qlast_ip_int";
	if ( $ip_version eq "v4" ) {
		$match="CAST(ip AS UNSIGNED) BETWEEN $qfirst_ip_int AND $qlast_ip_int";
	}

        my $sth = $dbh->prepare("DELETE FROM host WHERE $match AND client_id=\"$client_id\""
                                ) or die "Can not execute statement: $dbh->errstr";
        $sth->execute() or die "Can not execute statement: $dbh->errstr";
        $sth->finish();
        $dbh->disconnect;
}

sub clear_ip {
        my ( $client_id,$first_ip_int, $last_ip_int, $ip_version ) = @_;
        my $dbh = mysql_connection();
        my $qfirst_ip_int = $dbh->quote( $first_ip_int );
        my $qlast_ip_int = $dbh->quote( $last_ip_int );

	my $match="ip BETWEEN $qfirst_ip_int AND $qlast_ip_int";
	if ( $ip_version eq "v4" ) {
		$match="CAST(ip AS UNSIGNED) BETWEEN $qfirst_ip_int AND $qlast_ip_int";
	}

        my $sth = $dbh->prepare("UPDATE host SET hostname='', host_descr='', int_admin='n', alive='', last_response='' WHERE $match AND client_id=\"$client_id\""
                                ) or die "Can not execute statement: $dbh->errstr";
        $sth->execute() or die "Can not execute statement: $dbh->errstr";
        $sth->finish();
        $dbh->disconnect;
}

sub insert_ip_mod {
        my ( $client_id,$ip_int, $hostname, $host_descr, $loc, $int_admin, $cat, $comentario, $update_type, $mydatetime, $red_num, $alive, $ip_version  ) = @_;
        my $dbh = mysql_connection();
        my $sth;
        my $qhostname = $dbh->quote( $hostname );
        my $qhost_descr = $dbh->quote( $host_descr );
        my $qloc = $dbh->quote( $loc );
        my $qint_admin = $dbh->quote( $int_admin );
        my $qcat = $dbh->quote( $cat );
        my $qcomentario = $dbh->quote( $comentario );
        my $qupdate_type = $dbh->quote( $update_type );
        my $qmydatetime = $dbh->quote( $mydatetime );
        my $qip_int = $dbh->quote( $ip_int );
        my $qred_num = $dbh->quote( $red_num );
        my $qclient_id = $dbh->quote( $client_id );
        my $qip_version = $dbh->quote( $ip_version );
        if ( defined($alive) ) {
                my $qalive = $dbh->quote( $alive );
                my $qlast_response = $dbh->quote( time() );
                $sth = $dbh->prepare("INSERT INTO host (ip,hostname,host_descr,loc,red_num,int_admin,categoria,comentario,update_type,last_update,alive,last_response,client_id,ip_version) VALUES ($qip_int,$qhostname,$qhost_descr,$qloc,$qred_num,$qint_admin,$qcat,$qcomentario,$qupdate_type,$qmydatetime,$qalive,$qlast_response,$qclient_id,$qip_version)"
                                ) or die "Can not execute statement: $dbh->errstr";
        } else {
                $sth = $dbh->prepare("INSERT INTO host (ip,hostname,host_descr,loc,red_num,int_admin,categoria,comentario,update_type,last_update,client_id,ip_version) VALUES ($qip_int,$qhostname,$qhost_descr,$qloc,$qred_num,$qint_admin,$qcat,$qcomentario,$qupdate_type,$qmydatetime,$qclient_id,$qip_version)"
                                ) or die "Can not execute statement: $dbh->errstr";
        }
        $sth->execute() or die "Can not execute statement: $dbh->errstr";
        $sth->finish();
        $dbh->disconnect;
}

sub update_ip_mod {
        my ( $client_id,$ip_int, $hostname, $host_descr, $loc, $int_admin, $cat, $comentario, $update_type, $mydatetime, $red_num, $alive ) = @_;
        my $dbh = mysql_connection();
        my $sth;
        my $qhostname = $dbh->quote( $hostname );
        my $qhost_descr = $dbh->quote( $host_descr );
        my $qloc = $dbh->quote( $loc );
        my $qint_admin = $dbh->quote( $int_admin );
        my $qcat = $dbh->quote( $cat );
        my $qcomentario = $dbh->quote( $comentario );
        my $qupdate_type = $dbh->quote( $update_type );
        my $qmydatetime = $dbh->quote( $mydatetime );
        my $qred_num = $dbh->quote( $red_num );
        my $qip_int = $dbh->quote( $ip_int );
        my $qclient_id = $dbh->quote( $client_id );
        if ( defined($alive) ) {
                my $qalive = $dbh->quote( $alive );
                my $qlast_response = $dbh->quote( time() );
                $sth = $dbh->prepare("UPDATE host SET hostname=$qhostname, host_descr=$qhost_descr, loc=$qloc, int_admin=$qint_admin, categoria=$qcat, comentario=$qcomentario, update_type=$qupdate_type, last_update=$qmydatetime, red_num=$qred_num, alive=$qalive, last_response=$qlast_response WHERE ip=$qip_int AND client_id=$qclient_id"
                                ) or die "Can not execute statement: $dbh->errstr";
        } else {
                $sth = $dbh->prepare("UPDATE host SET hostname=$qhostname, host_descr=$qhost_descr, loc=$qloc, int_admin=$qint_admin, categoria=$qcat, comentario=$qcomentario, update_type=$qupdate_type, last_update=$qmydatetime, red_num=$qred_num WHERE ip=$qip_int AND client_id=$qclient_id"
                                ) or die "Can not execute statement: $dbh->errstr";
        }
        $sth->execute() or die "Can not execute statement: $dbh->errstr";
        $sth->finish();
        $dbh->disconnect;
}


sub count_clients {
        my $val;
        my $dbh = mysql_connection();
        my $sth = $dbh->prepare("SELECT count(*) FROM clients
                        ") or die "Can not execute statement: $dbh->errstr";
        $sth->execute() or die "Can not execute statement: $dbh->errstr";
        $val = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $val;
}

sub check_one_client_name {
	my ($client_name) = @_; 
        my $val;
        my $dbh = mysql_connection();
        my $sth = $dbh->prepare("SELECT client FROM clients WHERE client=\"$client_name\"
                        ") or die "Can not execute statement: $dbh->errstr";
        $sth->execute() or die "Can not execute statement: $dbh->errstr";
        $val = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $val;
}

sub get_client_id_one {
	my ($client_name) = @_; 
        my $val;
        my $dbh = mysql_connection();
        my $sth = $dbh->prepare("SELECT id FROM clients
                        ") or die "Can not execute statement: $dbh->errstr";
        $sth->execute() or die "Can not execute statement: $dbh->errstr";
        $val = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $val;
}

sub get_client_id_from_name {
        my ( $client_name ) = @_;
        my $val;
        my $dbh = mysql_connection();
        my $qclient_name = $dbh->quote( $client_name );
        my $sth = $dbh->prepare("SELECT id FROM clients WHERE client=$qclient_name");
        $sth->execute() or  die "Can not execute statement:$sth->errstr";
        $val = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $val;
}

sub get_client_entries {
        my ( $client_id ) = @_;
        my @values;
        my $ip_ref;
        my $dbh = mysql_connection();
        my $qclient_id = $dbh->quote( $client_id );
	my $sth;
        $sth = $dbh->prepare("SELECT c.client,ce.phone,ce.fax,ce.address,ce.comment,ce.contact_name_1,ce.contact_phone_1,ce.contact_cell_1,ce.contact_email_1,ce.contact_comment_1,ce.contact_name_2,ce.contact_phone_2,ce.contact_cell_2,ce.contact_email_2,ce.contact_comment_2,ce.contact_name_3,ce.contact_phone_3,ce.contact_cell_3,ce.contact_email_3,ce.contact_comment_3,ce.default_resolver,ce.dns_server_1,ce.dns_server_2,ce.dns_server_3 FROM clients c, client_entries ce WHERE c.id = ce.client_id AND c.id = $qclient_id") or die "Can not execute statement: $sth->errstr";
        $sth->execute() or die "Can not execute statement:$sth->errstr";
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
        push @values, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @values;
}


sub get_version {
        my $val;
        my $dbh = mysql_connection();
        my $sth = $dbh->prepare("SELECT version FROM global_config");
        $sth->execute() or  die "Can not execute statement:$sth->errstr";
        $val = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $val;
}

sub get_host_id_from_ip_int {
        my ( $client_id,$ip_int ) = @_;
        my $val;
        my $dbh = mysql_connection();
        my $qip_int = $dbh->quote( $ip_int );
        my $qclient_id = $dbh->quote( $client_id );
	my $sth;
        $sth = $dbh->prepare("SELECT id FROM host WHERE ip=$qip_int AND client_id=$qclient_id") or die "Can not execute statement: $dbh->errstr";
        $sth->execute() or die "Can not execute statement:$sth->errstr";
        $val = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $val;
}

sub delete_custom_host_column_entry {
        my ( $client_id, $host_id ) = @_;
        my $dbh = mysql_connection();
        my $qhost_id = $dbh->quote( $host_id );
        my $qclient_id = $dbh->quote( $client_id );
	my $sth;
        $sth = $dbh->prepare("DELETE FROM custom_host_column_entries WHERE host_id = $qhost_id AND client_id = $qclient_id") or die "Can not execute statement: $dbh->errstr";
        $sth->execute() or die "Can not execute statement:$sth->errstr";
        $sth->finish();
        $dbh->disconnect;
}

sub ping6_system {
	my ($command,$success) = @_;
	my $devnull = "/dev/null";
	$command .= " 1>$devnull 2>$devnull";
	my $exit_status = system($command) >> 8;
	return $exit_status;
}


sub fetch_zone {
        my ($zone_name,$default_resolver,$dns_servers)=@_;
        $default_resolver="" if $default_resolver;
        my @zone_records;
        my $res;

        if ( $default_resolver eq "yes" ) {
                $res = Net::DNS::Resolver->new(
                retry       => 2,
                udp_timeout => 5,
                recurse     => 1,
                debug       => 0,
                );
        } else {
                $res = Net::DNS::Resolver->new(
                retry       => 2,
                udp_timeout => 5,
                nameservers => [@$dns_servers],
                recurse     => 1,
                debug       => 0,
                );
        }


        my @fetch_zone = $res->axfr("$zone_name");

        my $i=0;
        my $rr;
        foreach $rr (@fetch_zone) {
                $zone_records[$i]=$rr->string;
                $i++;
        }
        return @zone_records;
}

sub get_host_from_red_num {
        my ( $client_id, $red_num ) = @_;
        my @values_ip;
        my $ip_ref;
        my $dbh = mysql_connection();
        my $qred_num = $dbh->quote( $red_num );
        my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("SELECT h.ip, h.hostname, h.host_descr, l.loc, c.cat, h.int_admin, h.comentario, ut.type, h.alive, h.last_response, h.range_id, h.id FROM host h, locations l, categorias c, update_type ut WHERE h.red_num=$qred_num AND h.loc = l.id AND h.categoria = c.id AND h.update_type = ut.id AND h.client_id = $qclient_id ORDER BY h.ip"
                ) or die "$DBI::errstr";
        $sth->execute() or die "$DBI::errstr";
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
                push @values_ip, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @values_ip;
}



sub get_custom_host_columns_from_net_id_hash {
	my ( $client_id,$host_id ) = @_;
	my %cc_values;
	my $ip_ref;
        my $dbh = mysql_connection();
	my $qhost_id = $dbh->quote( $host_id );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("SELECT DISTINCT cce.cc_id,cce.entry,cc.name,cc.column_type_id FROM custom_host_column_entries cce, custom_host_columns cc WHERE  cce.cc_id = cc.id AND host_id = $host_id AND cce.client_id = $qclient_id") or die "Can not execute statement: $dbh->errstr";
        $sth->execute() or die "$DBI::errstr";
        while ( $ip_ref = $sth->fetchrow_hashref ) {
		my $id = $ip_ref->{cc_id};
		my $name = $ip_ref->{name};
		my $entry = $ip_ref->{entry};
		my $column_type_id = $ip_ref->{column_type_id};
		push @{$cc_values{$id}},"$name","$entry","$column_type_id";
        }
        $dbh->disconnect;
        return %cc_values;
}



sub delete_linked_ip {
	my ( $client_id,$ip_version,$linked_ip_old,$ip,$host_id_linked ) = @_;

	my $ip_version_ip_old;
	if ( $linked_ip_old =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/ ) {
		$ip_version_ip_old="v4";
	} else {
		$ip_version_ip_old="v6";
	}

	my $cc_name="linked IP";
	my $cc_id="";
	my $pc_id="";
	$host_id_linked="" if ! $host_id_linked;
	if ( ! $host_id_linked ) {
		my $ip_int_linked=ip_to_int("$linked_ip_old","$ip_version_ip_old") || "";
		$host_id_linked=get_host_id_from_ip_int("$client_id","$ip_int_linked") || "";
	}
	return if ! $host_id_linked;
	my %custom_host_column_values=get_custom_host_columns_from_net_id_hash("$client_id","$host_id_linked");
	while ( my ($key, @value) = each(%custom_host_column_values) ) {
		if ( $value[0]->[0] eq $cc_name ) {
			$cc_id=$key;
			$pc_id=$value[0]->[2];
			last;
		}
	}

	my $linked_cc_entry=get_custom_host_column_entry("$client_id","$host_id_linked","$cc_name","$pc_id") || "";
	my $linked_ip_comp=$ip;
	$linked_ip_comp = ip_compress_address ($linked_ip_comp, 6) if $ip_version eq "v6";
	$linked_cc_entry =~ s/\b${linked_ip_comp}\b//;
	$linked_cc_entry =~ s/^,//;
	$linked_cc_entry =~ s/,$//;
	$linked_cc_entry =~ s/,,/,/;
	# delete entry from linked host
	if ( $linked_cc_entry ) {
		update_custom_host_column_value_host_modip("$client_id","$cc_id","$pc_id","$host_id_linked","$linked_cc_entry");
	} else {
		delete_single_custom_host_column_entry("$client_id","$host_id_linked","$linked_ip_comp","$pc_id");
	}
}



sub delete_single_custom_host_column_entry {
	my ( $client_id, $host_id, $cc_entry_host, $pc_id ) = @_;
        my $dbh = mysql_connection();
	my $qhost_id = $dbh->quote( $host_id );
	my $qcc_entry_host = $dbh->quote( $cc_entry_host );
	my $qpc_id = $dbh->quote( $pc_id );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("DELETE FROM custom_host_column_entries WHERE host_id = $qhost_id AND entry = $qcc_entry_host AND pc_id = $qpc_id"
                                ) or die "Can not execute statement: $dbh->errstr";
        $sth->execute() or die "$DBI::errstr";
        $sth->finish();
        $dbh->disconnect;
}


sub update_custom_host_column_value_host_modip {
	my ( $client_id, $cc_id, $pc_id, $host_id, $entry ) = @_;
        my $dbh = mysql_connection();
	my $qcc_id = $dbh->quote( $cc_id );
	my $qpc_id = $dbh->quote( $pc_id );
	my $qhost_id = $dbh->quote( $host_id );
	my $qentry = $dbh->quote( $entry );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("UPDATE custom_host_column_entries SET entry=$qentry WHERE pc_id=$qpc_id AND host_id=$qhost_id AND cc_id=$qcc_id");
        $sth->execute() or die "$DBI::errstr";
        $sth->finish();
        $dbh->disconnect;
}


sub get_custom_host_column_entry {
	my ( $client_id, $host_id, $cc_name, $pc_id ) = @_;
        my $dbh = mysql_connection();
	my $qhost_id = $dbh->quote( $host_id );
	my $qcc_name = $dbh->quote( $cc_name );
	my $qpc_id = $dbh->quote( $pc_id );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("SELECT cce.cc_id,cce.entry from custom_host_column_entries cce, custom_host_columns cc, predef_host_columns pc WHERE cc.name=$qcc_name AND cce.host_id = $qhost_id AND cce.cc_id = cc.id AND cc.column_type_id= pc.id AND pc.id = $qpc_id AND cce.client_id = $qclient_id
                        ") or die "Can not execute statement: $dbh->errstr";
        $sth->execute() or die "$DBI::errstr";
        my $entry = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $entry;
}


sub get_linked_custom_columns_hash {
	my ( $client_id,$red_num,$cc_id,$ip_version ) = @_;
	my %cc_values;
	my $ip_ref;
        my $dbh = mysql_connection();
	my $qred_num = $dbh->quote( $red_num );
	my $qcc_id = $dbh->quote( $cc_id );
	my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("SELECT ce.cc_id,ce.pc_id,ce.host_id,ce.entry,h.ip,INET_NTOA(h.ip) FROM custom_host_column_entries ce, host h WHERE ce.cc_id=$qcc_id AND ce.host_id=h.id AND ce.host_id IN ( select id from host WHERE red_num=$qred_num ) AND (h.client_id = $qclient_id OR h.client_id = '9999')")
		or die "Can not execute statement: $dbh->errstr";
        $sth->execute() or die "$DBI::errstr";
        while ( $ip_ref = $sth->fetchrow_hashref ) {
		my $ip="";
		my $ip_int = $ip_ref->{'ip'};
		if ( $ip_version eq "v4" ) {
			$ip = $ip_ref->{'INET_NTOA(h.ip)'};
		} else {
			$ip = int_to_ip("$ip_int","$ip_version");
		}
		my $entry = $ip_ref->{entry};
		my $host_id = $ip_ref->{host_id};
		push @{$cc_values{$ip_int}},"$entry","$ip","$host_id";
        }
        $dbh->disconnect;
        return %cc_values;
}

sub get_custom_host_column_values_host_hash {
	my ( $client_id, $red_num ) = @_;
	my %redes;
	my $ip_ref;
	my $red_num_expr = "" if ! $red_num;
	$red_num_expr = "AND host.red_num = '" . $red_num . "'" if $red_num;
        my $dbh = mysql_connection();
	my $qclient_id = $dbh->quote( $client_id );

	my $sth = $dbh->prepare("SELECT DISTINCT cce.cc_id,cce.host_id,cce.entry,pc.name,pc.id FROM custom_host_column_entries cce INNER JOIN predef_host_columns pc INNER JOIN custom_host_columns cc INNER JOIN host ON cc.column_type_id = pc.id AND cce.cc_id = cc.id AND cce.host_id = host.id WHERE cce.client_id = $qclient_id $red_num_expr ORDER BY pc.id") or die "Can not execute statement: $dbh->errstr";
        $sth->execute() or die "$DBI::errstr";
        while ( $ip_ref = $sth->fetchrow_hashref ) {
		my $cc_id = $ip_ref->{cc_id};
		my $host_id = $ip_ref->{host_id};
		my $entry = $ip_ref->{entry};
		my $name = $ip_ref->{name};
		push @{$redes{"${cc_id}_${host_id}"}},"$entry","$name";
        }
        $dbh->disconnect;
        return %redes;
}



sub get_custom_host_column_ids_from_name {
	my ( $client_id, $column_name ) = @_;
	my @values;
	my $ip_ref;
        my $dbh = mysql_connection();
	my $qcolumn_name = $dbh->quote( $column_name );
	my $sth;
	$sth = $dbh->prepare("SELECT id FROM custom_host_columns WHERE name=$qcolumn_name") or die "Can not execute statement: $dbh->errstr";
        $sth->execute() or die "$DBI::errstr";
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
		push @values, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @values;
}


sub get_host_hash_check {
	my ( $client_id,$first_ip_int,$last_ip_int,$red_num ) = @_;

	my %values_ip = ();
	my $ip_ref;
        my $dbh = mysql_connection();
        my $qfirst_ip_int = $dbh->quote( $first_ip_int );
        my $qlast_ip_int = $dbh->quote( $last_ip_int );
	my $qclient_id = $dbh->quote( $client_id );
	my $qred_num = $dbh->quote( $red_num );

	my $sth = $dbh->prepare("SELECT h.ip, INET_NTOA(h.ip),h.hostname, h.host_descr, h.comentario, h.range_id, h.id, h.red_num, h.ip_version FROM host h WHERE h.red_num=$qred_num AND h.client_id = $qclient_id ORDER BY h.ip") or die "Can not execute statement: $dbh->errstr";

        $sth->execute() or die "$DBI::errstr";

	my $i=0;
	my $j=0;
	my $k=0;
	while ( $ip_ref = $sth->fetchrow_hashref ) {
		my $ip_version = $ip_ref->{'ip_version'};
		my $hostname = $ip_ref->{'hostname'} || "";
		my $range_id = $ip_ref->{'range_id'} || "";
		next if ! $hostname;
		my $ip_int = $ip_ref->{'ip'} || "";
		my $ip;
		if ( $ip_version eq "v4" ) {
			$ip = $ip_ref->{'INET_NTOA(h.ip)'};
		} else {
			$ip = int_to_ip("$ip_int","$ip_version");
		}
		my $host_descr = $ip_ref->{'host_descr'} || "";
		my $comentario = $ip_ref->{'comentario'} || "";
		my $id = $ip_ref->{'id'} || "";
		my $red_num = $ip_ref->{'red_num'} || "";
		push @{$values_ip{$ip_int}},"$ip","$hostname","$host_descr","$comentario","$range_id","$ip_int","$id","$red_num","$client_id","$ip_version";

	}

        $dbh->disconnect;


        return \%values_ip;
}


__DATA__
