#!/usr/bin/perl -T -w

# Copyright (C) 2013 Marc Uebel

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
use Cwd;
use File::Find;
use File::stat;
use lib '../modules';
use GestioIP;

my $daten=<STDIN>;
my $gip = GestioIP -> new();
my %daten=$gip->preparer($daten);

my $base_uri = $gip->get_base_uri();
my $server_proto=$gip->get_server_proto();

my $lang="";
my ($lang_vars,$vars_file)=$gip->get_lang("","$lang");

my $export_result = $daten{export_result};
my $client_id = $daten{client_id};

my @export_result=split(" ",$export_result);

$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{export_data_message}","$vars_file");

my $align="align=\"right\"";
my $align1="";
my $ori="left";
my $rtl_helper="<font color=\"white\">x</font>";
if ( $vars_file =~ /vars_he$/ ) {
        $align="align=\"left\"";
        $align1="align=\"right\"";
        $ori="right";
}


unshift(@export_result, "IP,ping status");


print "<p><br>\n";

my $export_dir = getcwd;
$export_dir =~ s/res.*/export/;
$export_dir =~ /^([\w.\/]+)$/;

# delete old files
my $found_file;
sub findfile {
	$found_file = $File::Find::name if ! -d;
	if ( $found_file ) {
		$found_file =~ /^([\w.\/]+)$/;
		$found_file = $1;
		my $filetime = stat($found_file)->mtime;
		my $checktime=time();
		$checktime = $checktime - 3600;
		if ( $filetime < $checktime ) {
			unlink($found_file) if $found_file =~ /ping_stat/;
		}
	}
}

find( {wanted=>\&findfile,no_chdir=>1},$export_dir);

my $mydatetime=time();
my $csv_file_name="$mydatetime.ping_stat.csv";
my $csv_file="../export/$csv_file_name";

open(EXPORT,">$csv_file") or $gip->print_error("$client_id","$!");


foreach ( @export_result ) {
	$_=~s/,0$/,down/;
	$_=~s/,1$/,up/;
        print EXPORT "$_\n";
}

close EXPORT;

print "<p><b style=\"float: $ori\">$$lang_vars{export_successful_message}</b><br><p>\n";
print "<p><span style=\"float: $ori\"><a href=\"$server_proto://$base_uri/export/$csv_file_name\">$$lang_vars{download_csv_file}</a></span><p>\n";


$gip->print_end("$client_id","$vars_file","go_to_top");
