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
use locale;
use Math::BigInt;

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

$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{importar_host_sheet_message}","$vars_file");

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


my $import_dir = getcwd;
$import_dir =~ s/res.*/import/;

$gip->print_error("$client_id","$$lang_vars{no_spreadsheet_message}") if $daten{'spreadsheet'} !~ /.+/;
my $spreadsheet = $daten{'spreadsheet'};
my $excel_file_name="../import/$spreadsheet";

if ( ! -e $excel_file_name ) {
	$gip->print_error("$client_id","$$lang_vars{no_spreadsheet_message} \"$spreadsheet\"<p>$$lang_vars{no_host_spreadsheet_explic_message} \"$spreadsheet\"");
}
if ( ! -r $excel_file_name ) {
	$gip->print_error("$client_id","$$lang_vars{spreadsheet_no_readable_message} \"$excel_file_name\"<p>$$lang_vars{check_permissions_message}");
}

$gip->print_error("$client_id","$$lang_vars{hoja_and_first_sheets_message}") if ( $daten{'hoja'} && $daten{'some_sheet_values'} );
$gip->print_error("$client_id","$$lang_vars{hoja_and_first_sheets_message}") if ( $daten{'one_sheet'} && $daten{'sheet_import_type'} ne "one_sheet" );
$gip->print_error("$client_id","$$lang_vars{hoja_and_first_sheets_message}") if ( $daten{'some_sheet_values'} && $daten{'sheet_import_type'} ne "some_sheet" );
$gip->print_error("$client_id","$$lang_vars{hoja_and_first_sheets_message}") if ( ( $daten{'hoja'} || $daten{'some_sheet_values'} ) && $daten{'sheet_import_type'} eq "all_sheet" );
$gip->print_error("$client_id","$$lang_vars{import_host_no_network_field}") if ( $daten{IP_format} eq "last_oct" && ! $daten{'network_field'} );
my ( $network_field_col, $network_field_row);
if ( $daten{IP_format} eq "last_oct" ) {
	$daten{'network_field'} = uc($daten{'network_field'});
	$gip->print_error("$client_id","$$lang_vars{import_host_format_network_field_message}: $daten{'network_field'}") if ( $daten{'network_field'} !~ /^[A-Z]{1}\d{1,3}$/ );
	$daten{'network_field'} =~ /^([A-Z]{1})(\d{1,3})$/;
	$network_field_col=$1;
	$network_field_row=$2;
	$network_field_row--;
	$network_field_col = "0" if $network_field_col eq "A";
	$network_field_col = "1" if $network_field_col eq "B";
	$network_field_col = "2" if $network_field_col eq "C";
	$network_field_col = "3" if $network_field_col eq "D";
	$network_field_col = "4" if $network_field_col eq "E";
	$network_field_col = "5" if $network_field_col eq "F";
	$network_field_col = "6" if $network_field_col eq "G";
	$network_field_col = "7" if $network_field_col eq "H";
	$network_field_col = "8" if $network_field_col eq "I";
	$network_field_col = "9" if $network_field_col eq "J";
	$network_field_col = "10" if $network_field_col eq "K";
	$network_field_col = "11" if $network_field_col eq "L";
	$network_field_col = "12" if $network_field_col eq "M";
	$network_field_col = "13" if $network_field_col eq "N";
	$network_field_col = "14" if $network_field_col eq "O";
	$network_field_col = "15" if $network_field_col eq "P";
	$network_field_col = "16" if $network_field_col eq "Q";
	$network_field_col = "17" if $network_field_col eq "R";
	$network_field_col = "18" if $network_field_col eq "S";
	$network_field_col = "19" if $network_field_col eq "T";
	$network_field_col = "20" if $network_field_col eq "U";
	$network_field_col = "21" if $network_field_col eq "V";
	$network_field_col = "22" if $network_field_col eq "W";
	$network_field_col = "23" if $network_field_col eq "X";
	$network_field_col = "24" if $network_field_col eq "Y";
	$network_field_col = "25" if $network_field_col eq "Z";
}

my $allowd = $gip->get_allowed_characters();
my @cc_values=$gip->get_custom_host_columns("$client_id");

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
my $m = "0";
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
			$m++;
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
			$m++;
			next;
		}
		$m++;
		last if $m >= 100;
		last if $hay_match == 1;
	}
}

$gip->print_error("$client_id","$$lang_vars{check_sheet_number_format} $some_sheet_values") if ( $some_sheet_values );
$gip->print_error("$client_id","$$lang_vars{check_sheet_number_format}") if ( $daten{'some_sheet_values'} && ! $import_sheet_numbers );


if ( ! $daten{'ip'} ) {
	$gip->print_error("$client_id","$$lang_vars{elige_columna_ip_message}");
} elsif ( ! $daten{'hostname'} ) {
	$gip->print_error("$client_id","$$lang_vars{introduce_columna_hostnames_message}");
}
	

if ( $daten{ip} && $daten{ip} !~ /^\w{1}$/ ) { $gip->print_error("$client_id","$$lang_vars{formato_malo_message}: $daten{ip}") };
if ( $daten{hostname} && $daten{hostname} !~ /^\w{1}$/ ) { $gip->print_error("$client_id",$$lang_vars{formato_malo_message}) };
if ( $daten{descr} && $daten{descr} !~ /^\w{1}$/ ) { $gip->print_error("$client_id",$$lang_vars{formato_malo_message}) };
if ( $daten{loc} && $daten{loc} !~ /^\w{1}$/ ) { $gip->print_error("$client_id",$$lang_vars{formato_malo_message}) };
if ( $daten{cat} && $daten{cat} !~ /^\w{1}$/ ) { $gip->print_error("$client_id",$$lang_vars{formato_malo_message}) };
if ( $daten{comentario} && $daten{comentario} !~ /^\w{1}$/ ) { $gip->print_error("$client_id",$$lang_vars{formato_malo_message}) };
if ( $daten{update_type} && $daten{update_type} !~ /^\w{3}$/ ) { $gip->print_error("$client_id",$$lang_vars{formato_malo_message}) };

my $utype = $daten{update_type} || "xxxxx";
my $utype_id = $gip->get_utype_id("$client_id",$utype) || "-1";

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

my @values_host_redes = $gip->get_host_redes_no_rootnet("$client_id");
my $anz_values_host_redes = @values_host_redes;
$gip->print_error("$client_id","$$lang_vars{no_network_host_import_message}") if $anz_values_host_redes == "0";

my ($row_new, $sync,$loc_id,$cat_id,$loc_audit,$cat_audit,$last_k,$host_red,$host_red_bm,$redob_redes,$ipob_redes,$last_ip_int,$first_ip_int,$redbo_redes,$mydatetime,$red_num,$k,$to_ignore);
my $host_descr="";
my $int_admin="n";
my $excel = Spreadsheet::ParseExcel::Workbook->Parse($excel_file_name);
my $sheet_found=1;
my $host_found="1";
my $firstfound = "0";
my $j = "1";

my $ip_version;
print "<span class=\"sinc_text\"><p>";
foreach my $sheet (@{$excel->{Worksheet}}) {
	if (( $sheet->{Name} eq "$excel_sheet_name" && $daten{'hoja'} && $daten{'sheet_import_type'} eq "one_sheet" ) || ( $daten{'sheet_import_type'} eq "all_sheet" && ! $daten{'hoja'} && ! $daten{'some_sheet_values'} ) || ( $daten{'sheet_import_type'} eq "some_sheet" && $j =~ /^($import_sheet_numbers)$/ )) {
		$sheet_found=0;
		$firstfound = "0";

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

		print "<p>\n";

		my $last_oct_net = "";
		if ( $daten{'network_field'} ) {
			my $last_oct_net_val = $sheet->{Cells}[$network_field_row][$network_field_col];
			$last_oct_net = $last_oct_net_val->{Val} || "";
			if ( $last_oct_net =~ /(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/ ) {
				$ip_version = "v4";
			} elsif ( $last_oct_net =~ /((?=.*::.*)(::)?([0-9A-F]{1,4}(:(?=[0-9A-F])|(?!\2)(?!\5)(::)|\z)){0,7}|((?=.*::.*)(::)?([0-9A-F]{1,4}(:(?=[0-9A-F])|(?!\7)(?!\10)(::))){0,5}|([0-9A-F]{1,4}:){6})((25[0-5]|(2[0-4]|1[0-9]|[1-9]?)[0-9])(\.(?=.)|\z)){4}|([0-9A-F]{1,4}:){7}[0-9A-F]{1,4})*/i ) {
				$ip_version = "v6";
			} else {
				print "<span style=\"float: $ori\">$$lang_vars{can_not_determine_ip_version_message}</span><br>\n";
				$j++;
				next;
			}
			if ( $ip_version eq "v4" ) {
				$last_oct_net =~ /(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/;
				$last_oct_net = $1;
				if ( ! $last_oct_net || $last_oct_net !~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/ ) {
					print "<span style=\"float: $ori\">$$lang_vars{no_network_address_found}</span><br>\n";
					$j++;
					next;
				}
				$last_oct_net =~  /(\d{1,3}\.\d{1,3}\.\d{1,3})\.(\d{1,3})/;
				$last_oct_net = $1;
				if ( $vars_file =~ /vars_he$/ ) {
					print "<span style=\"float: $ori\">$last_oct_net :<i>$$lang_vars{redes_message}</i></span><br><p>\n";
				} else {
					print "<i>$$lang_vars{redes_message}: $last_oct_net</i><p>\n";
				}
			} elsif ( $ip_version eq "v6" ) {
				$last_oct_net =~  /^(.+)\//;
				$last_oct_net = $1;
				$last_oct_net = ip_expand_address ($last_oct_net, 6);
				if ( ! $last_oct_net || $last_oct_net !~ /^\w*\:\w*\:\w*\:\w*\:\w*\:\w*\:\w*\:\w*$/ ) {
					print "<span style=\"float: $ori\">$$lang_vars{no_network_address_found}</span><br>\n";
					$j++;
					next;
				}
#### TEST /^(\w*.......... ueberarbeiten....
				$last_oct_net =~  /^(\w*\:\w*\:\w*\:\w*\:\w*\:\w*\:\w*)\:\w*$/;
				$last_oct_net = $1;
			}
			
		}

		$sheet->{MaxRow} ||= $sheet->{MinRow};

		foreach my $row ($sheet->{MinRow} .. $sheet->{MaxRow}) {
			$to_ignore = "0";
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
			my $cell12 =  $sheet->{Cells}[$row][11];
			my $cell13 =  $sheet->{Cells}[$row][12];
			my $cell14 =  $sheet->{Cells}[$row][13];
			my $cell15 =  $sheet->{Cells}[$row][14];
			my $cell16 =  $sheet->{Cells}[$row][15];
			my $cell17 =  $sheet->{Cells}[$row][16];
			my $cell18 =  $sheet->{Cells}[$row][17];
			my $cell19 =  $sheet->{Cells}[$row][18];
			my $cell20 =  $sheet->{Cells}[$row][19];
			my $cell21 =  $sheet->{Cells}[$row][20];
			my $cell22 =  $sheet->{Cells}[$row][21];
			my $cell23 =  $sheet->{Cells}[$row][22];
			my $cell24 =  $sheet->{Cells}[$row][23];
			my $cell25 =  $sheet->{Cells}[$row][24];
			my $cell26 =  $sheet->{Cells}[$row][25];

			my %entries = %daten;
			my $i = "1";
			while ( my ($key,$value) = each ( %entries ) ) {
				if ( $value eq "A" ) {
					$entries{"$key"} = $cell1->{Val} || "";
					if ( $cell1->{Val} && $cell1->{Val} eq "0" ) {
						$entries{"$key"} = "0";
					}
					if (Spreadsheet::ParseExcel::Cell->can('value') && $entries{"$key"} && $cell1->{Val} ne "0" && $daten{IP_format} eq "standard" ) {
						$entries{"$key"} = $cell1->value() if $cell1->value();
					}
				} elsif ( $value eq "B" ) {
					$entries{"$key"} = $cell2->{Val} || "";
					if ( $cell2->{Val} && $cell2->{Val} eq "0" ) {
						$entries{"$key"} = "0";
					}
					if ( Spreadsheet::ParseExcel::Cell->can('value') && $entries{"$key"} && $cell2->{Val} ne "0" && $daten{IP_format} eq "standard" ) {
						$entries{"$key"} = $cell2->value() if $cell2->value();
					}
				} elsif ( $value eq "C" ) {
					$entries{"$key"} = $cell3->{Val} || "";
					if ( $cell3->{Val} && $cell3->{Val} eq "0" ) {
						$entries{"$key"} = "0";
					}
					if ( Spreadsheet::ParseExcel::Cell->can('value') && $entries{"$key"} && $cell3->{Val} ne "0" && $daten{IP_format} eq "standard" ) {
						$entries{"$key"} = $cell3->value() if $cell3->value();
					}
				} elsif ( $value eq "D" ) {
					$entries{"$key"} = $cell4->{Val} || "";
					if ( $cell4->{Val} && $cell4->{Val} eq "0" ) {
						$entries{"$key"} = "0";
					}
					if ( Spreadsheet::ParseExcel::Cell->can('value') && $entries{"$key"} && $cell4->{Val} ne "0" && $daten{IP_format} eq "standard" ) {
						$entries{"$key"} = $cell4->value() if $cell4->value();
					}
				} elsif ( $value eq "E" ) {
					$entries{"$key"} = $cell5->{Val} || "";
					if ( $cell5->{Val} && $cell5->{Val} eq "0" ) {
						$entries{"$key"} = "0";
					}
					if ( Spreadsheet::ParseExcel::Cell->can('value') && $entries{"$key"} && $cell5->{Val} ne "0" && $daten{IP_format} eq "standard" ) {
						$entries{"$key"} = $cell5->value() if $cell5->value();
					}
				} elsif ( $value eq "F" ) {
					$entries{"$key"} = $cell6->{Val} || "";
					if ( $cell6->{Val} && $cell6->{Val} eq "0" ) {
						$entries{"$key"} = "0";
					}
					if ( Spreadsheet::ParseExcel::Cell->can('value') && $entries{"$key"} && $cell6->{Val} ne "0" && $daten{IP_format} eq "standard" ) {
						$entries{"$key"} = $cell6->value() if $cell6->value();
					}
				} elsif ( $value eq "G" ) {
					$entries{"$key"} = $cell7->{Val} || "";
					if ( $cell7->{Val} && $cell7->{Val} eq "0" ) {
						$entries{"$key"} = "0";
					}
					if ( Spreadsheet::ParseExcel::Cell->can('value') && $entries{"$key"} && $cell7->{Val} ne "0" && $daten{IP_format} eq "standard" ) {
						$entries{"$key"} = $cell7->value() if $cell7->value();
					}
				} elsif ( $value eq "H" ) {
					$entries{"$key"} = $cell8->{Val} || "";
					if ( $cell8->{Val} && $cell8->{Val} eq "0" ) {
						$entries{"$key"} = "0";
					}
					if ( Spreadsheet::ParseExcel::Cell->can('value') && $entries{"$key"} && $cell8->{Val} ne "0" && $daten{IP_format} eq "standard" ) {
						$entries{"$key"} = $cell8->value() if $cell8->value();
					}
				} elsif ( $value eq "I" ) {
					$entries{"$key"} = $cell9->{Val} || "";
					if ( $cell9->{Val} && $cell9->{Val} eq "0" ) {
						$entries{"$key"} = "0";
					}
					if ( Spreadsheet::ParseExcel::Cell->can('value') && $entries{"$key"} && $cell9->{Val} ne "0" && $daten{IP_format} eq "standard" ) {
						$entries{"$key"} = $cell9->value() if $cell9->value();
					}
				} elsif ( $value eq "J" ) {
					$entries{"$key"} = $cell10->{Val} || "";
					if ( $cell10->{Val} && $cell10->{Val} eq "0" ) {
						$entries{"$key"} = "0";
					}
					if ( Spreadsheet::ParseExcel::Cell->can('value') && $entries{"$key"} && $cell10->{Val} ne "0" && $daten{IP_format} eq "standard" ) {
						$entries{"$key"} = $cell10->value() if $cell10->value();
					}
				} elsif ( $value eq "K" ) {
					$entries{"$key"} = $cell11->{Val} || "";
					if ( $cell11->{Val} && $cell11->{Val} eq "0" ) {
						$entries{"$key"} = "0";
					}
					if ( Spreadsheet::ParseExcel::Cell->can('value') && $entries{"$key"} && $cell11->{Val} ne "0" && $daten{IP_format} eq "standard" ) {
						$entries{"$key"} = $cell11->value() if $cell11->value();
					}
				} elsif ( $value eq "L" ) {
					$entries{"$key"} = $cell12->{Val} || "";
					if ( $cell12->{Val} && $cell12->{Val} eq "0" ) {
						$entries{"$key"} = "0";
					}
					if ( Spreadsheet::ParseExcel::Cell->can('value') && $entries{"$key"} && $cell12->{Val} ne "0" && $daten{IP_format} eq "standard" ) {
						$entries{"$key"} = $cell12->value() if $cell12->value();
					}
				} elsif ( $value eq "M" ) {
					$entries{"$key"} = $cell13->{Val} || "";
					if ( $cell13->{Val} && $cell13->{Val} eq "0" ) {
						$entries{"$key"} = "0";
					}
					if ( Spreadsheet::ParseExcel::Cell->can('value') && $entries{"$key"} && $cell13->{Val} ne "0" && $daten{IP_format} eq "standard" ) {
						$entries{"$key"} = $cell13->value() if $cell13->value();
					}
				} elsif ( $value eq "N" ) {
					$entries{"$key"} = $cell14->{Val} || "";
					if ( $cell14->{Val} && $cell14->{Val} eq "0" ) {
						$entries{"$key"} = "0";
					}
					if ( Spreadsheet::ParseExcel::Cell->can('value') && $entries{"$key"} && $cell14->{Val} ne "0" && $daten{IP_format} eq "standard" ) {
						$entries{"$key"} = $cell14->value() if $cell14->value();
					}
				} elsif ( $value eq "O" ) {
					$entries{"$key"} = $cell15->{Val} || "";
					if ( $cell15->{Val} && $cell15->{Val} eq "0" ) {
						$entries{"$key"} = "0";
					}
					if ( Spreadsheet::ParseExcel::Cell->can('value') && $entries{"$key"} && $cell15->{Val} ne "0" && $daten{IP_format} eq "standard" ) {
						$entries{"$key"} = $cell15->value() if $cell15->value();
					}
				} elsif ( $value eq "P" ) {
					$entries{"$key"} = $cell16->{Val} || "";
					if ( $cell16->{Val} && $cell16->{Val} eq "0" ) {
						$entries{"$key"} = "0";
					}
					if ( Spreadsheet::ParseExcel::Cell->can('value') && $entries{"$key"} && $cell16->{Val} ne "0" && $daten{IP_format} eq "standard" ) {
						$entries{"$key"} = $cell16->value() if $cell16->value();
					}
				} elsif ( $value eq "Q" ) {
					$entries{"$key"} = $cell17->{Val} || "";
					if ( $cell17->{Val} && $cell17->{Val} eq "0" ) {
						$entries{"$key"} = "0";
					}
					if ( Spreadsheet::ParseExcel::Cell->can('value') && $entries{"$key"} && $cell17->{Val} ne "0" && $daten{IP_format} eq "standard" ) {
						$entries{"$key"} = $cell17->value() if $cell17->value();
					}
				} elsif ( $value eq "R" ) {
					$entries{"$key"} = $cell18->{Val} || "";
					if ( $cell18->{Val} && $cell18->{Val} eq "0" ) {
						$entries{"$key"} = "0";
					}
					if ( Spreadsheet::ParseExcel::Cell->can('value') && $entries{"$key"} && $cell18->{Val} ne "0" && $daten{IP_format} eq "standard" ) {
						$entries{"$key"} = $cell18->value() if $cell18->value();
					}
				} elsif ( $value eq "S" ) {
					$entries{"$key"} = $cell19->{Val} || "";
					if ( $cell19->{Val} && $cell19->{Val} eq "0" ) {
						$entries{"$key"} = "0";
					}
					if ( Spreadsheet::ParseExcel::Cell->can('value') && $entries{"$key"} && $cell19->{Val} ne "0" && $daten{IP_format} eq "standard" ) {
						$entries{"$key"} = $cell19->value() if $cell19->value();
					}
				} elsif ( $value eq "T" ) {
					$entries{"$key"} = $cell20->{Val} || "";
					if ( $cell20->{Val} && $cell20->{Val} eq "0" ) {
						$entries{"$key"} = "0";
					}
					if ( Spreadsheet::ParseExcel::Cell->can('value') && $entries{"$key"} && $cell20->{Val} ne "0" && $daten{IP_format} eq "standard" ) {
						$entries{"$key"} = $cell20->value() if $cell20->value();
					}
				} elsif ( $value eq "U" ) {
					$entries{"$key"} = $cell21->{Val} || "";
					if ( $cell21->{Val} && $cell21->{Val} eq "0" ) {
						$entries{"$key"} = "0";
					}
					if ( Spreadsheet::ParseExcel::Cell->can('value') && $entries{"$key"} && $cell21->{Val} ne "0" && $daten{IP_format} eq "standard" ) {
						$entries{"$key"} = $cell21->value() if $cell21->value();
					}
				} elsif ( $value eq "V" ) {
					$entries{"$key"} = $cell22->{Val} || "";
					if ( $cell22->{Val} && $cell22->{Val} eq "0" ) {
						$entries{"$key"} = "0";
					}
					if ( Spreadsheet::ParseExcel::Cell->can('value') && $entries{"$key"} && $cell22->{Val} ne "0" && $daten{IP_format} eq "standard" ) {
						$entries{"$key"} = $cell22->value() if $cell22->value();
					}
				} elsif ( $value eq "W" ) {
					$entries{"$key"} = $cell23->{Val} || "";
					if ( $cell23->{Val} && $cell23->{Val} eq "0" ) {
						$entries{"$key"} = "0";
					}
					if ( Spreadsheet::ParseExcel::Cell->can('value') && $entries{"$key"} && $cell23->{Val} ne "0" && $daten{IP_format} eq "standard" ) {
						$entries{"$key"} = $cell23->value() if $cell23->value();
					}
				} elsif ( $value eq "X" ) {
					$entries{"$key"} = $cell24->{Val} || "";
					if ( $cell24->{Val} && $cell24->{Val} eq "0" ) {
						$entries{"$key"} = "0";
					}
					if ( Spreadsheet::ParseExcel::Cell->can('value') && $entries{"$key"} && $cell24->{Val} ne "0" && $daten{IP_format} eq "standard" ) {
						$entries{"$key"} = $cell24->value() if $cell24->value();
					}
				} elsif ( $value eq "Y" ) {
					$entries{"$key"} = $cell25->{Val} || "";
					if ( $cell25->{Val} && $cell25->{Val} eq "0" ) {
						$entries{"$key"} = "0";
					}
					if ( Spreadsheet::ParseExcel::Cell->can('value') && $entries{"$key"} && $cell25->{Val} ne "0" && $daten{IP_format} eq "standard" ) {
						$entries{"$key"} = $cell25->value() if $cell25->value();
					}
				} elsif ( $value eq "Z" ) {
					$entries{"$key"} = $cell26->{Val} || "";
					if ( $cell26->{Val} && $cell26->{Val} eq "0" ) {
						$entries{"$key"} = "0";
					}
					if ( Spreadsheet::ParseExcel::Cell->can('value') && $entries{"$key"} && $cell26->{Val} ne "0" && $daten{IP_format} eq "standard" ) {
						$entries{"$key"} = $cell26->value() if $cell26->value();
					}
				}
			}


			# Check IP format
			if ( ! $entries{ip} ) {
				next;
			}
			$entries{ip} =~ s/[\s\t\n]+//g;

			if ( $daten{'IP_format'} eq "standard" ) {
				if ( $entries{ip} =~ /^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})$/ ) {
					$ip_version = "v4";
				} elsif ( $entries{ip} =~ /^((?=.*::.*)(::)?([0-9A-F]{1,4}(:(?=[0-9A-F])|(?!\2)(?!\5)(::)|\z)){0,7}|((?=.*::.*)(::)?([0-9A-F]{1,4}(:(?=[0-9A-F])|(?!\7)(?!\10)(::))){0,5}|([0-9A-F]{1,4}:){6})((25[0-5]|(2[0-4]|1[0-9]|[1-9]?)[0-9])(\.(?=.)|\z)){4}|([0-9A-F]{1,4}:){7}[0-9A-F]{1,4})$/i ) {
					$ip_version = "v6";
				} else {
					if ( $vars_file =~ /vars_he$/ ) {
						print "<span style=\"float: $ori\">$$lang_vars{ignorado_message} - $entries{ip} :$$lang_vars{ip_invalido_message}</span><br>\n";
					} else {
						print "$$lang_vars{ip_invalido_message}: $entries{ip} - $$lang_vars{ignorado_message}<br>\n";
					}
					next;
				}
			} elsif ( $daten{'IP_format'} eq "last_oct" ) {
				if ( $ip_version eq "v4" ) {
					if ( $entries{ip} !~ /^(\.)?\d{1,3}$/ ) {
						if ( $vars_file =~ /vars_he$/ ) {
							print "<span style=\"float: $ori\">$$lang_vars{ignorado_message} - $entries{ip} :$$lang_vars{ip_invalido_message}</span><br>\n";
						} else {
							print "$$lang_vars{ip_invalido_message}: $entries{ip} - $$lang_vars{ignorado_message}<br>\n";
						}	
						next;
					}
					$entries{ip} =~ s/^\.//g;
					$entries{ip} = $last_oct_net . "." . $entries{ip};
				} elsif ( $ip_version eq "v6" ) {
					if ( $entries{ip} !~ /^(\:)?[0-9,abcdef]{1,4}$/ ) {
						if ( $vars_file =~ /vars_he$/ ) {
							print "<span style=\"float: $ori\">$$lang_vars{ignorado_message} - $entries{ip} :$$lang_vars{ip_invalido_message}</span><br>\n";
						} else {
							print "$$lang_vars{ip_invalido_message}: $entries{ip} - $$lang_vars{ignorado_message}<br>\n";
						}
						next;
					}
					$entries{ip} =~ s/^\://g;
					$entries{ip} = $last_oct_net . ":" . $entries{ip};
				}
			}


			# Adapt hostname format
			if ( ! $entries{hostname} ) {
				if ( $vars_file =~ /vars_he$/ ) {
					print "<span style=\"float: $ori\">$$lang_vars{ignorado_message} - $$lang_vars{no_hostname_sheet_message} - <b>$entries{ip}</b></span><br>\n";
				} else {
					print "<b>$entries{ip}</b> - $$lang_vars{no_hostname_sheet_message} - $$lang_vars{ignorado_message}<br>\n";
				}
				next;
			}
			$entries{hostname} =~ s/^(.{2,75}).*/$1/;
			$entries{hostname} =~ s/[\s\t\n]+/_/g;


			# Check if IP is valid
			my $valid_ip = "0";
			my $check_BM="32";
			$check_BM="128" if $ip_version eq "v6";
			my $redob = "$entries{ip}/$check_BM";
			my $ipob_red = new Net::IP ($redob) or $valid_ip = "1";
			if ( $valid_ip == "1" ) {
				if ( $vars_file =~ /vars_he$/ ) {
					print "<span style=\"float: $ori\">$$lang_vars{ignorado_message} -  $$lang_vars{ip_invalido_message} - <b>$entries{ip}</b></span><br>";
				} else {
					print "<b>$entries{ip}</b> - $$lang_vars{ip_invalido_message} - $$lang_vars{ignorado_message}<br>";
				}
				next;
			} else {
				$host_found = "0";
			}

			my $ip_int = ($ipob_red->intip());
			$ip_int = Math::BigInt->new("$ip_int");

			# check for unallowed characters
			foreach my $key( keys %entries ) {
				if ( $key eq "URL" ) {
					$entries{$key} =~ s/;/,/g;
					$entries{$key} =~ s/['<>\\*#%\^\`\$*]/_/g;
				} else {
					$entries{$key} =~ s/['<>\\\/*&#%\^\`=\$*]/_/g;
				}
				
				my $converted=encode("UTF-8",$entries{$key}); 
				$entries{$key} = $converted;

				$converted =~ s/['=?_\.,:\-\@()\w\/\[\]{}|~\+\n\r\f\t\s]//g;
				my $hex = join('', map { sprintf('%X', ord $_) } split('', "$converted"));
				my @hex_ar=split(' ',$converted); 

				foreach (@hex_ar) {
						if ( $_ !~ /^[${allowd}]+$/i && $hex =~ /.+/) {
						if ( $vars_file =~ /vars_he$/ ) {
							print "<span style=\"float: $ori\">$$lang_vars{ignorado_message} $key - $$lang_vars{caracter_no_permitido_encontrado_message} :$key :<b>$entries{ip}/$entries{hostname}</b></span><br>\n";
						} else {
							print "<b>$entries{ip}/$entries{hostname}</b>: $key: $$lang_vars{caracter_no_permitido_encontrado_message} - $key $$lang_vars{ignorado_message}<br>\n";
						}
						$entries{$key} ="";
						last;
					}
				}
			}

			next if ! $entries{hostname};

			$mydatetime = time();

			if ( $firstfound = "1" && $ip_int >= $first_ip_int && $ip_int <= $last_ip_int) {

#### PRINT

				if ( $ip_int == "$first_ip_int" ) {
					if ( $vars_file =~ /vars_he$/ ) {
						print "<span style=\"float: $ori\">$$lang_vars{ignorado_message} - $$lang_vars{import_network_address_message} - $entries{hostname} :<b>$entries{ip}</b></span><br>\n";
					} else {
						print "<b>$entries{ip}</b>: $entries{hostname} - $$lang_vars{import_network_address_message} - $$lang_vars{ignorado_message}<br>\n";
					}
					$to_ignore="1";
				} elsif ( $ip_int == "$last_ip_int" ) {
					if ( $vars_file =~ /vars_he$/ ) {
						print "<span style=\"float: $ori\">$$lang_vars{ignorado_message} - $$lang_vars{import_broadcast_address_message} - $entries{hostname} :<b>$entries{ip}</b></span><br>";
					} else {
						print "<b>$entries{ip}</b>: $entries{hostname} - $$lang_vars{import_broadcast_address_message} - $$lang_vars{ignorado_message}";
					}
					$to_ignore="1";
				} else {
					$host_descr = $entries{descr} || "NULL";
					$red_num = $values_host_redes[$last_k]->[2];
					$gip->print_error("$client_id","$$lang_vars{algo_malo_message}") if ! $red_num;
				}
			} else {
				$k = 0;
				$last_k = "";
				my $net_found = "1";
				foreach ( @values_host_redes ) {
					if ( ! $values_host_redes[$k]->[0] ) {
						$k++;
						next;
					}
					if ( $values_host_redes[$k]->[5] == 1 ) {
						$k++;
						next;
					}

					my $ip_version_checkred = $values_host_redes[$k]->[4];

					if ( $ip_version ne $ip_version_checkred ) {
						$k++;
						next;
					}

					$host_red = $values_host_redes[$k]->[0];
					$host_red_bm = $values_host_redes[$k]->[1];
					$red_num = $values_host_redes[$k]->[2];

					$redob_redes = "$host_red/$host_red_bm";
					$ipob_redes = new Net::IP ($redob_redes) or $gip->print_error("$client_id","$$lang_vars{algo_malo_message}");
					$last_ip_int = ($ipob_redes->last_int());
					$last_ip_int = Math::BigInt->new("$last_ip_int");
					$first_ip_int = ($ipob_redes->intip());
					$first_ip_int = Math::BigInt->new("$first_ip_int");


					if ( $ip_version eq "v4" ) {
						$host_red =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})/;
						my $third_host_red_oct=$3;
						$entries{ip} =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})/;
						my $third_host_oct=$3;
						if ( $k + 1 != $anz_values_host_redes && ( $host_red_bm >= 24 && $third_host_red_oct != $third_host_oct ) ) {
							$k++;
							next;
						}
					}

					if ( $k + 1 == $anz_values_host_redes && ( $ip_int < $first_ip_int || $ip_int > $last_ip_int ) ) {
						if ( $vars_file =~ /vars_he$/ ) {
							print "<span style=\"float: $ori\">$$lang_vars{ignorado_message} - $$lang_vars{import_no_red_message} :<b>$entries{ip}</b></span><br>\n";
						} else {
							print "<b>$entries{ip}</b>: $$lang_vars{import_no_red_message} - $$lang_vars{ignorado_message}<br>\n";
						}
						$to_ignore="1";
						next;
					}

					if ( $ip_int < $first_ip_int || $ip_int > $last_ip_int ) {
						$k++;
						next;
					}

# PRINT
#					print "<b>$entries{ip}</b>: $entries{hostname} ";

					if ( $ip_int == "$first_ip_int" ) {
						if ( $vars_file =~ /vars_he$/ ) {
							print "<span style=\"float: $ori\">$$lang_vars{ignorado_message} - $$lang_vars{import_network_address_message} - $entries{hostname} :<b>$entries{ip}</b></span><br>\n";
						} else {
							print "<b>$entries{ip}</b>: $entries{hostname}  - $$lang_vars{import_network_address_message} - $$lang_vars{ignorado_message}<br>\n";
						}
						$last_k = $k;
						$to_ignore="1";
						last;
					} elsif ( $ip_int == "$last_ip_int" ) {
						if ( $vars_file =~ /vars_he$/ ) {
							print "<span style=\"float: $ori\">$$lang_vars{ignorado_message} - $$lang_vars{import_broadcast_address_message} - $entries{hostname} :<b>$entries{ip}</b></span><br>\n";
						} else {
							print "<b>$entries{ip}</b>: $entries{hostname} - $$lang_vars{import_broadcast_address_message} - $$lang_vars{ignorado_message}<br>\n";
						}
						$last_k = $k;
						$to_ignore="1";
						last;
					}
					$net_found = "0";

					$host_descr = $entries{descr} || "NULL";
					$red_num = $values_host_redes[$k]->[2];
					$gip->print_error("$client_id","$$lang_vars{algo_malo_message}") if ! $red_num;
					$last_k = $k;
					last;
				}
			}
			$firstfound = "1";
			next if $to_ignore == 1;

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
				$cat_id=$gip->get_cat_from_id("$client_id","$entries{cat}");
				if (  ! $cat_id ) {
					$cat_id="-1";
					$entries{cat} = "";
				}
			} else {
				$cat_id = "-1";
			}
		
			$entries{comentario} = "NULL" if ! $entries{comentario};
			

			# insert or update host

			my $host_updated="1";
			my @ch=$gip->get_host("$client_id","$ip_int","$ip_int");
			if ( $ch[0]->[0] ) {
				my $alive = $ch[0]->[8] || "-1";
				my $descr_db = $ch[0]->[2] || "";
				$int_admin = $ch[0]->[5] || "n";
				if ( $cat_id == "-1" ) {
					my $cat = $ch[0]->[4];
					$cat_id = $gip->get_cat_from_id("$client_id","$cat");
					$cat_id = "-1" if ! $cat_id || $cat_id eq "NULL";
				}
				if ( $loc_id == "-1" ) {
					my $loc = $ch[0]->[3];
					$loc_id = $gip->get_loc_from_id("$client_id","$loc");
					$loc_id = "-1" if ! $loc_id || $loc_id eq "NULL";
				}
				my $comentario = "";
				my $comentario_db = $ch[0]->[6] || "";
				if ( $descr_db =~ /$host_descr/ ) {
					$host_descr=$descr_db;
				} else {
					$host_descr = $descr_db . " " . $host_descr if $descr_db;
				}
				if ( $comentario_db =~ /$entries{comentario}/ ) {
					$comentario = $comentario_db;
				} elsif ( ! $comentario_db ) {
					$comentario = $entries{comentario} || "";
				} else {
					$comentario = $comentario_db . " " . $entries{comentario} if $comentario_db;
				}
				$comentario =~ s/NULL//g if $comentario;
				$host_descr =~ s/NULL//g if $host_descr;
				$gip->update_ip_mod("$client_id","$ip_int","$entries{hostname}","$host_descr","$loc_id","$int_admin","$cat_id","$comentario","$utype_id","$mydatetime","$red_num","$alive","$ip_version");
			} else {
				my $comentario = $entries{comentario};
				$comentario =~ s/NULL//g;
				$host_descr =~ s/NULL//g;
				$cat_id  = "-1" if ! $cat_id || $cat_id eq "NULL";
				$loc_id  = "-1" if ! $loc_id || $loc_id eq "NULL";
				$gip->insert_ip_mod("$client_id","$ip_int","$entries{hostname}","$host_descr","$loc_id","$int_admin","$cat_id","$comentario","$utype_id","$mydatetime","$red_num",'-1',"$ip_version");
				$host_updated="2";
			}


			my $host_id = $gip->get_host_id_from_ip_int("$client_id","$ip_int");

                        for ( my $k = 0; $k < scalar(@cc_values); $k++ ) {
                                if ( $entries{"$cc_values[$k]->[0]"} ) {
                                        my $cc_name="$cc_values[$k]->[0]";
                                        my $cc_value=$entries{"$cc_values[$k]->[0]"};
                                        my $cc_id="$cc_values[$k]->[1]";
                                        my $pc_id="$cc_values[$k]->[3]";
#                                        print ", $cc_value";

                                        my $cc_entry=$gip->get_custom_host_column_entry("$client_id","$host_id","$cc_name") || "";
                                        if ( $cc_entry ) {
                                                $gip->update_custom_host_column_value_host("$client_id","$cc_id","$host_id","$cc_value");
                                        } else {
                                                $gip->insert_custom_host_column_value_host("$client_id","$cc_id","$pc_id","$host_id","$cc_value");
                                        }
                                }
                        }

			if ( $host_updated =="1" ) {
				if ( $vars_file =~ /vars_he$/ ) {
					print "<span style=\"float: $ori\">$$lang_vars{host_actualizado_message} - $entries{hostname} :<b>$entries{ip}</b></span><br>\n";
				} else {
					print "<b>$entries{ip}</b>: $entries{hostname} - $$lang_vars{host_actualizado_message}<br>\n";
				}
			} else {
				if ( $vars_file =~ /vars_he$/ ) {
					print "<span style=\"float: $ori\">$$lang_vars{host_anadido_message} - $entries{hostname} :<b>$entries{ip}</b></span><br>\n";
				} else {
					print "<b>$entries{ip}</b>: $entries{hostname} - $$lang_vars{host_anadido_message}<br>\n";
				}
			}


			my $audit_type;
			if ( $ch[0]->[0] ) {
				$audit_type = 1;
			} else {
				$audit_type = 15;
			}
			my $audit_class="1";
			my $update_type_audit="10";
			$entries{descr}="---" if $entries{descr} eq "NULL";
			$entries{comentario}="---" if $entries{comentario} eq "NULL";
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

			my $event="$entries{ip}/$entries{hostname},$entries{descr},$loc_audit,$cat_audit,$entries{comentario},'n'";
			$gip->insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");
		}
	}
	$j++;
}

print "</span>\n";


if ( $sheet_found == "1" ) {
	$gip->print_error("$client_id","$$lang_vars{no_sheet_message} \"$excel_sheet_name\"<p>$$lang_vars{comprueba_formulario_message}");
}

if ( $host_found == "1" ) {
	$gip->print_error("$client_id","$$lang_vars{no_hosts_message}");
}

print "<h3 style=\"float: $ori\">$$lang_vars{listo_message}</h3><br><p><br>\n";

$gip->print_end("$client_id","$vars_file","go_to_top");
