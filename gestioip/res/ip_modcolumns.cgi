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
use lib '../modules';
use GestioIP;

my $daten=<STDIN>;
my $gip = GestioIP -> new();
my %daten=$gip->preparer($daten);

my $base_uri = $gip->get_base_uri();
my $server_proto=$gip->get_server_proto();

my $lang = $daten{'lang'} || "";
my ($lang_vars,$vars_file)=$gip->get_lang("","$lang");

my $client_id = $daten{'client_id'} || $gip->get_first_client_id();

my $management_type=$daten{manage_type} || "";

my ($ce_id,$ce_host_id);
my ($which_clients,$custom_column,$custom_host_column );
$which_clients = $daten{which_clients} || "9999";
if ( $which_clients !~ /^\d{1,4}/ ) {
	$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{manage_custom_columns_message}","$vars_file");
	$gip->print_error("$client_id","$$lang_vars{formato_malo_message}");
}

my $align="align=\"right\"";
my $align1="";
my $ori="left";
if ( $vars_file =~ /vars_he$/ ) {
	$align="align=\"left\"";
	$align1="align=\"right\"";
	$ori="right";
}


if ( $management_type eq "insert_cc" || $management_type eq "insert_cc_custom" ) {
	$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{manage_custom_columns_message}: $$lang_vars{cc_added_message}","$vars_file");
	$gip->print_error("$client_id","$$lang_vars{insert_cc_name_message}") if $management_type eq "insert_cc_custom" && ! $daten{'custom_column'};
	my %cc=$gip->get_custom_columns_hash_client_all("$client_id");
	$custom_column = $daten{'custom_column'};
	$custom_column =~ s/^\++//;
	$custom_column =~ s/\s+$//;
	$custom_column =~ s/[.?]/_/g;
	if ( ! $custom_column && $daten{'ce_id'} ) {
		$ce_id = $daten{'ce_id'};
		$gip->print_error("$client_id","$$lang_vars{mal_signo_error_message}") if $ce_id !~ /^\d{1,4}$/;
		$custom_column=$gip->get_predef_column_name("$client_id","$ce_id");
	}
	$gip->print_error("$client_id","<i>$custom_column</i>: $$lang_vars{cc_exists_message}: $custom_column") if defined($cc{"$custom_column"}) && $which_clients ne "9999"; 

} elsif ( $management_type eq "insert_host_cc" || $management_type eq "insert_host_cc_custom" ) {
	$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{manage_custom_columns_message}: $$lang_vars{cc_added_message}","$vars_file");
	$gip->print_error("$client_id","$$lang_vars{insert_cc_name_message}") if $management_type eq "insert_host_cc_custom" && ! $daten{'custom_host_column'};
	my %cc_host=$gip->get_custom_host_columns_hash_client_all("$client_id");
	$custom_host_column = $daten{'custom_host_column'};
	if ( ! $custom_host_column && $daten{'ce_host_id'} ) {
		$ce_host_id = $daten{'ce_host_id'};
		$gip->print_error("$client_id","$$lang_vars{mal_signo_error_message}") if $ce_host_id !~ /^\d{1,4}$/;
		$custom_host_column=$gip->get_predef_host_column_name("$client_id","$ce_host_id");
	}
	$gip->print_error("$client_id","<i>$custom_host_column</i>: $$lang_vars{cc_exists_message}") if defined($cc_host{"$custom_host_column"}) && $which_clients ne "9999"; 

} elsif ( $management_type eq "delete_cc" || $management_type eq "delete_host_cc" ) {
	$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{manage_custom_columns_message}: $$lang_vars{cc_deleted_message}","$vars_file");
} else {
	$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{manage_custom_columns_message}","$vars_file");
}


my @clients = $gip->get_clients();
my @cc_values=$gip->get_custom_columns("$client_id");
my @ce_values=$gip->get_predef_columns_all("$client_id");
my @cc_host_values=$gip->get_custom_host_columns("$client_id");
my @ce_host_values=$gip->get_predef_host_columns_all("$client_id");
my $client_name=$gip->get_client_from_id("$client_id");
my $anz_clients_all=$gip->count_clients("$client_id");

my $event="";
my $event_new="";


print "<p>\n";

if ( $management_type eq "insert_cc" ) {
	my $last_custom_column_id=$gip->get_last_custom_column_id("$client_id");
	$last_custom_column_id++;
	$ce_id = '-1' if ! $ce_id;
	if ( $which_clients eq "9999" ) {
		my @ids_to_change=$gip->get_custom_column_ids_from_name("$client_id","$custom_column");
		foreach ( @ids_to_change ) {
			$gip->change_custom_column_entry_cc_id("$client_id","$_->[0]","$last_custom_column_id");
		}
		$gip->delete_custom_column_from_name("$client_id","$custom_column");
	}
	my $insert_ok=$gip->insert_custom_column("$which_clients","$last_custom_column_id","$custom_column","$ce_id");

	my $audit_type="31";
	my $audit_class="5";
	my $update_type_audit="1";
	my $audit_which_clients=$$lang_vars{actual_client_message};
	$audit_which_clients=$$lang_vars{all_clients_message} if $client_id == "9999";
	my $event="$custom_column ($audit_which_clients)";
	$gip->insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");

	@cc_values=$gip->get_custom_columns("$client_id");
	@ce_values=$gip->get_predef_columns_all("$client_id");

} elsif ( $management_type eq "insert_cc_custom" ) {
	my $last_custom_column_id=$gip->get_last_custom_column_id("$client_id");
	$last_custom_column_id++;
	$ce_id = '-1' if ! $ce_id;

	@ce_values=$gip->get_predef_columns_all("$client_id");
	my $j="0";
	foreach ( @ce_values ) {
		if ( "$custom_column" eq "$ce_values[$j]->[1]" ) {
			$gip->print_error("$client_id","$$lang_vars{ce_name_exists_message}: $custom_column");
		}
		$j++;
	}
	@cc_values=$gip->get_custom_columns("$client_id");
	$j="0";
	foreach ( @cc_values ) {
		if ( "$custom_column" eq "$cc_values[$j]->[0]" && ( "$cc_values[$j]->[2]" eq $client_id || "$cc_values[$j]->[2]" eq "9999" ) ) {
			$gip->print_error("$client_id","$$lang_vars{cc_name_exists_message}: $custom_column");
		}
		$j++;
	}

	if ( $which_clients eq "9999" ) {
		my @ids_to_change=$gip->get_custom_column_ids_from_name("$client_id","$custom_column");
		foreach ( @ids_to_change ) {
			$gip->change_custom_column_entry_cc_id("$client_id","$_->[0]","$last_custom_column_id");
		}
		$gip->delete_custom_column_from_name("$client_id","$custom_column");
	}

	my $insert_ok=$gip->insert_custom_column("$which_clients","$last_custom_column_id","$custom_column","$ce_id");

	my $audit_type="31";
	my $audit_class="5";
	my $update_type_audit="1";
	my $audit_which_clients=$$lang_vars{actual_client_message};
	$audit_which_clients=$$lang_vars{all_clients_message} if $client_id == "9999";
	my $event="$custom_column ($audit_which_clients)";
	$gip->insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");

	@cc_values=$gip->get_custom_columns("$client_id");

} elsif ( $management_type eq "delete_cc" ) {
	my $cc_id = $daten{'cc_id'};
	my $cc_name=$gip->get_custom_column_name("$client_id","$cc_id");
	my $cc_client_id=$gip->get_custom_column_client_id("$client_id","$cc_id");
	my $delete_ok=$gip->delete_custom_column("$client_id","$cc_id");
	my @clients = $gip->get_clients();
	@cc_values=$gip->get_custom_columns("$client_id");
	@ce_values=$gip->get_predef_columns_all("$client_id");

	my $audit_type="32";
	my $audit_class="5";
	my $update_type_audit="1";
	my $audit_which_clients=$$lang_vars{actual_client_message};
	$audit_which_clients=$$lang_vars{all_clients_message} if $cc_client_id == "9999";
	my $event="$cc_name ($audit_which_clients)";
	$gip->insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");
} elsif ( $management_type eq "insert_host_cc" ) {
	my $last_custom_host_column_id=$gip->get_last_custom_host_column_id();
	$last_custom_host_column_id++;
	$ce_host_id = '-1' if ! $ce_host_id;
	if ( $which_clients eq "9999" ) {
		my @ids_to_change=$gip->get_custom_host_column_ids_from_name("$client_id","$custom_host_column");
		foreach ( @ids_to_change ) {
			$gip->change_custom_host_column_entry_cc_id("$client_id","$_->[0]","$last_custom_host_column_id");
		}
		$gip->delete_custom_host_column_from_name("$client_id","$custom_host_column");
	}
	my $insert_ok=$gip->insert_custom_host_column("$which_clients","$last_custom_host_column_id","$custom_host_column","$ce_host_id");

	my $audit_type="42";
	my $audit_class="5";
	my $update_type_audit="1";
	my $audit_which_clients=$$lang_vars{actual_client_message};
	$audit_which_clients=$$lang_vars{all_clients_message} if $client_id == "9999";
	my $event="$custom_host_column ($audit_which_clients)";
	$gip->insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");

	@cc_host_values=$gip->get_custom_host_columns("$client_id");
	@ce_host_values=$gip->get_predef_host_columns_all("$client_id");
} elsif ( $management_type eq "insert_host_cc_custom" ) {
	my $last_custom_host_column_id=$gip->get_last_custom_host_column_id();
	$last_custom_host_column_id++;
	$ce_host_id = '-1' if ! $ce_host_id;



	@ce_host_values=$gip->get_predef_host_columns_all("$client_id");
	my $j="0";
	foreach ( @ce_host_values ) {
		if ( "$custom_host_column" eq "$ce_host_values[$j]->[1]" ) {
			$gip->print_error("$client_id","$$lang_vars{ce_name_exists_message}: $custom_host_column");
		}
		$j++;
	}
	@cc_host_values=$gip->get_custom_host_columns("$client_id");
	$j="0";
	foreach ( @cc_host_values ) {
		if ( "$custom_host_column" eq "$cc_host_values[$j]->[0]" && ( "$cc_host_values[$j]->[2]" eq $client_id || "$cc_host_values[$j]->[2]" eq "9999" ) ) {
			$gip->print_error("$client_id","$$lang_vars{cc_name_exists_message}: $custom_host_column");
		}
		$j++;
	}



	if ( $which_clients eq "9999" ) {
	my @ids_to_change=$gip->get_custom_host_column_ids_from_name("$client_id","$custom_host_column");
		foreach ( @ids_to_change ) {
			$gip->change_custom_host_column_entry_cc_id("$client_id","$_->[0]","$last_custom_host_column_id");
		}
		$gip->delete_custom_host_column_from_name("$client_id","$custom_host_column");
	}
	my $insert_ok=$gip->insert_custom_host_column("$which_clients","$last_custom_host_column_id","$custom_host_column","$ce_host_id");

	my $audit_type="42";
	my $audit_class="5";
	my $update_type_audit="1";
	my $audit_which_clients=$$lang_vars{actual_client_message};
	$audit_which_clients=$$lang_vars{all_clients_message} if $client_id == "9999";
	my $event="$custom_host_column ($audit_which_clients)";
	$gip->insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");

	@cc_host_values=$gip->get_custom_host_columns("$client_id");
} elsif ( $management_type eq "delete_host_cc" ) {
	my $cc_host_id = $daten{'cc_host_id'};
	my $cc_host_name=$gip->get_custom_host_column_name("$client_id","$cc_host_id");
	my $cc_client_id=$gip->get_custom_host_column_client_id("$client_id","$cc_host_id");
	my $delete_ok=$gip->delete_custom_host_column("$client_id","$cc_host_id");
	my @clients = $gip->get_clients();
	@cc_host_values=$gip->get_custom_host_columns("$client_id");
	@ce_host_values=$gip->get_predef_host_columns_all("$client_id");

	my $audit_type="43";
	my $audit_class="5";
	my $update_type_audit="1";
	my $audit_which_clients=$$lang_vars{actual_client_message};
	$audit_which_clients=$$lang_vars{all_clients_message} if $cc_client_id == "9999";
	my $event="$cc_host_name ($audit_which_clients)";
	$gip->insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");
}

print "<br><p>\n";

print "<table border=\"0\" cellpadding=\"25\" cellspacing=\"1\" width=\"100%\"><tr><td valign=\"top\" width=\"50%\" $align1>\n";


my $j=0;
my $ce_values_count=@ce_values; 
if ( ( $ce_values_count == "1" && $ce_values[0]->[1] eq "NOTYPE" )  ||  $ce_values_count == 0 ) {
	print "<b>$$lang_vars{insert_predef_column_message}</b><p>\n";
	print "<font color=\"gray\"><i>$$lang_vars{no_predef_net_columns_available_message}</i></font><br><p>\n";
} else {
	print "<form  method=\"POST\" border=\"0\" action=\"$server_proto://$base_uri/res/ip_modcolumns.cgi\">\n";
	print "<b>$$lang_vars{insert_predef_column_message}</b><p>\n";
	print "<table border=\"0\" cellpadding=\"7\">\n";
	print "<tr><td align=\"right\">$$lang_vars{title_message}</td><td>\n";

	print "<select name=\"ce_id\" size=\"1\">\n";
	foreach (@ce_values) {
		print "<option value=\"$ce_values[$j]->[0]\">$ce_values[$j]->[1]</option>" if $ce_values[$j]->[1] ne "NOTYPE";
		$j++;
	}
	print "</select></td></tr>\n";

	if ( $anz_clients_all > 1 ) {
		print "<tr><td colspan=\"2\">$$lang_vars{all_clients_message}<input type=\"radio\" name=\"which_clients\" value=\"9999\" checked>&nbsp;&nbsp;&nbsp;$$lang_vars{actual_client_message}<input type=\"radio\" name=\"which_clients\" value=\"$client_id\"><font color=\"white\">x</font></td></tr>\n";
	}

        print "<tr><td><input name=\"manage_type\" type=\"hidden\" value=\"insert_cc\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input type=\"submit\" class=\"input_link_w\" value=\"$$lang_vars{crear_message}\" name=\"B1\"></td><td></td></tr>\n";

	print "</table>\n";
	print "</form>\n";
}


print "<br><p>\n";
print "<form  method=\"POST\" action=\"$server_proto://$base_uri/res/ip_modcolumns.cgi\">\n";
print "<b>$$lang_vars{insert_custom_column_message}<b><p>\n";
print "<table border=\"0\" cellpadding=\"7\">\n";
print "<tr><td align=\"right\">$$lang_vars{title_message}</td><td><input type=\"text\" size=\"15\" name=\"custom_column\" value=\"\" maxlength=\"15\"></td></tr>\n";

if ( $anz_clients_all > 1 ) {
	print "<tr><td colspan=\"2\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\">$$lang_vars{all_clients_message}<input type=\"radio\" name=\"which_clients\" value=\"9999\" checked>&nbsp;&nbsp;&nbsp;$$lang_vars{actual_client_message}<input type=\"radio\" name=\"which_clients\" value=\"$client_id\"><font color=\"white\">x</font></td></tr>\n";
}
print "<tr><td><input name=\"manage_type\" type=\"hidden\" value=\"insert_cc_custom\"><input type=\"submit\" class=\"input_link_w\" value=\"$$lang_vars{crear_message}\" name=\"B1\"></td><td></td></tr>\n";
print "</table>\n";
print "</form>\n";

if ( $cc_values[0]->[0] ) {
	print "<form method=\"POST\" action=\"$server_proto://$base_uri/res/ip_modcolumns.cgi\">\n";
	print "<br><p>\n";
	print "<b>$$lang_vars{delete_custom_column_message}</b><p>\n";
	print "<table border=\"0\" cellpadding=\"7\">\n";
	print "<tr><td colspan=\"2\">$$lang_vars{title_message} \n";
	print "<select name=\"cc_id\" size=\"1\">\n";
	$j=0;
	foreach (@cc_values) {
		if ( $cc_values[$j]->[2] == "9999" ) {
			print "<option value=\"$cc_values[$j]->[1]\">$cc_values[$j]->[0] ($$lang_vars{for_all_clients_message})</option>";
		} else {
			print "<option value=\"$cc_values[$j]->[1]\">$cc_values[$j]->[0]</option>";
		}
		$j++;
	}
	print "</select></td></tr>\n";
	print "<tr><td><input name=\"manage_type\" type=\"hidden\" value=\"delete_cc\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input type=\"submit\" class=\"input_link_w\" value=\"$$lang_vars{borrar_message}\" name=\"B1\"></td><td></td></tr>\n";
	print "</table>\n";
	print "</form>\n";
}



print "</td><td valign=\"top\" $align1>\n";

### CUSTOM HOST COLUMNS

$j=0;
my $ce_host_values_count=@ce_host_values; 
if ( ( $ce_host_values_count == "1" && $ce_host_values[0]->[1] eq "NOTYPE" ) || ( $ce_host_values_count == 0 ) ) {
	print "<b>$$lang_vars{insert_predef_host_column_message}</b><p>\n";
	print "<font color=\"gray\"><i>$$lang_vars{no_predef_host_columns_available_message}</i></font><br><p>\n";
} else {
	print "<form  method=\"POST\" action=\"$server_proto://$base_uri/res/ip_modcolumns.cgi\">\n";
	print "<b>$$lang_vars{insert_predef_host_column_message}</b><p>\n";
	print "<table border=\"0\" cellpadding=\"7\">\n";
	print "<tr><td align=\"right\">$$lang_vars{title_message}</td><td>\n";

	print "<select name=\"ce_host_id\" size=\"1\">\n";
	foreach (@ce_host_values) {
		print "<option value=\"$ce_host_values[$j]->[0]\">$ce_host_values[$j]->[1]</option>" if $ce_host_values[$j]->[1] ne "NOTYPE";
		$j++;
	}
	print "</select></td></tr>\n";



	if ( $anz_clients_all > 1 ) {
		print "<tr><td colspan=\"2\">$$lang_vars{all_clients_message}<input type=\"radio\" name=\"which_clients\" value=\"9999\" checked>&nbsp;&nbsp;&nbsp;$$lang_vars{actual_client_message}<input type=\"radio\" name=\"which_clients\" value=\"$client_id\"><font color=\"white\">x</font></td></tr>\n";
	}

	print "<tr><td><input name=\"manage_type\" type=\"hidden\" value=\"insert_host_cc\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input type=\"submit\" class=\"input_link_w\" value=\"$$lang_vars{crear_message}\" name=\"B1\"></td><td></td></tr>\n";
	print "</table>\n";
	print "</form>\n";
}


print "<br><p>\n";
print "<form  method=\"POST\" action=\"$server_proto://$base_uri/res/ip_modcolumns.cgi\">\n";
print "<b>$$lang_vars{insert_custom_host_column_message}<b><p>\n";
print "<table border=\"0\" cellpadding=\"7\">\n";
print "<tr><td align=\"right\">$$lang_vars{title_message}</td><td><input type=\"text\" size=\"15\" name=\"custom_host_column\" value=\"\" maxlength=\"15\"></td></tr>\n";
if ( $anz_clients_all > 1 ) {
	print "<tr><td colspan=\"2\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\">$$lang_vars{all_clients_message}<input type=\"radio\" name=\"which_clients\" value=\"9999\" checked>&nbsp;&nbsp;&nbsp;$$lang_vars{actual_client_message}<input type=\"radio\" name=\"which_clients\" value=\"$client_id\"><font color=\"white\">x</font></td></tr>\n";
}
print "<tr><td><input name=\"manage_type\" type=\"hidden\" value=\"insert_host_cc_custom\"><input type=\"submit\" class=\"input_link_w\" value=\"$$lang_vars{crear_message}\" name=\"B1\"></td><td></td></tr>\n";
print "</table>\n";
print "</form>\n";

if ( $cc_host_values[0]->[0] ) {
	print "<form method=\"POST\" action=\"$server_proto://$base_uri/res/ip_modcolumns.cgi\">\n";
	print "<br><p>\n";
	print "<b>$$lang_vars{delete_custom_host_column_message}</b><p>\n";
	print "<table border=\"0\" cellpadding=\"7\">\n";
	print "<tr><td colspan=\"2\">$$lang_vars{title_message} \n";
	print "<select name=\"cc_host_id\" size=\"1\">\n";
	$j=0;
	foreach (@cc_host_values) {
		if ( $cc_host_values[$j]->[2] == "9999" ) {
			print "<option value=\"$cc_host_values[$j]->[1]\">$cc_host_values[$j]->[0] ($$lang_vars{for_all_clients_message})</option>";
		} else {
			print "<option value=\"$cc_host_values[$j]->[1]\">$cc_host_values[$j]->[0]</option>";
		}
		$j++;
	}
	print "</select></td></tr>\n";
	print "<tr><td><input name=\"manage_type\" type=\"hidden\" value=\"delete_host_cc\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input type=\"submit\" class=\"input_link_w\" value=\"$$lang_vars{borrar_message}\" name=\"B1\"></td><td></td></tr>\n";
	print "</table>\n";
	print "</form>\n";
}




print "</td></tr></table>\n";
print "<br><p>\n";


$gip->print_end("$client_id","$vars_file");
