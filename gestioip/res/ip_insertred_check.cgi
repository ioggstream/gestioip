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


my $daten=<STDIN>;
my $gip = GestioIP -> new();
my %daten=$gip->preparer($daten);

my $lang = $daten{'lang'} || "";
my ($lang_vars,$vars_file)=$gip->get_lang("","$lang");
my $server_proto=$gip->get_server_proto();

my $base_uri = $gip->get_base_uri();

my $client_id = $daten{'client_id'} || $gip->get_first_client_id();
my $ip_version=$daten{'ip_version'} || "v4";

my @values_locations=$gip->get_loc("$client_id");
my @values_cat_net=$gip->get_cat_net("$client_id");

my $descr = $daten{'descr'} || "";
my $loc = $daten{'loc'} || "NULL";
my $cat_net = $daten{'cat_red'} || "NULL";
my $comentario = $daten{'comentario'} || "NULL";
my $vigilada = $daten{'vigilada'} || "n";

my $rootnet = $daten{'rootnet'} || "n";
my $rootnet_val = "0";
$rootnet_val = "1" if $rootnet eq "y";


$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{crear_red_message}","$vars_file");

$gip->print_error("$client_id","$$lang_vars{formato_malo_message}") if $ip_version !~ /(v4|v6)/;

my ($message,$intro_message,$ip_ad,$BM,$bitmasks,$anz_BM,$BM_freerange);

my @bitmasks;
if ( $daten{add_type} eq "multiple_different_bm" ) {
	$ip_ad = $daten{'red'}  || $gip->print_error("$client_id","$$lang_vars{introduce_red_id_message}");
	$bitmasks=$daten{bitmasks} || $gip->print_error("$client_id","$$lang_vars{no_bitmasks_message}");
	$bitmasks =~ s/[\r\f\n\t\s]//;
	$BM_freerange=$daten{BM_freerange};
	$intro_message="$$lang_vars{first_net_message}: $ip_ad, $$lang_vars{bitmasks_message}: $bitmasks<p>\n";
	if ( $bitmasks !~ /^(\/\d{1,3}){2,}$/ ) {
		$gip->print_error("$client_id","$$lang_vars{bitmasks_malo_message}<p><br>\n");
	}
	$bitmasks =~ s/^\///;
	@bitmasks=split('/',$bitmasks);
	my $anz_bitmasks=@bitmasks;
	$gip->print_error("$client_id","$$lang_vars{max_create_50_message}") if $anz_bitmasks > 50;

} elsif ( $daten{add_type} eq "multiple_same_bm" ) {
	$ip_ad = $daten{'red'}  || $gip->print_error("$client_id","$$lang_vars{introduce_red_id_message}");
	$bitmasks=$daten{bitmasks};
	$BM=$daten{BM};
	$anz_BM=$daten{anz_BM};
	$intro_message="<p>$$lang_vars{first_net_message}:$ip_ad/$BM, $$lang_vars{number_of_networks_message}: $anz_BM<p>\n";
} else {
	$gip->print_error("$client_id","$$lang_vars{formato_malo_message}");
}

if ( $ip_version eq "v4" ) {
	if ( $ip_ad =~ /^\d{6,12}$/ ) {
		$ip_ad = $gip->int_to_ip("$client_id","$ip_ad","$ip_version");
	}
	if ( $ip_ad !~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/ ) {
		print "$$lang_vars{ip_invalido_message}: $ip_ad<p><br>\n";
		$gip->print_end("$client_id","$vars_file");
		exit 1;
	}
} else {
	my $valid_v6 = $gip->check_valid_ipv6("$ip_ad") || "0";
	$gip->print_error("$client_id","$$lang_vars{no_valid_ipv6_address_message} <b>$ip_ad</b>") if $valid_v6 != "1";
	$ip_ad = ip_expand_address ($ip_ad,6);
}


my @overlap_redes=$gip->get_overlap_red("$ip_version","$client_id");
my $first_ip_new="";
$first_ip_new = Math::BigInt->new("$first_ip_new");
my $bm_mess;
my $i="0";
my ( $redob, $new_redes);
my @new_redes;

if ( @bitmasks) {

### multiple_different_bm

	print "<p><span class=\"create_red_intro_message_text\">$intro_message</span><p>\n";
	foreach (@bitmasks) {
		my $BM_actual = $_;
		my $overlap_check_red;
		my $overlap_check_BM;
		if ( $i == 0 ) {
			$redob="$ip_ad/$_";
			$overlap_check_red=$ip_ad;
			$overlap_check_BM=$BM_actual;
		} else {
			$redob="$first_ip_new/$_";
			$overlap_check_red=$first_ip_new;
			$overlap_check_BM=$BM_actual;
		}
		my $ipob = new Net::IP ($redob);
		if ( ! $ipob ) {
			if ( $message ) {
				$bm_mess="$bm_mess/<font color=\"red\"><u>$bitmasks[$i]</u></font>" if ( $bitmasks[$i] );
				print "<b>$$lang_vars{error_red_invalido_message}</b><p>$message<font color=\"red\">$redob - NOT OK</font><p>$bm_mess - $$lang_vars{invalid_bitmask_message}<br><p>";
				print "<FORM><INPUT TYPE=\"BUTTON\" VALUE=\"$$lang_vars{atras_message}\" ONCLICK=\"history.go(-1)\" class=\"error_back_link\"></FORM>\n";
			} else {
				$bm_mess="$bm_mess/<font color=\"red\"><u>$bitmasks[$i]</u></font>" if ( $bitmasks[$i] );
				print "<b>$$lang_vars{error_red_invalido_message}</b><p><font color=\"red\">$redob - NOT OK</font><p>$bm_mess - $$lang_vars{invalid_bitmask_message}<br><p><br>";
				print "<FORM><INPUT TYPE=\"BUTTON\" VALUE=\"$$lang_vars{atras_message}\" ONCLICK=\"history.go(-1)\" class=\"error_back_link\"></FORM>\n";
			}
			$gip->print_end("$client_id","$vars_file");
			exit 1;
		}

                if ( $BM_actual == "31" ) {
                        if ( $message ) {
                                print "$message<font color=\"red\">$redob - NOT OK</font><p><b>ERROR</b><p>$$lang_vars{no_bm_31_message}: $redob<br>";
                        } else {
                                print "<font color=\"red\">$redob - NOT OK</font><p><b>ERROR</b><p>$$lang_vars{no_bm_31_message}: $redob<br>";
                        }
			$gip->print_end("$client_id","$vars_file");
                        exit 1;
                }

		
		my $last_ip_int = ($ipob->last_int());
		$last_ip_int = Math::BigInt->new("$last_ip_int");	
		my $first_ip_int="";
		$first_ip_int = Math::BigInt->new("$first_ip_int");
		$first_ip_int = $last_ip_int + 1;
		$first_ip_new=$gip->int_to_ip("$client_id","$first_ip_int","$ip_version");

		$rootnet_val=1 if $ip_version eq "v6" && $BM_actual < 64;

		if ( $rootnet_val == 0 ) {
			
			my @overlap_found = $gip->find_overlap_redes("$client_id","$overlap_check_red","$overlap_check_BM",\@overlap_redes,"$ip_version","$vars_file","","","1");
			if ( $overlap_found[0] ) {
				if ( $overlap_found[0] ne "$ip_ad" ) {
					print "<p><b>$$lang_vars{overlap_detected_message}</b><p>\n";
					if ( $message ) {
						print "$message<font color=\"red\">$redob - NOT OK</font></b><p>$redob $$lang_vars{overlaps_con_message} $overlap_found[0]<p><br><p>";
						print "<FORM><INPUT TYPE=\"BUTTON\" VALUE=\"$$lang_vars{atras_message}\" ONCLICK=\"history.go(-1)\" class=\"error_back_link\"></FORM>\n";
					} else {
						print "<font color=\"red\">$redob - NOT OK</font></b><p>$redob $$lang_vars{overlaps_con_message} $overlap_found[0]<p><br><p>";
						print "<FORM><INPUT TYPE=\"BUTTON\" VALUE=\"$$lang_vars{atras_message}\" ONCLICK=\"history.go(-1)\" class=\"error_back_link\"></FORM>\n";
					}
					$gip->print_end("$client_id","$vars_file");
					exit 1;
				}
			}
		} else {
			my $ignore_rootnet="1";
			if ( $rootnet_val == 1 ) {
				$ignore_rootnet="0";
			}

			$overlap_check_red = ip_expand_address ($overlap_check_red,6) if $ip_version eq "v6";
			my $red_check=$gip->check_red_exists("$client_id","$overlap_check_red","$BM_actual","$ignore_rootnet");
			if ( $red_check ) {
				if ( $message ) {
					print "$message";
				}
				print "<font color=\"red\">$redob - NOT OK</font></b><p>$redob $$lang_vars{red_exists_message}<p><br><p>";
				print "<FORM><INPUT TYPE=\"BUTTON\" VALUE=\"$$lang_vars{atras_message}\" ONCLICK=\"history.go(-1)\" class=\"error_back_link\"></FORM>\n";
				$gip->print_end("$client_id","$vars_file");
				exit 1;
			}
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
		$new_redes[$i] = $redob;
		if ( $new_redes ) {
			$new_redes="$new_redes" . "-" . "$redob";
		} else {
			$new_redes="$redob";
		}
		$i++;
	}




} elsif ( $BM ) {

## multiple redes same BM

	print "<p><span class=\"create_red_intro_message_text\">$intro_message</span><p>\n";
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
				print "$message<p><b>$redob - NOT OK</b><p><b>$$lang_vars{red_invalido_message}</b><p><br><p>";
				print "<FORM><INPUT TYPE=\"BUTTON\" VALUE=\"$$lang_vars{atras_message}\" ONCLICK=\"history.go(-1)\" class=\"error_back_link\"></FORM>\n";
			} else {
				print "<p><b>$redob - NOT OK</b><p><b>$$lang_vars{red_invalido_message}</b><p><br><p>";
				print "<FORM><INPUT TYPE=\"BUTTON\" VALUE=\"$$lang_vars{atras_message}\" ONCLICK=\"history.go(-1)\" class=\"error_back_link\"></FORM>\n";
			}
			$gip->print_end("$client_id","$vars_file");
			exit 1;
		}
		
		my $last_ip_int = ($ipob->last_int());
		$last_ip_int = Math::BigInt->new("$last_ip_int");
		my $first_ip_int = $last_ip_int + 1;
		$first_ip_new=$gip->int_to_ip("$client_id","$first_ip_int","$ip_version");

		$rootnet_val=1 if $ip_version eq "v6" && $BM < 64;

		if ( $rootnet_val == 0 ) {
			my @overlap_found = $gip->find_overlap_redes("$client_id","$overlap_check_red","$BM",\@overlap_redes,"$ip_version","$vars_file");
			if ( $overlap_found[0] ) {
				if ( $overlap_found[0] ne "$ip_ad" ) {
					print "<p><b>$$lang_vars{overlap_detected_message}</b><p>\n";
					if ( $message ) {
						print "$message<font color=\"red\">$redob - NOT OK</font></b><p>$redob $$lang_vars{overlaps_con_message} $overlap_found[0]<p><br><p>";
						print "<FORM><INPUT TYPE=\"BUTTON\" VALUE=\"$$lang_vars{atras_message}\" ONCLICK=\"history.go(-1)\" class=\"error_back_link\"></FORM>\n";
					} else {
						print "<font color=\"red\">$redob - NOT OK</font></b><p>$redob $$lang_vars{overlaps_con_message} $overlap_found[0]<p><br><p>";
						print "<FORM><INPUT TYPE=\"BUTTON\" VALUE=\"$$lang_vars{atras_message}\" ONCLICK=\"history.go(-1)\" class=\"error_back_link\"></FORM>\n";
					}
					$gip->print_end("$client_id","$vars_file");
					exit 1;
				}
			}
		} else {
			my $ignore_rootnet="1";
			if ( $rootnet_val == 1 ) {
				$ignore_rootnet="0";
			}

			$overlap_check_red = ip_expand_address ($overlap_check_red,6) if $ip_version eq "v6";
			my $red_check=$gip->check_red_exists("$client_id","$overlap_check_red","$BM","$ignore_rootnet");
			if ( $red_check ) {
				if ( $message ) {
					print "$message";
				}
				print "<font color=\"red\">$redob - NOT OK</font></b><p>$redob $$lang_vars{red_exists_message}<p><br><p>";
				print "<FORM><INPUT TYPE=\"BUTTON\" VALUE=\"$$lang_vars{atras_message}\" ONCLICK=\"history.go(-1)\" class=\"error_back_link\"></FORM>\n";
				$gip->print_end("$client_id","$vars_file");
				exit 1;
			}
		}

		if ( $message ) {
			$message = $message . "$redob - OK<br>";
		} else {
			$message = "$redob - OK<br>";
		}
		$new_redes[$i] = $redob;
		if ( $new_redes ) {
			$new_redes="$new_redes" . "-" . "$redob";
		} else {
			$new_redes="$redob";
		}
		
	}
}



print "<p><br>$$lang_vars{edit_network_parameters_message} \"$$lang_vars{submit_message}\" $$lang_vars{pulsar_message}<br><p><br>\n";
print "<form name=\"insertred\" method=\"POST\" action=\"$server_proto://$base_uri/res/ip_insertred.cgi\">\n";
print "<table border=\"0\" cellpadding=\"1\">\n";
print "<tr><td><b>$$lang_vars{redes_message}</b></td><td><b>  $$lang_vars{description_message}</b></td><td><b>  $$lang_vars{loc_message}</b></td><td><b>$$lang_vars{cat_message}</b></td><td><b>$$lang_vars{comentario_message}</b></td><td><b>$$lang_vars{sinc_message}</b></td><td></td></tr>\n";

my $k = "0";
foreach (@new_redes) {
        my ($form_red, $form_BM) = split("/",$_) if $_;
        next if ! $form_red;
	$form_red = ip_expand_address ($form_red, 6) if $ip_version eq "v6";
        my $color = "white";

        print "<tr bgcolor=\"$color\" valign=\"top\"><td><b>$form_red/$form_BM &nbsp;</b></td>";
        print "<td><i><input type=\"text\" size=\"25\" name=\"descr_$k\" value=\"\" maxlength=\"100\"></i></td><td><select name=\"loc_$k\" size=\"1\">";
        print "<option></option>";

        my $j=0;
        foreach (@values_locations) {
                if ($values_locations[$j]->[0] eq "NULL") {
                        $j++;
                        next;
                }
		if ($values_locations[$j]->[0] eq "$loc" ) { 
			print "<option selected>$values_locations[$j]->[0]</option>";
                        $j++;
                        next;
                }
                print "<option>$values_locations[$j]->[0]</option>";
                $j++;
        }
        print "</td><td>";
        print "<select name=\"cat_net_$k\" size=\"1\">";
        print "<option></option>";
        $j=0;
        foreach (@values_cat_net) {
                if ($values_cat_net[$j]->[0] eq "NULL") {
                        $j++;
                        next;
                }
		if ($values_cat_net[$j]->[0] eq "$cat_net" ) { 
			print "<option selected>$values_cat_net[$j]->[0]</option>";
                        $j++;
                        next;
                }
                print "<option>$values_cat_net[$j]->[0]</option>";
                $j++;
        }

        print "</select></td><input name=\"BM_$k\" type=\"hidden\" value=\"$form_BM\"><input name=\"red_$k\" type=\"hidden\" value=\"$form_red\">";
        print "<td><textarea name=\"comentario_$k\" cols=\"30\" rows=\"1\" wrap=\"physical\" maxlength=\"500\"></textarea>";
        print "</td>";

        print "<td><input type=\"checkbox\" name=\"vigilada_$k\" value=\"y\"></td></tr>\n";
        $k++;
}
print "</table>\n";
print "<p><br><input name=\"new_redes\" type=\"hidden\" value=\"$new_redes\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input name=\"ip_version\" type=\"hidden\" value=\"$ip_version\"><input name=\"rootnet\" type=\"hidden\" value=\"$rootnet\"><input type=\"submit\" value=\"$$lang_vars{submit_message}\" name=\"B2\" class=\"input_link_w\">\n";
print "</form>\n";



$gip->print_end("$client_id","$vars_file");
