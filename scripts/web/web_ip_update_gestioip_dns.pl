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


# web_ip_update_gestioip_dns.pl Version 3.0.0

# script para actualizar la BBDD del sistema GestioIP against the DNS


use lib '/var/www/gestioip/modules';
use GestioIP;
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
use Math::BigInt;
use POSIX;


#$ENV{'PATH'} = '/bin:/usr/bin';
#delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV'};

my $gip = GestioIP -> new();

my $VERSION="3.0.0";

my ( $disable_audit, $test, $verbose, $mail, $help, $version_arg, $community_arg,$community,$client_id,$snmp_version,$lang,$gip_config_file,$user,$with_spreadsheet,$max_sync_procs, $smallest_bm4, $smallest_bm6 );
my $ipv4="";
my $ipv6="";

GetOptions(
        "id_client=s"=>\$client_id,
        "lang=s"=>\$lang,
        "verbose!"=>\$verbose,
        "Version"=>\$version_arg,
        "user=s"=>\$user,
        "procs=s"=>\$max_sync_procs,
        "gestioip_config=s"=>\$gip_config_file,
        "with_spreadsheet!"=>\$with_spreadsheet,
        "config=s"=>\$gip_config_file,
	"x=s"=>\$smallest_bm4,
        "y=s"=>\$smallest_bm6,
        "4!"=>\$ipv4,
        "6!"=>\$ipv6,
#        "disable_audit!"=>\$disable_audit,
        "mail!"=>\$mail,
        "help!"=>\$help
) or print_help();

my $enable_audit = "1";
$enable_audit = "0" if $test || $disable_audit;

if ( $help ) { print_help(); }
if ( $version_arg ) { print_version(); }

$lang = "en" if ! $lang;

if ( ! $gip_config_file ) {
        print STDERR "Parameter \"gip_config_file\" missing\n\nexiting\n";
        exit 1;
}
if ( ! -r $gip_config_file ) {
        print STDERR "config_file $gip_config_file not readable\n\nexiting\n";
        exit 1;
}
if ( ! $client_id ) {
        print STDERR "Parameter \"client_id\" missing\n\nexiting\n";
        exit 1;
}

$client_id =~ /^(\d{1,5})$/;
$client_id = $1;


my $dir = $Bin;
$dir =~ /^(.*\/bin\/web)$/;
$dir = $1;
$dir =~ /^(.*)\/bin/;
my $base_dir=$1;

my $lockfile = $base_dir . "/var/run/" . $client_id . "_web_ip_update_gestioip_dns.lock";

no strict 'refs';
open($lockfile, '<', $0) or die("Unable to create lock file: $!\n");
use strict;

unless (flock($lockfile, LOCK_EX|LOCK_NB)) {
	print STDERR "$0 is already running. Exiting.\n";
	exit(1);
}


my $pidfile = $base_dir . "/var/run/" . $client_id . "_web_ip_update_gestioip_dns.pid";
$pidfile =~ /^(.*_web_ip_update_gestioip_dns.pid)$/;
$pidfile = $1;
open(PID,">$pidfile") or die("Unable to create pid file: $! (4)\n");
print PID $$;
close PID;

$SIG{'TERM'} = $SIG{'INT'} = \&do_term;


my ($s, $mm, $h, $d, $m, $y) = (localtime) [0,1,2,3,4,5];
$m++;
$y+=1900;
if ( $d =~ /^\d$/ ) { $d = "0$d"; }
if ( $s =~ /^\d$/ ) { $s = "0$s"; }
if ( $m =~ /^\d$/ ) { $m = "0$m"; }
if ( $mm =~ /^\d$/ ) { $mm = "0$mm"; }
my $mydatetime = "$y-$m-$d $h:$mm:$s";

$gip_config_file =~ /^(.*)\/priv/;
my $gestioip_root=$1;
my $ini_stat=$gestioip_root . "/status/ini_stat.html";
my $log=$gestioip_root . "/status/" . $client_id . "_initialize_gestioip.log";
$log =~ /^(.*_initialize_gestioip.log)$/;
$log = $1;

if ( ! -d "${gestioip_root}/status" ) {
        print STDERR "Log directory does not exists: ${gestioip_root}/status\n\exiting\n";
	unlink("$pidfile");
        exit 1;
}
open(LOG,">>$log") or die "$log: $!\n";
*STDERR = *LOG;

my $gip_version=get_version();

if ( ! $max_sync_procs ) {
	print LOG "Using default number of childs: 128\n";
	$max_sync_procs="128";
}

if ( $VERSION !~ /$gip_version/ ) {
        print LOG "\nScript and GestioIP version are not compatible\n\nGestioIP version: $gip_version - script version: $VERSION\n\n";
	unlink("$pidfile");
        exit;
}

my @config = get_config("$client_id");
my $ignorar = $config[0]->[2] || "";
my $ignore_generic_auto = $config[0]->[3] || "yes";
my $generic_dyn_host_name = $config[0]->[4] || "_NO_GENERIC_DYN_NAME_";
my $dyn_ranges_only = $config[0]->[5] || "n";
my $ping_timeout = $config[0]->[6] || "2";

my $delete_dns_hosts_down_all="yes";


my $vars_file=$base_dir . "/etc/vars/vars_update_gestioip_" . "$lang";
if ( ! -r $vars_file ) {
        print LOG "vars_file not found: $vars_file\n\exiting\n";
	unlink("$pidfile");
        exit 1;
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


$generic_dyn_host_name = "" if ! $generic_dyn_host_name;
$generic_dyn_host_name =~ s/,/|/g;


my $count_entradas_dns=0;
my $count_entradas_dns_timeout=0;
my @discover_networks=();

open (NF,"<${base_dir}/var/run/${client_id}_found_networks.tmp") or die "can't open ${base_dir}/var/run/${client_id}_found_networks.tmp\n";
while ( <NF> ) {
        push (@discover_networks,"$_") if $_ !~ /^#/ && $_ =~ /\d+/;
}
close NF;
if ( -r "${base_dir}/var/run/${client_id}_found_networks_spreadsheet.tmp" && $with_spreadsheet ) {
        open (NF,"<${base_dir}/var/run/${client_id}_found_networks_spreadsheet.tmp") or die "can't open ${base_dir}/var/run/${client_id}_found_networks_spreadsheet.tmp\n";
        while ( <NF> ) {
                push (@discover_networks,"$_") if $_ !~ /^#/ && $_ =~ /\d+/;
        }
        close NF;
}

my $new_host_count = "0";
if ( ! $discover_networks[0] ) {
	print LOG "\n--- $lang_vars{no_sync_redes} ---\n\n";
	mod_ini_stat("$new_host_count");
	unlink("$pidfile");
	exit (0);
}

my @values_ignorar;
if ( $ignorar ) {
	@values_ignorar=split(",",$ignorar);
} else {
	$values_ignorar[0]="__IGNORAR__";
}


if ( $discover_networks[0] ) {
	my $audit_type="23";
	my $audit_class="2";
	my $update_type_audit="4";
	my $event="---";
	insert_audit_auto("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file","$user") if $enable_audit == "1";
}


my @client_entries=get_client_entries("$client_id");
my $default_resolver = $client_entries[0]->[20];
my @dns_servers =("$client_entries[0]->[21]","$client_entries[0]->[22]","$client_entries[0]->[23]");


my %res_sub;
my %res;
my ($first_ip_int,$last_ip_int);
my @zone_records;
my $zone_name;

my $l=0;
foreach (@discover_networks) {

	$new_host_count = "0";

	my $red_num="$discover_networks[$l]";

	my @values_redes = ();
	my @reserved_ranges_found = ();
	if ( $dyn_ranges_only eq "yes" ) {
		 @reserved_ranges_found=check_for_reserved_range("$client_id","$red_num");
	}

	if ( ! $reserved_ranges_found[0] && $dyn_ranges_only eq "yes" ) {
		print LOG "$lang_vars{no_range_message}\n\n";
		$l++;
		next;
	}

	@values_redes = get_red("$client_id","$red_num");

	if ( ! $values_redes[0] ) {
		print LOG "$lang_vars{algo_malo_message}\n";
		$l++;
		next;
	}

	my $red = "$values_redes[0]->[0]" || "";
	my $BM = "$values_redes[0]->[1]" || "";
	my $descr = "$values_redes[0]->[2]" || "";
	my $loc_id = "$values_redes[0]->[3]" || "";
	my $ip_version = "$values_redes[0]->[7]" || "";

	if ( ! $ipv4 &&  $ip_version eq "v4" ) {
		$l++;
		next;
	} elsif ( ! $ipv6 &&  $ip_version eq "v6" ) {
		$l++;
		next;
	}

	print LOG "\n$red/$BM\n";

	if ( $ip_version eq "v4" ) {
		my $ipob = new Net::IP ("$red/$BM");
		if ( ! $ipob ) {
			$l++;
			next;
		}
		my $redint=($ipob->intip());
		$redint = Math::BigInt->new("$redint");
		$first_ip_int = $redint + 1;
		$first_ip_int = Math::BigInt->new("$first_ip_int");
		$last_ip_int = ($ipob->last_int());
		$last_ip_int = Math::BigInt->new("$last_ip_int");
		$last_ip_int = $last_ip_int - 1;
	} else {
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
		@zone_records=$gip->fetch_zone("$zone_name","$default_resolver",\@dns_servers);
	}

	if ( ! $zone_records[0] && $ip_version eq "v6" ) {
		print LOG "$lang_vars{can_not_fetch_zone_message} $zone_name\n$lang_vars{zone_transfer_allowed_message} - $lang_vars{ignorado_message}\n";
		$l++;
		next;
	}


	if ( $ip_version eq "v6" ) {
		$first_ip_int--;
		$last_ip_int++;
	}


	if ( $ip_version eq "v4" && $BM < $smallest_bm4 ) {
		print LOG "$lang_vars{smalles_bm_manage_message}: $smallest_bm4 $lang_vars{ignorado_message}\n\n";
		$l++;
		next;
	} elsif ( $ip_version eq "v6" && $BM < $smallest_bm6 ) {
		print LOG "$lang_vars{smalles_bm_manage_message}: $smallest_bm6 $lang_vars{ignorado_message}\n\n";
		$l++;
		next;
	}

	my $redob = "$red/$BM";
	my $host_loc = get_loc_from_redid("$client_id","$red_num");
	$host_loc = "---" if $host_loc eq "NULL";
	my $host_cat = "---";



	if ( $dyn_ranges_only eq "yes" ) {
		print LOG "\n($lang_vars{sync_only_rangos_message})\n\n";
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

	#check if DNS servers are alive

	my $res_dns;
	my $dns_error = "";
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

	my $test_ip_int=$first_ip_int;
	my $test_ip=$gip->int_to_ip("$client_id","$test_ip_int","$ip_version");

	my $ptr_query=$res_dns->query("$test_ip");

	if ( ! $ptr_query) {
		if ( $res_dns->errorstring eq "query timed out" ) {
			print LOG "$lang_vars{no_dns_server_message} (1):" . $res_dns->errorstring . "\n\n";
			mod_ini_stat("$new_host_count");
			$l++;
			next;
		}
	}

	my $used_nameservers = $res_dns->nameservers;

	my $all_used_nameservers = join (" ",$res_dns->nameserver());

	if ( $used_nameservers eq "0" ) {
		print LOG "$lang_vars{no_dns_server_message} (2)\n\n";
		mod_ini_stat("$new_host_count");
		$l++;
		next;
	}

	if ( $all_used_nameservers eq "127.0.0.1" && $default_resolver eq "yes" ) {
		print LOG "$lang_vars{no_answer_from_dns_message} - $lang_vars{nameserver_localhost_message}\n\n$lang_vars{exiting_message}\n\n";
		mod_ini_stat("$new_host_count");
		$l++;
		next;
	}

	my $mydatetime = time();

	my $j=0;
	my $hostname;
	my ( $ip_int, $ip_bin, $ip_ad, $pm, $res, $pid, $ip );
#	my ( %res_sub, %res, %result);
#	my ( %res, %result);
	my (%result);
	%res_sub=();
	%res=();

	my $MAX_PROCESSES=$max_sync_procs || "254";
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
	if ( $dyn_ranges_only eq "y" ) {
		@ip=get_host_range("$client_id","$first_ip_int","$last_ip_int");
		my $first_ip_int_check = $ip[0]->[0];
		my $last_ip_int_check = $ip[-1]->[0];
		if ( ! $first_ip_int || ! $last_ip_int ) {
			print LOG "$lang_vars{no_range_message}\n\n";
			$l++;
			next;
		}
	} else {
		if ( $ip_version eq "v4" ) {
			@ip=get_host("$client_id","$first_ip_int","$last_ip_int");
		} else {
			@ip=get_host_from_red_num("$client_id","$red_num");
		}
	}


	my @found_ip;
	my $p=0;
	foreach my $found_ips (@ip) {
		if ( $found_ips->[0] ) {
			$found_ips->[0]=$gip->int_to_ip("$client_id","$found_ips->[0]","$ip_version");
			$found_ip[$p]=$found_ips->[0];
		}
		$p++;
	}


	my @records;
	if ( $ip_version eq "v4" ) {
		my $l=0;
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




	my $i;
#	for (my $i = $first_ip_int; $i <= $last_ip_int; $i++) {

	foreach ( @records ) {

		next if ! $_;
		$i=$_;

		$count_entradas_dns++;
		my $exit;

		if ( $ip_version eq "v4" ) {
			$ip_ad=$gip->int_to_ip("$client_id","$i","$ip_version");
		} else {
			$ip_ad=$_;
		}


		
			##fork
			$pid = $pm->start("$ip_ad") and next;
				#child
#				$ip_ad =~ /^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})$/;
#		 		$ip_ad = $1;

				$SIG{'TERM'} = $SIG{'INT'} = \&do_term_child;
				my $p;	
				if ( $ip_version eq "v4" ) {
					$p = ping(host => "$ip_ad", timeout => 2);
				} else {
					my $command='ping6 -c 1 ' .  $ip_ad;
					my $result=$gip->ping6_system("$command","0");
					$p=1 if $result == "0";
				}

				if ( $p ) {
					$exit=0;
				} else {
					$exit=1;
				}


				my ($ptr_query,$dns_result_ip);

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


				if ( $dns_error =~ /(query timed out|no nameservers)/ ) {
					exit 5;
				} else {
					if ( $dns_result_ip && $exit == 0 ) {
						$exit=2;
					} elsif ( $dns_result_ip && $exit == 1 ) {
						$exit=3;
					} elsif ( ! $dns_result_ip && $exit == 0 ) {
						$exit=4;

					}
				}


				$pm->finish($exit); # Terminates the child process

			$i++;
	}

	$pm->wait_all_children;


	while (($pid,$ip) = each ( %res )) {
		$result{$ip}=$res_sub{$pid};
	}


	my $k = 0;
	$i=$first_ip_int;
	my $ip_ad_int="";

	foreach ( @records ) {
		if ( ! $_ ) {
			$i++;
			next;
		}

		if ( $ip_version eq "v4" ) {
			$ip_ad_int=$i;
			$ip_ad = $gip->int_to_ip("$client_id","$i","$ip_version");
		} else {
			$ip_ad=$_;
			$ip_ad_int = $gip->ip_to_int("$client_id","$ip_ad","$ip_version");
		}


		my $exit=$result{$ip_ad}; 

		print LOG "$ip_ad: "; 

		my $hostname_bbdd;
		my $cat_id="-1";
		my $int_admin="n";
		my $utype="dns";
		my $utype_id;
		my $host_descr = "NULL";
		my $comentario = "NULL";
		my $range_id="-1";
		$range_id= $ip[$k]->[10] if $ip[$k]->[10] && $ip_ad eq $ip[$k]->[0];

		if ( defined($ip[$k]->[0]) ) {
			if ( $dyn_ranges_only eq "y" && $range_id == "-1" && $ip_ad eq $ip[$k]->[0] ) {
				$k++;
				$i++;
				next;
			} elsif ( $dyn_ranges_only eq "y" && $range_id == "-1" && $ip_ad ne $ip[$k]->[0] ) {
				$i++;
				next;
			}
		} elsif ( ! defined($ip[$k]->[0]) && $dyn_ranges_only eq "y" ) {
			$i++;
			next;
		}

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


		$utype_id=get_utype_id("$utype") if ! $utype_id;

		my $ping_result=0;
		$ping_result=1 if $exit == "0" || $exit == "2" || $exit == "4";

		# Ignor IP if update type has higher priority than "dns" 
		if ( $utype ne "dns" && $utype ne "---" ) {
			if ( $hostname_bbdd || $range_id ne "-1" ) {
				$k++;
			}
			if ( $hostname_bbdd ) {
				print LOG "$hostname_bbdd - update type: $utype - $lang_vars{ignorado_message}\n";
				update_host_ping_info("$client_id","$ip_ad_int","$ping_result") if ! $test;
			} else {
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

			my ($ptr_query,$dns_result_ip);

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


			if ( $ip_ad =~ /\w+/ ) {
				$ptr_query = $res_dns->search("$ip_ad");

				if ($ptr_query) {
					foreach my $rr ($ptr_query->answer) {
						next unless $rr->type eq "PTR";
						$dns_result_ip = $rr->ptrdname;
					}
				} else {
					$dns_error = $res_dns->errorstring;
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

		if ( $hostname =~ /$generic_auto/ && $ignore_generic_auto eq "yes" ) {
			$igno_set = 1;
			$hostname="unknown";
			$igno_name="$generic_auto";
			$ignor_reason=2;
		}

		foreach (@values_ignorar) {
			if ( $hostname =~ /$_/ ) {
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


		if ( $hostname_bbdd ) {

			if ( $hostname_bbdd eq $hostname && $hostname ne "unknown" && $igno_set == "0") {
				print LOG "$lang_vars{tiene_entrada_message}: $hostname_bbdd - $lang_vars{ignorado_message}\n";
				update_host_ping_info("$client_id","$ip_ad_int","$ping_result") if ! $test;

			} else {
				if ( $delete_dns_hosts_down_all eq "yes" && $hostname eq "unknown" && $hostname_bbdd !~ /$generic_dyn_host_name/ && $ping_result == "0" ) {
					if ( $range_id eq "-1" ) {
						my $host_id=get_host_id_from_ip_int("$client_id","$ip_ad_int");
						delete_custom_host_column_entry("$client_id","$host_id");
						delete_ip("$client_id","$ip_ad_int","$ip_ad_int") if ! $test;
					} else {
						my $host_id=get_host_id_from_ip_int("$client_id","$ip_ad_int");
						delete_custom_host_column_entry("$client_id","$host_id");
						clear_ip("$client_id","$ip_ad_int","$ip_ad_int") if ! $test;
					}
					# no dns entry
					if ( $ignor_reason == "1" ) {
						print LOG "$lang_vars{entrada_borrado_message}: $hostname_bbdd ($lang_vars{no_dns_message} + $lang_vars{no_ping_message})\n";
					# hostname matches generic man auto name
					} elsif ( $ignor_reason == "2" ) {
						print LOG "$lang_vars{entrada_borrado_message}: $hostname_bbdd ($lang_vars{auto_generic_name_message} + $lang_vars{no_ping_message})\n";
					# hostname matches ignore-string
					} elsif ( $ignor_reason == "3" ) {
						print LOG "$lang_vars{entrada_borrado_message}: $hostname_bbdd ($lang_vars{tiene_man_string_no_ping_message})\n";
					} else {
						print LOG "$lang_vars{entrada_borrado_message}: $hostname_bbdd ($lang_vars{no_ping_message})\n";
					}
					$k++;
					my $audit_type="14";
					my $audit_class="1";
					my $update_type_audit="4";
					my $host_descr_audit = $host_descr;
					$host_descr_audit = "---" if $host_descr_audit eq "NULL";
					my $comentario_audit = $comentario;
					$comentario_audit = "---" if $comentario_audit eq "NULL";
					my $event="$ip_ad,$hostname_bbdd,$host_descr_audit,$host_loc,$host_cat,$comentario_audit";
					insert_audit_auto("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file","$user") if $enable_audit == "1";
					$i++;
					next;
				} elsif ( $hostname eq "unknown" && $hostname_bbdd =~ /$generic_dyn_host_name/ && $ping_result == "0" ) {
					if ( $range_id eq "-1" ) {
						my $host_id=get_host_id_from_ip_int("$client_id","$ip_ad_int");
						delete_custom_host_column_entry("$client_id","$host_id");
						delete_ip("$client_id","$ip_ad_int","$ip_ad_int") if ! $test;
					} else {
						my $host_id=get_host_id_from_ip_int("$client_id","$ip_ad_int");
						delete_custom_host_column_entry("$client_id","$host_id");
						clear_ip("$client_id","$ip_ad_int","$ip_ad_int") if ! $test;
					}
					print LOG "$lang_vars{entrada_borrado_message}: $hostname_bbdd ($lang_vars{generic_dyn_host_message} + $lang_vars{no_ping_message})\n";
					$k++;
					my $audit_type="14";
					my $audit_class="1";
					my $update_type_audit="4";
					my $host_descr_audit = $host_descr;
					$host_descr_audit = "---" if $host_descr_audit eq "NULL";
					my $comentario_audit = $comentario;
					$comentario_audit = "---" if $comentario_audit eq "NULL";
					my $event="$ip_ad,$hostname_bbdd,$host_descr_audit,$host_loc,$host_cat,$comentario_audit";
					insert_audit_auto("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file","$user") if $enable_audit == "1";
					$i++;
					next;
				} elsif ( $hostname eq "unknown" && $ping_result == "1" ) {
					# no dns entry
					if ( $ignor_reason == "1" ) {
						print LOG "$lang_vars{tiene_entrada_message}: $hostname_bbdd ($lang_vars{no_dns_message}) - $lang_vars{ignorado_message}\n";
					# generic auto name
					} elsif ( $ignor_reason == "2" ) {
						print LOG "$lang_vars{tiene_entrada_message}: $hostname_bbdd - $lang_vars{ignorado_message}\n";
					# hostname matches ignore-string
					} elsif ( $ignor_reason == "3" ) {
						print LOG "$lang_vars{tiene_entrada_message}: $hostname_bbdd - $lang_vars{ignorado_message}\n";
					# hostname matches generic-dynamic name
					} elsif ( $ignor_reason == "4" ) {
						print LOG "$lang_vars{tiene_entrada_message}: $hostname_bbdd - $lang_vars{ignorado_message}<br>\n";
					}
 
					update_host_ping_info("$client_id","$ip_ad_int","$ping_result") if ! $test;
					$k++;
					$i++;
					next;
				}

				if ( $hostname_bbdd ne $hostname ) {
						update_ip_mod("$client_id","$ip_ad_int","$hostname","$host_descr","$loc_id","$int_admin","$cat_id","$comentario","$utype_id","$mydatetime","$red_num","$ping_result") if ! $test;
						print LOG "$lang_vars{entrada_actualizada_message}: $hostname ($lang_vars{entrada_antigua_message}: $hostname_bbdd)\n";

					my $audit_type="1";
					my $audit_class="1";
					my $update_type_audit="4";
					my $host_descr_audit = $host_descr;
					$host_descr_audit = "---" if $host_descr_audit eq "NULL";
					my $comentario_audit = $comentario;
					$comentario_audit = "---" if $comentario_audit eq "NULL";
					my $event="$ip_ad,$hostname,$host_descr_audit,$host_loc,$host_cat,$comentario_audit";
					insert_audit_auto("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file","$user") if $enable_audit == "1";

				} elsif ( $ping_result == 1 && $hostname_bbdd eq "unknown" && $hostname eq "unknown" ) {
					print LOG "$lang_vars{tiene_entrada_message}: $hostname_bbdd - $lang_vars{ignorado_message}\n";
					update_host_ping_info("$client_id","$ip_ad_int","$ping_result") if ! $test;

				} else {
					update_host_ping_info("$client_id","$ip_ad_int","$ping_result") if ! $test;
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
					print LOG "$lang_vars{tiene_string_no_ping_message} - $lang_vars{ignorado_message}\n";
				} else {
					print LOG "$lang_vars{tiene_man_string_no_ping_message} - $lang_vars{ignorado_message}\n";
				}
				if ( $range_id ne "-1" ) {
					$k++;
				}
				$i++;
				next;
			}
			if ( $range_id eq "-1" ) {
				insert_ip_mod("$client_id","$ip_ad_int","$hostname","$host_descr","$loc_id","$int_admin","$cat_id","$comentario","$utype_id","$mydatetime","$red_num","$ping_result","$ip_version") if ! $test;
				$new_host_count++;
			} else {
				update_ip_mod("$client_id","$ip_ad_int","$hostname","$host_descr","$loc_id","$int_admin","$cat_id","$comentario","$utype_id","$mydatetime","$red_num","$ping_result") if ! $test;
				$k++;
			}
			if ( $exit eq 2 && $hostname eq "unknown" && $igno_set == "1") {
				if ( $ignor_reason == "2" ) {
					print LOG "$lang_vars{auto_generic_name_message} - $lang_vars{host_anadido_message}: unknown\n";
				} else {
					print LOG "$lang_vars{generic_dyn_host_message} - $lang_vars{host_anadido_message}: unknown\n";
				}
			} else {
				print LOG "$lang_vars{host_anadido_message}: $hostname\n";
			}
			my $audit_type="15";
			my $audit_class="1";
			my $update_type_audit="4";
			my $host_descr_audit = $host_descr;
			$host_descr_audit = "---" if $host_descr_audit eq "NULL";
			my $comentario_audit = $comentario;
			$comentario_audit = "---" if $comentario_audit eq "NULL";
			my $event="$ip_ad,$hostname,$host_descr_audit,$host_loc,$host_cat,$comentario_audit";
			insert_audit_auto("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file","$user") if $enable_audit == "1";
		} else {
			print LOG "$lang_vars{no_dns_message} + $lang_vars{no_ping_message} - $lang_vars{ignorado_message}\n";
			if ( $range_id ne "-1" ) {
				$k++;
			}
		} 
		$i++;
	}

	#change ini_stat.html
	mod_ini_stat("$new_host_count");

	$l++;
}

close LOG;

$count_entradas_dns ||= "0";


my $count_entradas = $count_entradas_dns;

unlink("$pidfile");

exit 0;


#######################
# Subroutiens
#######################

sub get_discover_networks {
	my ( $client_id,$red ) = @_;
	my $ip_ref;
	my @discover_networks;
	my $dbh = $gip->_mysql_connection("$gip_config_file");
        my $sth = $dbh->prepare("SELECT red, BM, red_num, loc FROM net WHERE vigilada=\"y\" AND client_id=\"$client_id\"");
        $sth->execute() or die "error while prepareing query: $DBI::errstr\n";
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
		push @discover_networks, [ @$ip_ref ];
        }
	$sth->finish();
        $dbh->disconnect;
        return @discover_networks;
}

sub check_for_reserved_range {
	my ( $client_id,$red_num ) = @_;
	my $ip_ref;
	my @ranges;
	my $dbh = $gip->_mysql_connection("$gip_config_file");
        my $sth = $dbh->prepare("SELECT red_num FROM ranges WHERE red_num = \"$red_num\" AND client_id=\"$client_id\"");
        $sth->execute() or die "error while prepareing query: $DBI::errstr\n";
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
	print "-d, --disable_audit	disable audit\n";
	print "-h, --help		help\n\n";
	exit;
}

sub print_version {
	print "\n$0 Version $VERSION\n\n";
	exit 0;
}


#sub send_mail {
#	my $mailer = Mail::Mailer->new("");
#	$mailer->open({	From	=> "$$mail_from",
#			To	=> "$$mail_destinatarios",
#			Subject	=> "Resultado update BBDD GestioIP DNS"
#		     }) or die "error while sending mail: $!\n";
#	open (LOG_MAIL,"<$log") or die "can not open log file: $!\n";
#	while (<LOG_MAIL>) {
#		print $mailer $_ if $_ !~ /$lang_vars{ignorado_message}/;
#	}
#	print $mailer "\n\n$count_entradas $lang_vars{entries_processed_message} (DNS Timeouts: $count_entradas_dns_timeout)\n";
#	print $mailer "\n\n\n\n\n\n\n\n\n--------------------------------\n\n";
#	print $mailer "$lang_vars{auto_mail_message}\n";
#	$mailer->close;
#	close LOG;
#}

#sub int_to_ip {
#        my $ip_int=shift;
#        my $ip_bin = ip_inttobin ($ip_int,4);
#        my $ip_ad = ip_bintoip ($ip_bin,4);
#        return $ip_ad;
#}

#sub resolve_ip {
#        my $ip=shift;
#        no strict 'subs';
#        my @h = gethostbyaddr(inet_aton($ip), AF_INET);
#        use strict;
#        return @h;
#}



sub insert_audit_auto {
        my ($client_id,$event_class,$event_type,$event,$update_type_audit,$vars_file,$user) = @_;
        my $mydatetime=time();
	my $dbh = $gip->_mysql_connection("$gip_config_file");
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
	my $dbh = $gip->_mysql_connection("$gip_config_file");
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
	my $dbh = $gip->_mysql_connection("$gip_config_file");
        my $qred_num = $dbh->quote( $red_num );
        my $sth = $dbh->prepare("SELECT l.loc FROM locations l, net n WHERE n.red_num = $qred_num AND n.loc = l.id AND n.client_id=\"$client_id\"") or die "Can not execute statement: $dbh->errstr";
        $sth->execute() or die "Can not execute statement: $dbh->errstr";
        $red_loc = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $red_loc;
}

sub get_host {
        my ( $client_id, $first_ip_int, $last_ip_int ) = @_;
        my @values_ip;
        my $ip_ref;
	my $dbh = $gip->_mysql_connection("$gip_config_file");
        my $qfirst_ip_int = $dbh->quote( $first_ip_int );
        my $qlast_ip_int = $dbh->quote( $last_ip_int );
        my $sth = $dbh->prepare("SELECT h.ip, h.hostname, h.host_descr, l.loc, c.cat, h.int_admin, h.comentario, ut.type, h.alive, h.last_response, h.range_id FROM host h, locations l, categorias c, update_type ut WHERE ip BETWEEN $qfirst_ip_int AND $qlast_ip_int AND h.loc = l.id AND h.categoria = c.id AND h.update_type = ut.id AND h.client_id=\"$client_id\" ORDER BY h.ip") or die "Can not execute statement: $dbh->errstr";
        $sth->execute() or die "Can not execute statement: $dbh->errstr";
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
        push @values_ip, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @values_ip;
}

sub get_host_range {
        my ( $client_id,$first_ip_int, $last_ip_int ) = @_;
        my @values_ip;
        my $ip_ref;
	my $dbh = $gip->_mysql_connection("$gip_config_file");
        my $qfirst_ip_int = $dbh->quote( $first_ip_int );
        my $qlast_ip_int = $dbh->quote( $last_ip_int );
        my $sth = $dbh->prepare("SELECT h.ip, h.hostname, h.host_descr, l.loc, c.cat, h.int_admin, h.comentario, ut.type, h.alive, h.last_response, h.range_id FROM host h, locations l, categorias c, update_type ut WHERE ip BETWEEN $qfirst_ip_int AND $qlast_ip_int AND h.loc = l.id AND h.categoria = c.id AND h.update_type = ut.id AND range_id != '-1' AND h.client_id=\"$client_id\" ORDER BY h.ip") or die "Can not execute statement: $dbh->errstr";
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
	my $dbh = $gip->_mysql_connection("$gip_config_file");
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
	my $dbh = $gip->_mysql_connection("$gip_config_file");
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
        my ( $client_id,$ip_int, $ping_result) = @_;
	my $dbh = $gip->_mysql_connection("$gip_config_file");
        my $qip_int = $dbh->quote( $ip_int );
        my $qmydatetime = $dbh->quote( time() );
        my $alive = $dbh->quote( $ping_result );
        my $sth;
        $sth = $dbh->prepare("UPDATE host SET alive=$alive, last_response=$qmydatetime WHERE ip=$qip_int AND client_id=\"$client_id\"") or die "Can not execute statement: $dbh->errstr";
        $sth->execute() or die "Can not execute statement: $dbh->errstr";
        $sth->finish();
        $dbh->disconnect;
}

sub delete_ip {
        my ( $client_id,$first_ip_int, $last_ip_int ) = @_;
	my $dbh = $gip->_mysql_connection("$gip_config_file");
        my $qfirst_ip_int = $dbh->quote( $first_ip_int );
        my $qlast_ip_int = $dbh->quote( $last_ip_int );
        my $sth = $dbh->prepare("DELETE FROM host WHERE ip BETWEEN $qfirst_ip_int AND $qlast_ip_int AND client_id=\"$client_id\""
                                ) or die "Can not execute statement: $dbh->errstr";
        $sth->execute() or die "Can not execute statement: $dbh->errstr";
        $sth->finish();
        $dbh->disconnect;
}

sub clear_ip {
        my ( $client_id,$first_ip_int, $last_ip_int ) = @_;
	my $dbh = $gip->_mysql_connection("$gip_config_file");
        my $qfirst_ip_int = $dbh->quote( $first_ip_int );
        my $qlast_ip_int = $dbh->quote( $last_ip_int );

        my $sth = $dbh->prepare("UPDATE host SET hostname='', host_descr='', int_admin='n', alive='', last_response='' WHERE ip BETWEEN $qfirst_ip_int AND $qlast_ip_int AND client_id=\"$client_id\""
                                ) or die "Can not execute statement: $dbh->errstr";
        $sth->execute() or die "Can not execute statement: $dbh->errstr";
        $sth->finish();
        $dbh->disconnect;
}

sub insert_ip_mod {
        my ( $client_id,$ip_int, $hostname, $host_descr, $loc, $int_admin, $cat, $comentario, $update_type, $mydatetime, $red_num, $alive, $ip_version  ) = @_;
	my $dbh = $gip->_mysql_connection("$gip_config_file");
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
                $sth = $dbh->prepare("INSERT INTO host (ip,hostname,host_descr,loc,red_num,int_admin,categoria,comentario,update_type,last_update,alive,last_response,ip_version,client_id) VALUES ($qip_int,$qhostname,$qhost_descr,$qloc,$qred_num,$qint_admin,$qcat,$qcomentario,$qupdate_type,$qmydatetime,$qalive,$qlast_response,$qip_version,$qclient_id)"
                                ) or die "Can not execute statement: $dbh->errstr";
        } else {
                $sth = $dbh->prepare("INSERT INTO host (ip,hostname,host_descr,loc,red_num,int_admin,categoria,comentario,update_type,last_update,ip_version,client_id) VALUES ($qip_int,$qhostname,$qhost_descr,$qloc,$qred_num,$qint_admin,$qcat,$qcomentario,$qupdate_type,$qmydatetime,$qip_version,$qclient_id)"
                                ) or die "Can not execute statement: $dbh->errstr";
        }
        $sth->execute() or die "Can not execute statement: $dbh->errstr";
        $sth->finish();
        $dbh->disconnect;
}

sub update_ip_mod {
        my ( $client_id,$ip_int, $hostname, $host_descr, $loc, $int_admin, $cat, $comentario, $update_type, $mydatetime, $red_num, $alive ) = @_;
	my $dbh = $gip->_mysql_connection("$gip_config_file");
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


#sub get_all_range_ids {
#	my ( $client_id ) = @_;
#	my $ip_ref;
#	my @range_ids;
#        my $dbh = mysql_connection();
#        my $sth = $dbh->prepare("SELECT red, BM, red_num, loc FROM net WHERE vigilada=\"y\" AND client_id=\"$client_id\"");
#        $sth->execute() or print "error while prepareing query: $DBI::errstr\n";
#        while ( $ip_ref = $sth->fetchrow_arrayref ) {
#        push @range_ids, [ @$ip_ref ];
#        }
#	$sth->finish();
#        $dbh->disconnect;
#        return @range_ids;
#}

sub count_clients {
        my $val;
	my $dbh = $gip->_mysql_connection("$gip_config_file");
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
	my $dbh = $gip->_mysql_connection("$gip_config_file");
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
	my $dbh = $gip->_mysql_connection("$gip_config_file");
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
	my $dbh = $gip->_mysql_connection("$gip_config_file");
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
	my $dbh = $gip->_mysql_connection("$gip_config_file");
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
	my $dbh = $gip->_mysql_connection("$gip_config_file");
        my $sth = $dbh->prepare("SELECT version FROM global_config");
        $sth->execute() or  die "Can not execute statement:$sth->errstr";
        $val = $sth->fetchrow_array;
        $sth->finish();
        $dbh->disconnect;
        return $val;
}

sub get_config {
        my ( $client_id ) = @_;
        my @values_config;
        my $ip_ref;
        my $dbh = $gip->_mysql_connection("$gip_config_file");
        my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("SELECT smallest_bm,max_sinc_procs,ignorar,ignore_generic_auto,generic_dyn_host_name,dyn_ranges_only,ping_timeout FROM config WHERE client_id = $qclient_id") or die ("Can not execute statement:<p>$DBI::errstr");
        $sth->execute() or die ("Can not execute statement:<p>$DBI::errstr");
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
        push @values_config, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @values_config;
}


sub mod_ini_stat {
        my ($new_host_count) = @_;
	my $new = "./ini_stat.html.tmp.$$";
	open(OLD, "< $ini_stat") or die "can't open $ini_stat: $!";
	open(NEW, "> $new") or die "can't open $new: $!";

	while (<OLD>) {
		if ( $_ =~ /$lang_vars{hosts_found_message}: .{0,3}\d+/ ) {
			$_ =~ /$lang_vars{hosts_found_message}: .{0,3}(\d+)/;
			my $old_host_count = $1;
			my $host_count = $old_host_count + $new_host_count;
			s/$lang_vars{hosts_found_message}: .{0,3}\d+(<\/b>)*/$lang_vars{hosts_found_message}: <b>${host_count}<\/b>/;
		}
		(print NEW $_) or die "can't write to $new: $!";
	}

	close(OLD) or die "can't close $ini_stat: $!";
	close(NEW) or die "can't close $new: $!";

	rename($new, $ini_stat) or die "can't rename $new to $ini_stat: $!";
}

sub do_term {
        print LOG "Got TERM Signal - Killing sub processes and exiting\n";
        kill_childs();
        close LOG;
        unlink("$pidfile");
        mod_ini_stat("$new_host_count");
        exit 3;
}

sub kill_childs {
        kill TERM => keys %res;
}

sub do_term_child {
        exit 0;
}

sub get_host_id_from_ip_int {
        my ( $client_id,$ip_int ) = @_;
        my $val;
        my $dbh = $gip->_mysql_connection("$gip_config_file");
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
        my ( $client_id,$host_id ) = @_;
        my $dbh = $gip->_mysql_connection("$gip_config_file");
        my $qhost_id = $dbh->quote( $host_id );
        my $qclient_id = $dbh->quote( $client_id );
        my $sth;
        $sth = $dbh->prepare("DELETE FROM custom_host_column_entries WHERE host_id = $qhost_id AND client_id = $qclient_id") or die "Can not execute statement: $dbh->errstr";
        $sth->execute() or die "Can not execute statement:$sth->errstr";
        $sth->finish();
        $dbh->disconnect;
}

sub get_host_from_red_num {
        my ( $client_id, $red_num ) = @_;
        my @values_ip;
        my $ip_ref;
        my $dbh = $gip->_mysql_connection("$gip_config_file");
        my $qred_num = $dbh->quote( $red_num );
        my $qclient_id = $dbh->quote( $client_id );
        my $sth = $dbh->prepare("SELECT h.ip, h.hostname, h.host_descr, l.loc, c.cat, h.int_admin, h.comentario, ut.type, h.alive, h.last_response, h.range_id, h.id FROM host h, locations l, categorias c, update_type ut WHERE h.red_num=$qred_num AND h.loc = l.id AND h.categoria = c.id AND h.update_type = ut.id AND h.client_id = $qclient_id ORDER BY h.ip"
                ) or die "Can not execute statement:<p>$DBI::errstr";
        $sth->execute() or die "Can not execute statement:<p>$DBI::errstr";
        while ( $ip_ref = $sth->fetchrow_arrayref ) {
                push @values_ip, [ @$ip_ref ];
        }
        $dbh->disconnect;
        return @values_ip;
}




__DATA__
