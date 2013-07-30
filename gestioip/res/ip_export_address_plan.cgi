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
use Net::IP;
use Net::IP qw(:PROC);
use lib '../modules';
use GestioIP;
use Cwd;
use File::Find;
use File::stat;


my $daten=<STDIN>;
my $gip = GestioIP -> new();
my %daten=$gip->preparer($daten);

my $server_proto=$gip->get_server_proto();
my $base_uri = $gip->get_base_uri();

my $lang = $daten{'lang'} || "";
my ($lang_vars,$vars_file,$entries_per_page);
if ( $daten{'entries_per_page'} ) {
        $daten{'entries_per_page'} = "500" if $daten{'entries_per_page'} !~ /^\d{1,3}$/;
        ($lang_vars,$vars_file,$entries_per_page)=$gip->get_lang("$daten{'entries_per_page'}","$lang");
} else {
        ($lang_vars,$vars_file,$entries_per_page)=$gip->get_lang("","$lang");
}

my $client_id = $daten{'client_id'} || "";
if ( $client_id !~ /^\d{1,4}$/ ) {
	$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{ipv6_address_plan_message}","$vars_file");
	$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (1) $client_id");
}

my $ip_version = "v6";

my $anz_redes=$daten{'anz_redes'};

my @global_config = $gip->get_global_config("$client_id");
my $global_ip_version=$global_config[0]->[5] || "v4";
my $ip_version_ele="";


$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{ipv6_address_plan_message}","$vars_file");

my $align="align=\"right\"";
my $align1="";
my $ori="left";
my $rtl_helper="<font color=\"white\">x</font>";
if ( $vars_file =~ /vars_he$/ ) {
	$align="align=\"left\"";
	$align1="align=\"right\"";
	$ori="right";
}


$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (2)") if $ip_version !~ /^(v4|v6)$/; 
$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (3)") if $anz_redes !~ /^\d{1,5}/; 

my @new_redes_detail=();

for (my $l=0; $l <= $anz_redes; $l++) {
	if ( ! $daten{"red_$l"} ) {
		next;
	}
	$new_redes_detail[$l]->[0] = ip_expand_address($daten{"red_$l"},6);
	$new_redes_detail[$l]->[1] = $daten{"BM_$l"};
	$new_redes_detail[$l]->[2] = $daten{"descr_$l"} || "";
	$new_redes_detail[$l]->[3] = $daten{"loc_id_$l"} || "";
	$new_redes_detail[$l]->[4] = $daten{"cat_id_$l"} || "";
	$new_redes_detail[$l]->[5] = $daten{"comentario_$l"} || "";
	$new_redes_detail[$l]->[6] = $daten{"sinc_$l"} || "n";
	$new_redes_detail[$l]->[7] = $daten{"loc_$l"} || "";
	$new_redes_detail[$l]->[8] = $daten{"cat_$l"} || "";
	$new_redes_detail[$l]->[9] = $daten{"create_$l"} || "";
	$new_redes_detail[$l]->[10] = $daten{"red4_$l"} || "";
	$new_redes_detail[$l]->[11] = $daten{"BM4_$l"} || "";
}


my $rootnet_val="0";
my $m = "0";
my $n = "1";
my $event;
my @csv_strings;
$csv_strings[0]="$$lang_vars{ipv4_network_message},BM,$$lang_vars{translated_ipv6_address_message},$$lang_vars{prefix_length_message},$$lang_vars{description_message},$$lang_vars{loc_message},$$lang_vars{cat_message},$$lang_vars{comentario_message}\n";


foreach my $ele (@new_redes_detail) {
if ( ! $ele || ! $new_redes_detail[$m]->[0] ) { next; }

	my $red_nuevo=$new_redes_detail[$m]->[0];
	my $BM_nuevo=$new_redes_detail[$m]->[1];
	my $descr_nuevo = $new_redes_detail[$m]->[2] || "";
	$descr_nuevo="" if $descr_nuevo eq "NULL";
	my $loc_id_nuevo = $new_redes_detail[$m]->[3] || "-1";
	my $cat_id_nuevo = $new_redes_detail[$m]->[4] || "-1";
	my $comentario_nuevo = $new_redes_detail[$m]->[5] || "";
	$comentario_nuevo="" if $comentario_nuevo eq "NULL";
	my $vigilada_nuevo = $new_redes_detail[$m]->[6] || "n";
	my $loc_nuevo = $new_redes_detail[$m]->[7] || "";
	my $cat_nuevo = $new_redes_detail[$m]->[8] || "";
	my $red4 = $new_redes_detail[$m]->[10] || "";
	my $BM4 = $new_redes_detail[$m]->[11] || "";

	$csv_strings[$n++]="$red4,$BM4,$red_nuevo,$BM_nuevo,$descr_nuevo,$loc_nuevo,$cat_nuevo,$comentario_nuevo\n";

	$m++;
}


my $export_dir = getcwd;
$export_dir =~ s/res.*/export/;

$export_dir =~ /^([\w.\/]+)$/;

# delete old files
my $found_file;
sub findfile {
        $found_file = $File::Find::name if ! -d;
        if ( $found_file ) {
#                $found_file =~ /^([\w.\/]+)$/;
		$found_file =~ /^(.*)$/;
                $found_file = $1;
                my $filetime = stat($found_file)->mtime;
                my $checktime=time();
                $checktime = $checktime - 3600;
                if ( $filetime < $checktime ) {
                        unlink($found_file);
                }
        }
}

find( {wanted=>\&findfile,no_chdir=>1},$export_dir);

my $mydatetime=time();
my $csv_file_name="$mydatetime.plan_from_block.csv";
my $csv_file="../export/$csv_file_name";

open(EXPORT,">$csv_file") or $gip->print_error("$client_id","$!");

foreach ( @csv_strings ) {
	print EXPORT "$_";
}

close EXPORT;

print "<p><b style=\"float: $ori\">$$lang_vars{export_successful_message}</b><br><p>\n";
print "<p><span style=\"float: $ori\"><a href=\"$server_proto://$base_uri/export/$csv_file_name\">$$lang_vars{download_csv_file}</a></span><p>\n";

$gip->print_end("$client_id","$vars_file");
