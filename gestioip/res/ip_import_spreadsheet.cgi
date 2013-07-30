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
use Net::IP qw(:PROC);
use Spreadsheet::ParseExcel;
use Encode qw(encode decode); 
use Cwd;

my $daten=<STDIN>;
my $gip = GestioIP -> new();
my %daten=$gip->preparer($daten);

my $lang = $daten{'lang'} || "";
my ($lang_vars,$vars_file)=$gip->get_lang("","$lang");

my $client_id = $daten{'client_id'} || $gip->get_first_client_id();
if ( $client_id !~ /^\d{1,4}$/ ) {
	$client_id = 1;
	$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{redes_message}","$vars_file");
	$gip->print_error("$client_id","$$lang_vars{formato_malo_message}");
}

my $ip_version_ele=$gip->get_ip_version_ele() || "v4";
my $ip_version = $daten{'ip_version'} || "v4";

my $found_networks_file="/usr/share/gestioip/var/run/${client_id}_found_networks_spreadsheet.tmp";

$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{redes_dispo_message}","$vars_file");

my $align="align=\"right\"";
my $align1="";
my $ori="left";
my $rtl_helper="<font color=\"white\">x</font>";
if ( $vars_file =~ /vars_he$/ ) {
	$align="align=\"left\"";
	$align1="align=\"right\"";
	$ori="right";
}


my $module = "Spreadsheet::ParseExcel";
my $module_check=$gip->check_module("$module") || "0";
$gip->print_error("$client_id","$$lang_vars{no_spreadsheet_support}") if $module_check != "1";

my @config = $gip->get_config("$client_id");
my $smallest_bm = $config[0]->[0] || "22";
my $smallest_bm6 = $config[0]->[7] || "64";

my $import_dir = getcwd;
$import_dir =~ s/res.*/import/;

$gip->print_error("$client_id","$$lang_vars{no_spreadsheet_message}") if $daten{'spreadsheet'} !~ /.+/;
my $spreadsheet = $daten{'spreadsheet'};
my $excel_file_name="../import/$spreadsheet";
if ( ! -e $excel_file_name ) {
        $gip->print_error("$client_id","$$lang_vars{no_spreadsheet_message} \"$spreadsheet\"<p>$$lang_vars{no_host_spreadsheet_explic_message} \"$import_dir/networks.xls\"");
}
if ( ! -r $excel_file_name ) {
        $gip->print_error("$client_id","$$lang_vars{spreadsheet_no_readable_message} \"$excel_file_name\"<p>$$lang_vars{check_permissions_message}");
}


$gip->print_error("$client_id","$$lang_vars{hoja_and_first_sheets_message}") if ( $daten{'hoja'} && $daten{'some_sheet_values'} );
$gip->print_error("$client_id","$$lang_vars{hoja_and_first_sheets_message}") if ( $daten{'one_sheet'} && $daten{'sheet_import_type'} ne "one_sheet" );
$gip->print_error("$client_id","$$lang_vars{hoja_and_first_sheets_message}") if ( $daten{'some_sheet_values'} && $daten{'sheet_import_type'} ne "some_sheet" );
$gip->print_error("$client_id","$$lang_vars{hoja_and_first_sheets_message}") if ( ($daten{'hoja'} || $daten{'some_sheet_values'} ) && $daten{'sheet_import_type'} eq "all_sheet" );
$gip->print_error("$client_id","$$lang_vars{no_sheetname_message}") if ( $daten{'sheet_import_type'} eq "one_sheet" && ! $daten{hoja} );


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



my ($import_sheet_numbers,$some_sheet_values);
my $k = "0";
if ( $daten{'sheet_import_type'} eq "some_sheet" ) {
	$daten{'some_sheet_values'} =~ s/\s*//g;
	$gip->print_error("$client_id","$$lang_vars{check_sheet_number_format} $daten{'some_sheet_values'}") if ( $daten{'some_sheet_values'} !~ /[0-9\,\-]/ );
	$some_sheet_values = $daten{'some_sheet_values'};
	while ( 1 == 1 ) {
		my $hay_match = 1;
		$some_sheet_values =~ s/(\d+-\d+)//;
		if ( $1 ) {
			$1 =~ /(\d+)-(\d+)/;
			$gip->print_error("$client_id","$$lang_vars{'99_sheets_max_message'}") if $1 >= "100";
			$gip->print_error("$client_id","$$lang_vars{'99_sheets_max_message'}") if $2 >= "100";
			for (my $l = $1; $l <= $2; $l++) {
				if ( $import_sheet_numbers ) {
					$import_sheet_numbers = $import_sheet_numbers . "|" . $l;
				} else {
					$import_sheet_numbers = $l;
				}
			}
			$k++;
			$hay_match = 0;
			next;
		}
		$some_sheet_values =~ s/^,*(\d+),*//;
		if ( $1 ) {
			$gip->print_error("$client_id","$$lang_vars{'99_sheets_max_message'}") if $1 >= 100;
			if ( $import_sheet_numbers ) {
				$import_sheet_numbers = $import_sheet_numbers . "|" . $1;
			} else {
				$import_sheet_numbers = $1;
			}
			$hay_match = 0;
			$k++;
			next;
		}
		$k++;
		last if $k >= 100;
		last if $hay_match == 1;
	}
}

$gip->print_error("$client_id","$$lang_vars{check_sheet_number_format} $some_sheet_values") if ( $some_sheet_values );
$gip->print_error("$client_id","$$lang_vars{check_sheet_number_format}") if ( $daten{'some_sheet_values'} && ! $import_sheet_numbers );


if ( ! $daten{'redes'} && ! $daten{'BM'} && ! $daten{'mixed'} ) {
	$gip->print_error("$client_id","$$lang_vars{elige_columna_net_bm_message}");
} elsif ( $daten{'redes'} && ! $daten{'BM'} && ! $daten{'mixed'} ) {
	$gip->print_error("$client_id","$$lang_vars{introduce_columna_BM_message}");
} elsif ( ! $daten{'redes'} && $daten{'BM'} && ! $daten{'mixed'} ) {
	$gip->print_error("$client_id","$$lang_vars{introduce_columna_redes_message}");
} elsif ( $daten{'redes'} && ! $daten{'BM'} && $daten{'mixed'} ) {
	$gip->print_error("$client_id","$$lang_vars{elige_columna_net_bm_message}");
} elsif ( ! $daten{'redes'} && $daten{'BM'} && $daten{'mixed'} ) {
	$gip->print_error("$client_id","$$lang_vars{elige_columna_net_bm_message}");
}
	

if ( $daten{redes} && $daten{redes} !~ /^\w{1}$/ ) { $gip->print_error("$client_id",$$lang_vars{formato_malo_message}) };
if ( $daten{BM} && $daten{BM} !~ /^\w{1}$/ ) { $gip->print_error("$client_id",$$lang_vars{formato_malo_message}) };
if ( $daten{mixed} && $daten{mixed} !~ /^\w{1}$/ ) { $gip->print_error("$client_id",$$lang_vars{formato_malo_message}) };
if ( $daten{descr} && $daten{descr} !~ /^\w{1}$/ ) { $gip->print_error("$client_id",$$lang_vars{formato_malo_message}) };
if ( $daten{loc} && $daten{loc} !~ /^\w{1}$/ ) { $gip->print_error("$client_id",$$lang_vars{formato_malo_message}) };
if ( $daten{cat} && $daten{cat} !~ /^\w{1}$/ ) { $gip->print_error("$client_id",$$lang_vars{formato_malo_message}) };
if ( $daten{comentario} && $daten{comentario} !~ /^\w{1}$/ ) { $gip->print_error("$client_id",$$lang_vars{formato_malo_message}) };
if ( $daten{mark_sync} && $daten{mark_sync} !~ /^\w{1}$/ ) { $gip->print_error("$client_id",$$lang_vars{formato_malo_message}) };

my $sync=$daten{'mark_sync'} || "n";

my $key;
my $found_value="NULL";
my $found_key="NULL";
foreach $key (sort {$daten{$a} cmp $daten{$b} } keys %daten) {
	next if ! $daten{$key}; 
	if ( $found_value eq $daten{$key} ) {
		$gip->print_error("$client_id","$$lang_vars{column_duplicada_message}:<p>$found_key -> <b>$found_value</b><br>$key -> <b>$daten{$key}</b></b><p>$$lang_vars{comprueba_formulario_message}");
	}
	$found_value = "$daten{$key}";
	$found_key = $key;
}

my $excel_sheet_name=$daten{'hoja'} || "_NO__SHEET__GIVEN_";
$gip->print_error("$client_id","$$lang_vars{palabra_reservada_host_descr_NULL_message}") if $daten{'descr'} eq "NULL";
$gip->print_error("$client_id","$$lang_vars{palabra_reservada_comment_NULL_message}") if $daten{'comentario'} eq "NULL";
my $vigilada=$daten{'vigilada'} || "n";


my $red_num = $gip->get_last_red_num("$client_id") || "1";

my @values_redes = $gip->get_redes("$client_id",'-1','-1','0','254','red_auf',"$ip_version_ele");
my @overlap_redes=$gip->get_overlap_red("$ip_version","$client_id");
my $allowd = $gip->get_allowed_characters();
my @cc_values=$gip->get_custom_columns("$client_id");

my ( $row_new, $loc_id,$cat_id,$loc_audit,$cat_audit );
my $excel = Spreadsheet::ParseExcel::Workbook->Parse($excel_file_name);
my $sheet_found=1;
my $valid_sheet_found=1;
my $network_found="1";
my $j = "1";
my @found_networks=();

print "<span class=\"sinc_text\"><p>";
foreach my $sheet (@{$excel->{Worksheet}}) {
	if (( $sheet->{Name} eq "$excel_sheet_name" && $daten{'hoja'} && $daten{'sheet_import_type'} eq "one_sheet" ) || ( $daten{'sheet_import_type'} eq "all_sheet" && ! $daten{'hoja'} && ! $daten{'some_sheet_values'} ) || ( $daten{'sheet_import_type'} eq "some_sheet" && $j =~ /^($import_sheet_numbers)$/ )) {
		$sheet_found=0;
		
		if ( ! defined($sheet->{MaxRow}) || ! defined($sheet->{MinRow}) ) {
			if ( $vars_file =~ /vars_he$/ ) {
				print "<p><span style=\"float: $ori\">$$lang_vars{empty_sheet_message} - <b><i>$sheet->{Name} :$$lang_vars{sheet_message}</i></b></span><br><p>\n";
			} else {
				print "<p><b><i>$$lang_vars{sheet_message}: $sheet->{Name}</i></b>\n";
				print "  - $$lang_vars{empty_sheet_message}<p>\n";
			}
			$j++;
			next;
		}

		if ( $vars_file =~ /vars_he$/ ) {
			print "<p><span style=\"float: $ori\"><b><i>$sheet->{Name} :$$lang_vars{sheet_message}</i></b></span><br>\n";
		} else {
			print "<p><b><i>$$lang_vars{sheet_message}: $sheet->{Name}</i></b>\n";
		}

		$valid_sheet_found = 0;

		print "<p>\n";
		

		$sheet->{MaxRow} ||= $sheet->{MinRow};

		foreach my $row ($sheet->{MinRow} .. $sheet->{MaxRow}) {
			$sheet->{MaxCol} ||= $sheet->{MinCol};

			my $cell1 = $sheet->{Cells}[$row][0];
			my $cell2 = $sheet->{Cells}[$row][1];
			my $cell3 = $sheet->{Cells}[$row][2];
			my $cell4 = $sheet->{Cells}[$row][3];
			my $cell5 = $sheet->{Cells}[$row][4];
			my $cell6 = $sheet->{Cells}[$row][5];
			my $cell7 = $sheet->{Cells}[$row][6];
			my $cell8 = $sheet->{Cells}[$row][7];
			my $cell9 = $sheet->{Cells}[$row][8];
			my $cell10 = $sheet->{Cells}[$row][9];
			my $cell11 = $sheet->{Cells}[$row][10];
			my $cell12 = $sheet->{Cells}[$row][11];
			my $cell13 = $sheet->{Cells}[$row][12];
			my $cell14 = $sheet->{Cells}[$row][13];
			my $cell15 = $sheet->{Cells}[$row][14];
			my $cell16 = $sheet->{Cells}[$row][15];
			my $cell17 = $sheet->{Cells}[$row][16];
			my $cell18 = $sheet->{Cells}[$row][17];
			my $cell19 = $sheet->{Cells}[$row][18];
			my $cell20 = $sheet->{Cells}[$row][19];
			my $cell21 = $sheet->{Cells}[$row][20];
			my $cell22 = $sheet->{Cells}[$row][21];
			my $cell23 = $sheet->{Cells}[$row][22];
			my $cell24 = $sheet->{Cells}[$row][23];
			my $cell25 = $sheet->{Cells}[$row][24];
			my $cell26 = $sheet->{Cells}[$row][25];

			my %entries = %daten;
			while ( my ($key,$value) = each ( %entries ) ) {
				if ( $value eq "A" ) {
					$entries{"$key"} = $cell1->{Val} || "";
					if ( $cell1->{Val} && $cell1->{Val} eq "0" ) {
						$entries{"$key"} = "0";
					}
					if ( Spreadsheet::ParseExcel::Cell->can('value') && $entries{"$key"} && $cell1->{Val} ne "0") {
						$entries{"$key"} = $cell1->value() if $cell1->value();
					}
				} elsif ( $value eq "B" ) {
					$entries{"$key"} = $cell2->{Val} || "";
					if ( $cell2->{Val} && $cell2->{Val} eq "0" ) {
						$entries{"$key"} = "0";
					}
					if ( Spreadsheet::ParseExcel::Cell->can('value') && $entries{"$key"} && $cell2->{Val} ne "0") {
						$entries{"$key"} = $cell2->value() if $cell2->value();
					}
				} elsif ( $value eq "C" ) {
					$entries{"$key"} = $cell3->{Val} || "";
					if ( $cell3->{Val} && $cell3->{Val} eq "0" ) {
						$entries{"$key"} = "0";
					}
					if ( Spreadsheet::ParseExcel::Cell->can('value') && $entries{"$key"} && $cell3->{Val} ne "0") {
						$entries{"$key"} = $cell3->value() if $cell3->value();
					}
				} elsif ( $value eq "D" ) {
					$entries{"$key"} = $cell4->{Val} || "";
					if ( $cell4->{Val} && $cell4->{Val} eq "0" ) {
						$entries{"$key"} = "0";
					}
					if ( Spreadsheet::ParseExcel::Cell->can('value') && $entries{"$key"} && $cell4->{Val} ne "0") {
						$entries{"$key"} = $cell4->value() if $cell4->value();
					}
				} elsif ( $value eq "E" ) {
					$entries{"$key"} = $cell5->{Val} || "";
					if ( $cell5->{Val} && $cell5->{Val} eq "0" ) {
						$entries{"$key"} = "0";
					}
					if ( Spreadsheet::ParseExcel::Cell->can('value') && $entries{"$key"} && $cell5->{Val} ne "0") {
						$entries{"$key"} = $cell5->value() if $cell5->value();
					}
				} elsif ( $value eq "F" ) {
					$entries{"$key"} = $cell6->{Val} || "";
					if ( $cell6->{Val} && $cell6->{Val} eq "0" ) {
						$entries{"$key"} = "0";
					}
					if ( Spreadsheet::ParseExcel::Cell->can('value') && $entries{"$key"} && $cell6->{Val} ne "0") {
						$entries{"$key"} = $cell6->value() if $cell6->value();
					}
				} elsif ( $value eq "G" ) {
					$entries{"$key"} = $cell7->{Val} || "";
					if ( $cell7->{Val} && $cell7->{Val} eq "0" ) {
						$entries{"$key"} = "0";
					}
					if ( Spreadsheet::ParseExcel::Cell->can('value') && $entries{"$key"} && $cell7->{Val} ne "0") {
						$entries{"$key"} = $cell7->value() if $cell7->value();
					}
				} elsif ( $value eq "H" ) {
					$entries{"$key"} = $cell8->{Val} || "";
					if ( $cell8->{Val} && $cell8->{Val} eq "0" ) {
						$entries{"$key"} = "0";
					}
					if ( Spreadsheet::ParseExcel::Cell->can('value') && $entries{"$key"} && $cell8->{Val} ne "0") {
						$entries{"$key"} = $cell8->value() if $cell8->value();
					}
				} elsif ( $value eq "I" ) {
					$entries{"$key"} = $cell9->{Val} || "";
					if ( $cell9->{Val} && $cell9->{Val} eq "0" ) {
						$entries{"$key"} = "0";
					}
					if ( Spreadsheet::ParseExcel::Cell->can('value') && $entries{"$key"} && $cell9->{Val} ne "0") {
						$entries{"$key"} = $cell9->value() if $cell9->value();
					}
				} elsif ( $value eq "J" ) {
					$entries{"$key"} = $cell10->{Val} || "";
					if ( $cell10->{Val} && $cell10->{Val} eq "0" ) {
						$entries{"$key"} = "0";
					}
					if ( Spreadsheet::ParseExcel::Cell->can('value') && $entries{"$key"} && $cell10->{Val} ne "0") {
						$entries{"$key"} = $cell10->value() if $cell10->value();
					}
				} elsif ( $value eq "K" ) {
					$entries{"$key"} = $cell11->{Val} || "";
					if ( $cell11->{Val} && $cell11->{Val} eq "0" ) {
						$entries{"$key"} = "0";
					}
					if ( Spreadsheet::ParseExcel::Cell->can('value') && $entries{"$key"} && $cell11->{Val} ne "0") {
						$entries{"$key"} = $cell11->value() if $cell11->value();
					}
				} elsif ( $value eq "L" ) {
					$entries{"$key"} = $cell12->{Val} || "";
					if ( $cell12->{Val} && $cell12->{Val} eq "0" ) {
						$entries{"$key"} = "0";
					}
					if ( Spreadsheet::ParseExcel::Cell->can('value') && $entries{"$key"} && $cell12->{Val} ne "0") {
						$entries{"$key"} = $cell12->value() if $cell12->value();
					}
				} elsif ( $value eq "M" ) {
					$entries{"$key"} = $cell13->{Val} || "";
					if ( $cell13->{Val} && $cell13->{Val} eq "0" ) {
						$entries{"$key"} = "0";
					}
					if ( Spreadsheet::ParseExcel::Cell->can('value') && $entries{"$key"} && $cell13->{Val} ne "0") {
						$entries{"$key"} = $cell13->value() if $cell13->value();
					}
				} elsif ( $value eq "N" ) {
					$entries{"$key"} = $cell14->{Val} || "";
					if ( $cell14->{Val} && $cell14->{Val} eq "0" ) {
						$entries{"$key"} = "0";
					}
					if ( Spreadsheet::ParseExcel::Cell->can('value') && $entries{"$key"} && $cell14->{Val} ne "0") {
						$entries{"$key"} = $cell14->value() if $cell14->value();
					}
				} elsif ( $value eq "O" ) {
					$entries{"$key"} = $cell15->{Val} || "";
					if ( $cell15->{Val} && $cell15->{Val} eq "0" ) {
						$entries{"$key"} = "0";
					}
					if ( Spreadsheet::ParseExcel::Cell->can('value') && $entries{"$key"} && $cell15->{Val} ne "0") {
						$entries{"$key"} = $cell15->value() if $cell15->value();
					}
				} elsif ( $value eq "P" ) {
					$entries{"$key"} = $cell16->{Val} || "";
					if ( $cell16->{Val} && $cell16->{Val} eq "0" ) {
						$entries{"$key"} = "0";
					}
					if ( Spreadsheet::ParseExcel::Cell->can('value') && $entries{"$key"} && $cell16->{Val} ne "0") {
						$entries{"$key"} = $cell16->value() if $cell16->value();
					}
				} elsif ( $value eq "Q" ) {
					$entries{"$key"} = $cell17->{Val} || "";
					if ( $cell17->{Val} && $cell17->{Val} eq "0" ) {
						$entries{"$key"} = "0";
					}
					if ( Spreadsheet::ParseExcel::Cell->can('value') && $entries{"$key"} && $cell17->{Val} ne "0") {
						$entries{"$key"} = $cell17->value() if $cell17->value();
					}
				} elsif ( $value eq "R" ) {
					$entries{"$key"} = $cell18->{Val} || "";
					if ( $cell18->{Val} && $cell18->{Val} eq "0" ) {
						$entries{"$key"} = "0";
					}
					if ( Spreadsheet::ParseExcel::Cell->can('value') && $entries{"$key"} && $cell18->{Val} ne "0") {
						$entries{"$key"} = $cell18->value() if $cell18->value();
					}
				} elsif ( $value eq "S" ) {
					$entries{"$key"} = $cell19->{Val} || "";
					if ( $cell19->{Val} && $cell19->{Val} eq "0" ) {
						$entries{"$key"} = "0";
					}
					if ( Spreadsheet::ParseExcel::Cell->can('value') && $entries{"$key"} && $cell19->{Val} ne "0") {
						$entries{"$key"} = $cell19->value() if $cell19->value();
					}
				} elsif ( $value eq "T" ) {
					$entries{"$key"} = $cell20->{Val} || "";
					if ( $cell20->{Val} && $cell20->{Val} eq "0" ) {
						$entries{"$key"} = "0";
					}
					if ( Spreadsheet::ParseExcel::Cell->can('value') && $entries{"$key"} && $cell20->{Val} ne "0") {
						$entries{"$key"} = $cell20->value() if $cell20->value();
					}
				} elsif ( $value eq "U" ) {
					$entries{"$key"} = $cell21->{Val} || "";
					if ( $cell21->{Val} && $cell21->{Val} eq "0" ) {
						$entries{"$key"} = "0";
					}
					if ( Spreadsheet::ParseExcel::Cell->can('value') && $entries{"$key"} && $cell21->{Val} ne "0") {
						$entries{"$key"} = $cell21->value() if $cell21->value();
					}
				} elsif ( $value eq "V" ) {
					$entries{"$key"} = $cell22->{Val} || "";
					if ( $cell22->{Val} && $cell22->{Val} eq "0" ) {
						$entries{"$key"} = "0";
					}
					if ( Spreadsheet::ParseExcel::Cell->can('value') && $entries{"$key"} && $cell22->{Val} ne "0") {
						$entries{"$key"} = $cell22->value() if $cell22->value();
					}
				} elsif ( $value eq "W" ) {
					$entries{"$key"} = $cell23->{Val} || "";
					if ( $cell23->{Val} && $cell23->{Val} eq "0" ) {
						$entries{"$key"} = "0";
					}
					if ( Spreadsheet::ParseExcel::Cell->can('value') && $entries{"$key"} && $cell23->{Val} ne "0") {
						$entries{"$key"} = $cell23->value() if $cell23->value();
					}
				} elsif ( $value eq "X" ) {
					$entries{"$key"} = $cell24->{Val} || "";
					if ( $cell24->{Val} && $cell24->{Val} eq "0" ) {
						$entries{"$key"} = "0";
					}
					if ( Spreadsheet::ParseExcel::Cell->can('value') && $entries{"$key"} && $cell24->{Val} ne "0") {
						$entries{"$key"} = $cell24->value() if $cell24->value();
					}
				} elsif ( $value eq "Y" ) {
					$entries{"$key"} = $cell25->{Val} || "";
					if ( $cell25->{Val} && $cell25->{Val} eq "0" ) {
						$entries{"$key"} = "0";
					}
					if ( Spreadsheet::ParseExcel::Cell->can('value') && $entries{"$key"} && $cell25->{Val} ne "0") {
						$entries{"$key"} = $cell25->value() if $cell25->value();
					}
				} elsif ( $value eq "Z" ) {
					$entries{"$key"} = $cell26->{Val} || "";
					if ( $cell26->{Val} && $cell26->{Val} eq "0" ) {
						$entries{"$key"} = "0";
					}
					if ( Spreadsheet::ParseExcel::Cell->can('value') && $entries{"$key"} && $cell26->{Val} ne "0") {
						$entries{"$key"} = $cell26->value() if $cell26->value();
					}
				}
			}

			if ( $entries{mixed} ) {
				if ( $ip_version eq "v4" ) {
					if ( $entries{mixed} =~ /.*?(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\D+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\s*$/ ) {
						$entries{redes} = $1;
						$entries{BM} = $2;
						$network_found = "0";			
					} elsif ( $entries{mixed} =~ /.*?(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\D+(\d{1,2})\s*$/ ) {
						$entries{redes} = $1;
						$entries{BM} = $2;
						$network_found = "0";			
					} else {
						next;
					}
				} else {
					$entries{mixed} =~ /(.*)\/(\d{1,3})\s*$/;
					$entries{redes} = $1;
					$entries{BM} = $2;
				}
			}

			# Check network format
			if ( ! $entries{redes} ) {
				next;
			}
			if ( $ip_version eq "v4" ) {
				if ( $entries{redes} =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}$/ ) {
					$entries{redes} .= '.0';	
				}
				if ( $entries{redes} !~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/ ) {
					if ( $vars_file =~ /vars_he$/ ) {
						print "<span style=\"float: $ori\">$$lang_vars{ignorado_message} - $entries{redes} :$$lang_vars{red4_invalido_message}</span><br>\n";
					} else {
						print "$$lang_vars{red4_invalido_message}: $entries{redes} - $$lang_vars{ignorado_message}<br>\n";
					}
					next;
				}
			} else {
				my $valid_v6 = $gip->check_valid_ipv6("$entries{redes}") || "0";
				if ( $valid_v6 != "1" ) {
					if ( $vars_file =~ /vars_he$/ ) {
						print "<span style=\"float: $ori\">$$lang_vars{ignorado_message} - $entries{redes} :$$lang_vars{red6_invalido_message}</span><br>\n";
					} else {
						print "$$lang_vars{red6_invalido_message}: $entries{redes} - $$lang_vars{ignorado_message}<br>\n";
					}
					next;
				}
			}
			

			$entries{BM} =~ s/\///;

			# Check if BM exists
			if ( ! $entries{BM} ) {
				if ( $vars_file =~ /vars_he$/ ) {
					print "<span style=\"float: $ori\">$$lang_vars{ignorado_message} - $$lang_vars{no_bitmask_message} :<b>$entries{redes}</b></span><br>\n";
				} else {
					print "<b>$entries{redes}</b>: $$lang_vars{no_bitmask_message} - $$lang_vars{ignorado_message}<br>\n";
				}
				next;
			}

			# Convert allowed netmasks to bitmasks
                        if (( $entries{BM} =~ /\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/ || $entries{BM} =~ /^\.\d{1,3}$/ || $entries{BM} =~ /^\.?(255|254|252|248|240|224|192|128|0)$/) && $ip_version eq "v4" ) {

				$entries{BM} =~ s/\s+//g;
				$entries{BM} =~ s/\.// if $entries{BM} =~ /^\.\d{1,3}$/;
				if ( $entries{BM} =~ /255.255.255.255/ || $entries{BM} =~ /^255$/ ) { $entries{BM} = "32"; }
				elsif ( $entries{BM} =~ /255.255.255.254/ || $entries{BM} =~ /^254$/ ) { $entries{BM} = "31"; }
				elsif ( $entries{BM} =~ /255.255.255.252/ || $entries{BM} =~ /^252$/ ) { $entries{BM} = "30"; }
				elsif ( $entries{BM} =~ /255.255.255.248/ || $entries{BM} =~ /^248$/ ) { $entries{BM} = "29"; }
				elsif ( $entries{BM} =~ /255.255.255.240/ || $entries{BM} =~ /^240$/ ) { $entries{BM} = "28"; }
				elsif ( $entries{BM} =~ /255.255.255.224/ || $entries{BM} =~ /^224$/ ) { $entries{BM} = "27"; }
				elsif ( $entries{BM} =~ /255.255.255.192/ || $entries{BM} =~ /^192$/ ) { $entries{BM} = "26"; }
				elsif ( $entries{BM} =~ /255.255.255.128/ || $entries{BM} =~ /^128$/ ) { $entries{BM} = "25"; }
				elsif ( $entries{BM} =~ /255.255.255.0/ || $entries{BM} =~ /^0$/ ) { $entries{BM} = "24"; }
				elsif ( $entries{BM} =~ /255.255.254.0/ ) { $entries{BM} = "23"; }
				elsif ( $entries{BM} =~ /255.255.252.0/ ) { $entries{BM} = "22"; }
				elsif ( $entries{BM} =~ /255.255.248.0/ ) { $entries{BM} = "21"; }
				elsif ( $entries{BM} =~ /255.255.240.0/ ) { $entries{BM} = "20"; }
				elsif ( $entries{BM} =~ /255.255.224.0/ ) { $entries{BM} = "19"; }
				elsif ( $entries{BM} =~ /255.255.192.0/ ) { $entries{BM} = "18"; }
				elsif ( $entries{BM} =~ /255.255.128.0/ ) { $entries{BM} = "17"; }
				elsif ( $entries{BM} =~ /255.255.0.0/ ) { $entries{BM} = "16"; }
				elsif ( $entries{BM} =~ /255.254.0.0/ ) { $entries{BM} = "15"; }
				elsif ( $entries{BM} =~ /255.252.0.0/ ) { $entries{BM} = "14"; }
				elsif ( $entries{BM} =~ /255.248.0.0/ ) { $entries{BM} = "13"; }
				elsif ( $entries{BM} =~ /255.240.0.0/ ) { $entries{BM} = "12"; }
				elsif ( $entries{BM} =~ /255.224.0.0/ ) { $entries{BM} = "11"; }
				elsif ( $entries{BM} =~ /255.192.0.0/ ) { $entries{BM} = "10"; }
				elsif ( $entries{BM} =~ /255.128.0.0/ ) { $entries{BM} = "9"; }
				elsif ( $entries{BM} =~ /255.0.0.0/ ) { $entries{BM} = "8"; }
				elsif ( $entries{BM} =~ /254.0.0.0/ ) { $entries{BM} = "7"; }
				elsif ( $entries{BM} =~ /252.0.0.0/ ) { $entries{BM} = "6"; }
				elsif ( $entries{BM} =~ /248.0.0.0/ ) { $entries{BM} = "5"; }
				elsif ( $entries{BM} =~ /240.0.0.0/ ) { $entries{BM} = "4"; }
				elsif ( $entries{BM} =~ /224.0.0.0/ ) { $entries{BM} = "3"; }
				elsif ( $entries{BM} =~ /129.0.0.0/ ) { $entries{BM} = "2"; }
				elsif ( $entries{BM} =~ /128.0.0.0/ ) { $entries{BM} = "1"; }
				elsif ( $entries{BM} =~ /^\d{1,3}$/ ) {
					if ( $vars_file =~ /vars_he$/ ) {
						print "<span style=\"float: $ori\">$$lang_vars{ignorado_message} - $entries{BM} :<b>$entries{redes}:</b> $$lang_vars{bitmask_mala_message}</span><br>\n";
					} else {
						print "<b>$entries{redes}:</b> $$lang_vars{bitmask_mala_message}: $entries{BM} - $$lang_vars{ignorado_message}<br>\n";
					}
					next;
				 } else { 
					if ( $vars_file =~ /vars_he$/ ) {
						print "<span style=\"float: $ori\">$$lang_vars{ignorado_message} - 255.255.192.0 $$lang_vars{y_message} 128.0.0.0 $$lang_vars{netmask_no_between_message} - $entries{BM}=$$lang_vars{netmask_message} :<b>$entries{redes}</b></span><br>\n";
					} else {
						print "<b>$entries{redes}</b>: $$lang_vars{netmask_message}=$entries{BM} - $$lang_vars{netmask_no_between_message} 128.0.0.0 $$lang_vars{y_message} 255.255.192.0 - $$lang_vars{ignorado_message}<br>\n";
					}
					next;
				}
			}

			# Check bitmask format
			if (( $entries{BM} !~ /^\d{1,2}$/ && $ip_version eq "v4" ) || ( $entries{BM} !~ /^\d{1,3}$/ && $ip_version eq "v6" )) {
				$entries{BM} =~ s/\s+//g;
				if ( $vars_file =~ /vars_he$/ ) {
					print "<span style=\"float: $ori\">$$lang_vars{ignorado_message} - $entries{BM} :$$lang_vars{bitmask_mala_message} :<b>$entries{redes}</b></span><br>\n";
				} else {
					print "<b>$entries{redes}:</b> $$lang_vars{bitmask_mala_message}: $entries{BM} - $$lang_vars{ignorado_message}<br>\n";
				}
				next;
			} else {
				$network_found = "0";
			}


			# Ignore row if bitmask < $smallest_bm or bitmask > 32


			my $ignore_rootnet=1;
			my $red_exists="";

			my $rootnet_val=0;

			if ( $entries{is_rootnet} ) {
				$rootnet_val=1;
			} elsif ( $entries{BM} < 64 && $ip_version eq "v6" ) {
				$rootnet_val=1;
			}

			if ( $ip_version eq "v4" ) {
				if ( $entries{BM} < $smallest_bm ) {
					if ( $vars_file =~ /vars_he$/ ) {
						print "<span style=\"float: $ori\">$$lang_vars{ignorado_message} - $smallest_bm $$lang_vars{bm_not_allowed_message} - $entries{BM}=BM :<b>$entries{redes}</b></span><br>\n";
					} else {
						print "<b>$entries{redes}</b>: BM=$entries{BM} - $$lang_vars{bm_not_allowed_message}";
						print " $smallest_bm - $$lang_vars{ignorado_message}<br>\n";
					}
					next;
				}

				if ( $rootnet_val == 1 && $entries{BM} == 32 ) {
					if ( $vars_file =~ /vars_he$/ ) {
						print "<span style=\"float: $ori\">$$lang_vars{ignorado_message} - $$lang_vars{rootnet_message} + $entries{BM}=BM :<b>$entries{redes}</b></span><br>\n";
					} else {
						print "<b>$entries{redes}</b>: BM=$entries{BM} + $$lang_vars{rootnet_message} - $$lang_vars{ignorado_message}<br>\n";
					}
					next;
				}
			}


			if (( $entries{BM} > 32  && $ip_version eq "v4" ) || ( $entries{BM} > 128 && $ip_version eq "v6" )) {
				if ( $ip_version eq "v4" ) {
					if ( $vars_file =~ /vars_he$/ ) {
						print "<span style=\"float: $ori\">$$lang_vars{ignorado_message} - $$lang_vars{no_bm_31_message} $entries{BM}=BM :<b>$entries{redes}</b></span><br>\n";
					} else {
						print "<b>$entries{redes}</b>: BM=$entries{BM} - $$lang_vars{no_bm_31_message} - $$lang_vars{ignorado_message}<br>\n";
					}
				} else {
					if ( $vars_file =~ /vars_he$/ ) {
						print "<span style=\"float: $ori\">$$lang_vars{ignorado_message} - $$lang_vars{no_bm_128_message} $entries{BM}=BM :<b>$entries{redes}</span><br>\n";
					} else {
						print "<b>$entries{redes}</b>: BM=$entries{BM} - $$lang_vars{no_bm_128_message} - $$lang_vars{ignorado_message}<br>\n";
					}
				}
				next;
			}


			# Check if nework/bitmask result in a valid range
			my $valid_net = "0";
			my $redob = "$entries{redes}/$entries{BM}";
			my $ipob_red = new Net::IP ($redob) or $valid_net = "1";
			if ( $valid_net == "1" && $ip_version eq "v4" ) {
				if ( $vars_file =~ /vars_he$/ ) {
					print "<span style=\"float: $ori\">$$lang_vars{ignorado_message} - $$lang_vars{red4_invalido_message} <b>$redob</b></span><br>";
				} else {
					print "<b>$redob</b> - $$lang_vars{red4_invalido_message} - $$lang_vars{ignorado_message}<br>";
				}
				next;
			} elsif ( $valid_net == "1" && $ip_version eq "v6" ) {
				if ( $vars_file =~ /vars_he$/ ) {
					print "<span style=\"float: $ori\">$$lang_vars{ignorado_message} - $$lang_vars{red6_invalido_message} - <b>$redob</b></span><br>";
				} else {
					print "<b>$redob</b> - $$lang_vars{red6_invalido_message} - $$lang_vars{ignorado_message}<br>";
				}
				next;
			}

#			$entries{redes} = ip_expand_address ($entries{redes}, 6) if $ip_version eq "v6";
			my $red_expanded = $entries{redes};
			$red_expanded = ip_expand_address ($entries{redes}, 6) if $ip_version eq "v6";


			# Check for overlapping networks
			if ( $overlap_redes[0]->[0] && $rootnet_val == 0 ) {
				my @overlap_found = $gip->find_overlap_redes("$client_id","$red_expanded","$entries{BM}",\@overlap_redes,"$ip_version","$vars_file","","","1");
				if ( $overlap_found[0] ) {
					if ( $vars_file =~ /vars_he$/ ) {
						print "<span style=\"float: $ori\">$$lang_vars{ignorado_message} - $overlap_found[0] $$lang_vars{overlaps_con_message} <b>$entries{redes}/$entries{BM}</b></span><br>\n";
					} else {
						print "<b>$entries{redes}/$entries{BM}</b> $$lang_vars{overlaps_con_message} $overlap_found[0] - $$lang_vars{ignorado_message}<br>\n";
					}
					next;
				}
			} elsif ( $rootnet_val == 1 ) {
				$red_exists=$gip->check_red_exists("$client_id","$red_expanded","$entries{BM}","0");
				### TEST oder mit loop ueber @overlap_found um neue database verbindungen zu vermeiden.....

				if ( $red_exists ) {
					if ( $vars_file =~ /vars_he$/ ) {
						print "<span style=\"float: $ori\">$$lang_vars{ignorado_message} - $$lang_vars{red_exists_message} <b>$entries{redes}/$entries{BM}</b></span><br>\n";
					} else {
						print "<b>$entries{redes}/$entries{BM}</b> $$lang_vars{red_exists_message} - $$lang_vars{ignorado_message}<br>\n";
					}
					next;
				}
			}

			# check for unallowed characters
			foreach my $key( keys %entries ) {
				$entries{$key} =~ s/['<>\\\/*&#%\^\`=\$*]/_/g;
				my $converted=encode("UTF-8",$entries{$key}); 
				$entries{$key} = $converted;

				$converted =~ s/['=?_\.,:\-\@()\w\/\[\]{}|~\+\n\r\f\t\s]//g;
				my $hex = join('', map { sprintf('%X', ord $_) } split('', "$converted"));
				my @hex_ar=split(' ',$converted); 

				foreach (@hex_ar) {
					if ( $_ !~ /^[${allowd}]+$/i && $hex =~ /.+/) {
						if ( $vars_file =~ /vars_he$/ ) {
							print "<span style=\"float: $ori\">$$lang_vars{ignorado_message} $key - $$lang_vars{caracter_no_permitido_encontrado_message} :$key :<b>$entries{redes}/$entries{BM}</b></span><br>\n";
						} else {
							print "<b>$entries{redes}/$entries{BM}</b>: $key: $$lang_vars{caracter_no_permitido_encontrado_message} - $key $$lang_vars{ignorado_message}<br>\n";
						}
						$entries{$key} ="";
						last;
					}
				}
			}

			# add the network to @values_redes to include it within the overlap check
			# for the next network
			my $l;
			if ( ! $overlap_redes[0]->[0] ) {
				$l = "0";
			} else {
				$l = @overlap_redes;
			}

			$entries{redes} = ip_expand_address ($entries{redes}, 6) if $ip_version eq "v6";

			$overlap_redes[$l]->[0] = $entries{redes};
			$overlap_redes[$l]->[1] = $entries{BM};
			$red_num++;
			$overlap_redes[$l]->[3] = $red_num;

			if ( $rootnet_val == "1" ) {
				$overlap_redes[$l]->[10] = 1;
			} else {
				$overlap_redes[$l]->[10] = 0;
			}

			if ( $entries{loc} ) {
				$loc_id=$gip->get_loc_id("$client_id","$entries{loc}");
				if (  ! $loc_id ) {
					$loc_id="-1";
					$entries{loc} = "";
				}
			} else {
				$loc_id = "-1";
			}
		
			if ( $entries{cat} ) {
				$cat_id=$gip->get_cat_net_id("$client_id","$entries{cat}");
				if (  ! $cat_id ) {
					$cat_id="-1";
					$entries{cat} = "";
				}
			} else {
				$cat_id = "-1";
			}

			# insert networks into the database
#			print "<b>$entries{redes}/$entries{BM}</b>  ";
			my $network_string="";
			if ( $entries{descr} ne "NULL" ) {
				$network_string.="$entries{descr}  ";
			} else {
				$network_string.="- ";
			}
			if ( $entries{loc} && $entries{loc} ne "-1" ) {
				$network_string.="$entries{loc}  ";
			} else {
				$network_string.="- ";
			}
			if ( $entries{cat} && $entries{cat} ne "-1" ) {
				$network_string.="$entries{cat}  ";
			} else {
				$network_string.="- ";
			}
			if ( $entries{comentario} ne "NULL" ) {
				$network_string.="$entries{comentario}";
			} else {
				$network_string.="- ";
			}
			if ( $rootnet_val == "1" ) {
				$network_string.="$$lang_vars{rootnet_message}";
			} else {
				$network_string.="- ";
			}


			$gip->insert_net("$client_id","$red_num","$entries{redes}","$entries{BM}","$entries{descr}","$loc_id","$sync","$entries{comentario}","$cat_id","$ip_version","$rootnet_val");

			for ( my $k = 0; $k < scalar(@cc_values); $k++ ) {
				if ( $entries{"$cc_values[$k]->[0]"} ) {
					my $cc_name="$cc_values[$k]->[0]";
					my $cc_value=$entries{"$cc_values[$k]->[0]"};
					my $cc_id="$cc_values[$k]->[1]";
#					print ", $cc_value";

					my $cc_entry_net=$gip->get_custom_column_entry("$client_id","$red_num","$cc_name") || "";
					if ( $cc_entry_net ) {
						$gip->update_custom_column_value_red("$client_id","$cc_id","$red_num","$cc_value");
					} else {
						$gip->insert_custom_column_value_red("$client_id","$cc_id","$red_num","$cc_value");
					}
				}
			}

			if ( $vars_file =~ /vars_he$/ ) {
				print "<span style=\"float: $ori\">$$lang_vars{host_anadido_message} - $network_string <b>$entries{redes}/$entries{BM}</b></span><br>\n";
			} else {
				print "<b>$entries{redes}/$entries{BM}</b> $network_string - $$lang_vars{host_anadido_message}<br>\n";
			}

			push (@found_networks,$red_num);

			my $audit_type="17";
			my $audit_class="2";
			my $update_type_audit="8";
			$entries{descr}="---" if $entries{descr} eq "NULL" || $entries{descr} eq "";
			$entries{comentario}="---" if $entries{comentario} eq "NULL" || $entries{comentario} eq "";
			if ( ! $entries{loc} ) {
				$loc_audit = "---";
			} else {
				$loc_audit = $entries{loc};
			}
			if ( ! $entries{cat} ) {
				$cat_audit = "---";
			} else {
				$cat_audit = $entries{cat};
			}
		
			my $vigilada = "n";

			my $event="$entries{redes}/$entries{BM},$entries{descr},$loc_audit,$cat_audit,$entries{comentario},'n'";
			$gip->insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");
		}
	}
	$j++;
}
print "</span>\n";

if ( $sheet_found == "1" ) {
	$gip->print_error("$client_id","$$lang_vars{no_sheet_message}: \"$excel_sheet_name\"<p>$$lang_vars{comprueba_formulario_message}");
}

if ( $network_found == "1" ) {
	if ( $valid_sheet_found == "0" ) {
		if ( $ip_version eq "v4" ) {
			$gip->print_error("$client_id","$$lang_vars{no_network4_message}");
		} else {
			$gip->print_error("$client_id","$$lang_vars{no_network6_message}");
		}
	} else {
		$gip->print_error("$client_id","$$lang_vars{no_valid_sheet_message}");
	}
}

print "<br><h3 style=\"float: $ori\">$$lang_vars{listo_message}</h3><br><p><br>\n";

$found_networks_file=~/^(.*found_networks_spreadsheet.tmp)$/;
$found_networks_file=$1;

if ( $found_networks[0] ) {
	open(FN,">$found_networks_file") or print STDERR "Can't open $found_networks_file: $!\n";
	foreach my $line ( @found_networks ) {
		print FN $line . "\n";
	}
	close FN;
}

$gip->print_end("$client_id","$vars_file","go_to_top");
