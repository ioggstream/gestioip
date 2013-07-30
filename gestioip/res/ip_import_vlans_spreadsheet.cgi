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
        $gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{import_vlans_from_spreadsheet_message}","$vars_file");
        $gip->print_error("$client_id","$$lang_vars{formato_malo_message}");
}

$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{import_vlans_from_spreadsheet_message}","$vars_file");

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
	$gip->print_error("$client_id","$$lang_vars{no_spreadsheet_message} \"$spreadsheet\"<p>$$lang_vars{no_vlan_spreadsheet_explic_message} \"$spreadsheet\"");
}
if ( ! -r $excel_file_name ) {
	$gip->print_error("$client_id","$$lang_vars{spreadsheet_no_readable_message} \"$excel_file_name\"<p>$$lang_vars{check_permissions_message}");
}

#$daten{IP_format}="standard" if $ip_version eq "v6";

$gip->print_error("$client_id","$$lang_vars{hoja_and_first_sheets_message}") if ( $daten{'hoja'} && $daten{'some_sheet_values'} );
$gip->print_error("$client_id","$$lang_vars{hoja_and_first_sheets_message}") if ( $daten{'one_sheet'} && $daten{'sheet_import_type'} ne "one_sheet" );
$gip->print_error("$client_id","$$lang_vars{hoja_and_first_sheets_message}") if ( $daten{'some_sheet_values'} && $daten{'sheet_import_type'} ne "some_sheet" );
$gip->print_error("$client_id","$$lang_vars{hoja_and_first_sheets_message}") if ( ( $daten{'hoja'} || $daten{'some_sheet_values'} ) && $daten{'sheet_import_type'} eq "all_sheet" );

my $allowd = $gip->get_allowed_characters();

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

my %vlan_provider=$gip->get_vlan_providers_hash_key_name("$client_id");

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


if ( ! $daten{'vlan_id'} ) {
#TEST........
	$gip->print_error("$client_id","$$lang_vars{elige_columna_vlan_num_message}");
} elsif ( ! $daten{'vlan_name'} ) {
#TEST........
	$gip->print_error("$client_id","$$lang_vars{introduce_columna_vlan_names_message}");
}
	

if ( $daten{vlan_id} && $daten{vlan_id} !~ /^\w{1}$/ ) { $gip->print_error("$client_id","$$lang_vars{formato_malo_message}: $daten{vlan_id}") };
if ( $daten{vlan_name} && $daten{vlan_name} !~ /^\w{1}$/ ) { $gip->print_error("$client_id",$$lang_vars{formato_malo_message}) };
if ( $daten{descr} && $daten{descr} !~ /^\w{1}$/ ) { $gip->print_error("$client_id",$$lang_vars{formato_malo_message}) };
if ( $daten{provider} && $daten{provider} !~ /^\w{1}$/ ) { $gip->print_error("$client_id",$$lang_vars{formato_malo_message}) };
if ( $daten{network} && $daten{network} !~ /^\w{1}$/ ) { $gip->print_error("$client_id",$$lang_vars{formato_malo_message}) };


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
$gip->print_error("$client_id","$$lang_vars{palabra_reservada_comment_NULL_message}") if $daten{'descr'} eq "NULL";
my $vigilada=$daten{'vigilada'} || "n";

my @vlans=$gip->get_vlans_with_asso_vlans("$client_id");
my %vlan_hash=$gip->get_asso_vlan_hash("$client_id");

my ($row_new, $last_k,$vlan_descr,$mydatetime,$k,$to_ignore);
my $excel = Spreadsheet::ParseExcel::Workbook->Parse($excel_file_name);
my $sheet_found=1;
my $vlan_found="1";
my $firstfound = "0";
my $j = "1";

my $ip_version;
print "<span class=\"sinc_text\"><p>";
foreach my $sheet (@{$excel->{Worksheet}}) {
	if (( $sheet->{Name} eq "$excel_sheet_name" && $daten{'hoja'} && $daten{'sheet_import_type'} eq "one_sheet" ) || ( $daten{'sheet_import_type'} eq "all_sheet" && ! $daten{'hoja'} && ! $daten{'some_sheet_values'} ) || ( $daten{'sheet_import_type'} eq "some_sheet" && $j =~ /^($import_sheet_numbers)$/ )) {
		$sheet_found=0;
		print "<p><b><i>Sheet: $sheet->{Name}</i></b>\n";

		if ( ! defined($sheet->{MaxRow}) || ! defined($sheet->{MinRow}) ) {
			print "  - $$lang_vars{empty_sheet_message}<p>\n";
			$j++;
			next;
		}

		print "<p>\n";

		$sheet->{MaxRow} ||= $sheet->{MinRow};

		foreach my $row ($sheet->{MinRow} .. $sheet->{MaxRow}) {
			$to_ignore = "0";
			$sheet->{MaxCol} ||= $sheet->{MinCol};

                        my %entries = %daten;
                        foreach my $key ( keys %entries ) {
                                if ( $entries{$key} =~ /^[A-M]$/ && defined $sheet->{Cells}[$row][ord($entries{$key})-ord('A')]) {
                                        $entries{$key} = $sheet->{Cells}[$row][ord($entries{$key})-ord('A')]->value();
                                        $entries{$key} = '' unless defined $entries{$key};
                                } else {
					$entries{$key} = ''
				}
                        }

			# Check IP format
			if ( ! $entries{vlan_id} ) {
				next;
			}
			$entries{vlan_id} =~ s/[\s\t\n]+//g;
			my $vlan_id=$entries{vlan_id};
			if ( $vlan_id !~ /^\d{1,10}$/ ) {
				print "$$lang_vars{invalid_vlan_id}: $entries{vlan_id} - $$lang_vars{ignorado_message}<br>\n";
				next;
			}
				
			# check for vlan_name
			if ( ! $entries{vlan_name} ) {
				print "$$lang_vars{no_vlan_name_sheet_message} - $$lang_vars{ignorado_message}<br>\n";
				next;
			}
			$entries{vlan_name} =~ s/^(.{2,45}).*/$1/;
			$entries{vlan_name} =~ s/\s+/_/g;
			my $vlan_name=$entries{vlan_name};

			$vlan_found=0;

			# check for unallowed characters
			foreach my $key( keys %entries ) {
				$entries{$key} =~ s/['<>\\\/*&#%\^\`=\$*]/_/g;
				my $converted=encode("UTF-8",$entries{$key}); 
				$entries{$key} = $converted;

				$converted =~ s/['=?_\.,:\-\@()\w\/\[\]{}|~\+\s]//g;
				if ( $converted !~ /^[${allowd}]+$/i && length($converted) > 0) {
					print "<b>$entries{vlan_id} - $entries{vlan_name}</b>: $key: $$lang_vars{caracter_no_permitido_encontrado_message} - $key $$lang_vars{ignorado_message}<br>\n";
					$entries{$key} = '';
				}
			}


#TEST $firstfound

			print "<b>$entries{vlan_id}</b>: $entries{vlan_name} ";


			$vlan_descr = $entries{descr} || "NULL";
			$mydatetime = time();


			$firstfound = "1";
			next if $to_ignore == 1;

			$entries{descr} = "NULL" if ! $entries{descr};
			

			# insert or update vlan

			my $vlan_updated="1";


			# check if VLAN is already in the database
			my $vlan_exists=0;
			foreach ( @vlans ) {
				if ($_->[1] eq $vlan_id && $_->[2] eq $vlan_name ) {
					print "$$lang_vars{vlan_exists_message} - $$lang_vars{ignorado_message}<br>\n";
					$vlan_exists=1;
					last;
				}
			}
			next if $vlan_exists == 1; 

			#Add VLAN to @vlans for exists-check of next rounds
			my $vlan_arr_index=scalar(@vlans);
			$vlans[$vlan_arr_index]->[1]=$vlan_id;
			$vlans[$vlan_arr_index]->[2]=$vlan_name;

#if ( VLAN_EXISTS_IN_THE_DATABASE ) {
#				my $descr = "";
#				my $descr_db = $ch[0]->[6] || "";
#				if ( $descr_db =~ /$vlan_descr/ ) {
#					$vlan_descr=$descr_db;
#				} else {
#					$vlan_descr = $descr_db . " " . $vlan_descr if $descr_db;
#				}
#				if ( $descr_db =~ /$entries{descr}/ ) {
#					$descr = $descr_db;
#				} else {
#					$descr = $descr_db . " " . $entries{descr} if $descr_db;
#				}
#				$descr =~ s/NULL//g if $descr;
#				$vlan_descr =~ s/NULL//g if $vlan_descr;
#				$gip->update_ip_mod("$client_id","$ip_int","$entries{vlan_name}","$vlan_descr","$loc_id","$int_admin","$cat_id","$descr","$utype_id","$mydatetime","$red_num","$alive","$ip_version");
#			} else {
				my $descr = $entries{descr};
				$descr =~ s/NULL//g;
				$vlan_descr =~ s/NULL//g;


				my $provider = $entries{provider} || "";
				my $provider_id="-1";
				if ( $provider ) {
					$provider_id=$vlan_provider{"$provider"} || "-1";
				}

				$gip->insert_vlan("$client_id","$entries{vlan_id}","$entries{vlan_name}","$descr","$provider_id","black","white","");
				$vlan_updated="2";
#			}



			if ( $vlan_updated =="1" ) {
				print " - $$lang_vars{vlan_modificado_message}<br>\n";
			} else {
				print " - $$lang_vars{vlan_added_message}<br>\n";
			}


			my $audit_type;
#			if ( $ch[0]->[0] ) {
#				$audit_type = 38;
#			} else {
				$audit_type = 36;
#			}
			my $audit_class="7";
			my $update_type_audit="12";
			$entries{descr}="---" if $entries{descr} eq "NULL";

			my $event="$entries{vlan_id}, $entries{vlan_name}, $entries{descr}";
			$gip->insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");
		}
	}
	$j++;
}

print "</span>\n";


if ( $sheet_found == "1" ) {
	$gip->print_error("$client_id","$$lang_vars{no_sheet_message} \"$excel_sheet_name\"<p>$$lang_vars{comprueba_formulario_message}");
}

if ( $vlan_found == "1" ) {
	$gip->print_error("$client_id","$$lang_vars{no_vlans_message}");
}

print "<h3>$$lang_vars{listo_message}</h3>\n";

$gip->print_end("$client_id","$vars_file","go_to_top");
