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


my $daten=<STDIN>;
my $gip = GestioIP -> new();
my %daten=$gip->preparer($daten);

my $base_uri = $gip->get_base_uri();

my $lang = $daten{'lang'} || "";
my ($lang_vars,$vars_file)=$gip->get_lang("","$lang");
my $server_proto=$gip->get_server_proto();

my $admin_type=$daten{'admin_type'} || "";

my $client_id = $daten{'client_id'} || $gip->get_first_client_id();

if ( $daten{'client_id'} !~ /^\d{1,4}$/ ) {
                $gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{administrar_message}","$vars_file");
                $gip->print_error("$client_id","$$lang_vars{formato_malo_message} (1)");
}

my $count_clients=$gip->count_clients() || "1";

my $align="align=\"right\"";
my $align1="";
my $ori="left";
if ( $vars_file =~ /vars_he$/ ) {
        $align="align=\"left\"";
        $align1="align=\"right\"";
        $ori="right";
}

if ( $admin_type eq "loc_del" ) {
	my $loc=$daten{'loc_del'};
	my $loc_id=$gip->get_loc_id("$client_id","$loc");
	if ( ! defined($loc_id) ) {
		$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{administrar_message} $$lang_vars{locs_message}","$vars_file");
		$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (1)");
	} else {
		$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{admin_loc_del_message}: $loc","$vars_file");
	}
	$gip->reset_host_loc_id("$client_id","$loc_id") if $loc_id;
	$gip->reset_net_loc_id("$client_id","$loc_id") if $loc_id;
	$gip->loc_del("$client_id","$loc");
	my $audit_type="13";
	my $audit_class="5";
	my $update_type_audit="1";
	my $event="$loc";
	$gip->insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");
} elsif ( $admin_type eq "loc_add" ) {
	my $loc=$daten{'loc_add'};
	if ( ! $daten{'loc_add'} ) {
		$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{administrar_message} $$lang_vars{locs_message}","$vars_file");
		$gip->print_error("$client_id","$$lang_vars{introduce_loc_message}");
	} elsif ( $loc !~ /^.{1,30}$/ ) {
		$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{administrar_message} $$lang_vars{locs_message}","$vars_file");
		$gip->print_error("$client_id","<i>$$lang_vars{loc_message}</i> $$lang_vars{max_signos_30_message}");
	}
	my $loc_id=$gip->get_loc_id("$client_id","$loc");
	if ( $loc_id ) {
		$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{administrar_message} $$lang_vars{locs_message}","$vars_file");
		$gip->print_error("$client_id","$$lang_vars{loc_exists_message}: $loc");
	}
	$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{admin_loc_add_message}: $loc","$vars_file");
	my $last_loc_id=$gip->get_last_loc_id("$client_id");
	$last_loc_id++;
	$last_loc_id = "1" if $last_loc_id == "0";
	$gip->loc_add("$client_id","$loc","$last_loc_id");
	my $audit_type="10";
	my $audit_class="5";
	my $update_type_audit="1";
	my $event="$loc";
	$gip->insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");
} elsif ( $admin_type eq "cat_del" ) {
	my $cat=$daten{'cat_del'};
	my $cat_id=$gip->get_cat_id("$client_id","$cat");
	if ( ! defined($cat_id) ) {
		$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{administrar_message} $$lang_vars{cats_message}","$vars_file");
		$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (2)");
	} elsif ( $cat eq "DB" || $cat eq "FW" || $cat eq "L2 device" || $cat eq "L3 device" || $cat eq "other" || $cat eq "VoIP" || $cat eq "server" || $cat eq "workst" || $cat eq "printer" ) {
		$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{administrar_message} $$lang_vars{cats_message}","$vars_file");
		$gip->print_error("$client_id","<b>$cat</b>: $$lang_vars{borrar_default_cat_message}")
	} else {
		$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{admin_cat_del_message}: $cat","$vars_file");
	}
	$gip->reset_host_cat_id("$client_id","$cat_id") if $cat_id;
	$gip->cat_del("$client_id","$cat");
	my $audit_type="11";
	my $audit_class="5";
	my $update_type_audit="1";
	my $event="$cat";
	$gip->insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");
} elsif ( $admin_type eq "cat_add" ) {
	my $cat=$daten{'cat_add'};
	if ( ! $daten{'cat_add'} ) {
		$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{administrar_message} $$lang_vars{cats_message}","$vars_file");
		$gip->print_error("$client_id","$$lang_vars{cat_red_message}");
	} elsif ( $cat !~ /^.{1,30}$/ ) {
		$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{administrar_message} $$lang_vars{cats_message}","$vars_file");
		$gip->print_error("$client_id","<i>$$lang_vars{cat_message}</i> $$lang_vars{max_signos_30_message}");
	}
	my $cat_id=$gip->get_cat_id("$client_id","$cat");
	if ( $cat_id ) {
		$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{administrar_message} $$lang_vars{cats_message}","$vars_file");
		$gip->print_error("$client_id","$$lang_vars{cat_exists_message}: $cat");
	}
	$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{admin_cat_add_message}: $cat","$vars_file");
	my $last_cat_id=$gip->get_last_cat_id("$client_id");
	$last_cat_id++;
	$last_cat_id = "1" if $last_cat_id == "0";
	$gip->cat_add("$client_id","$cat","$last_cat_id");
	my $audit_type="8";
	my $audit_class="5";
	my $update_type_audit="1";
	my $event="$cat";
	$gip->insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");
} elsif ( $admin_type eq "cat_net_del" ) {
	my $cat_net=$daten{'cat_net_del'};
	my $cat_net_id=$gip->get_cat_net_id("$client_id","$cat_net");
	if ( ! defined($cat_net_id) ) {
		$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{administrar_message} $$lang_vars{cat_net_message}","$vars_file");
		$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (3)");
	} else {
		$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{admin_cat_del_message}: $cat_net","$vars_file");
	}

	$gip->reset_host_cat_net_id("$client_id","$cat_net_id") if $cat_net_id;
	$gip->cat_net_del("$client_id","$cat_net");
	my $audit_type="12";
	my $audit_class="5";
	my $update_type_audit="1";
	my $event="$cat_net";
	$gip->insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");
} elsif ( $admin_type eq "cat_net_add" ) {
	my $cat_net=$daten{'cat_net_add'};
	if ( ! $daten{'cat_net_add'} ) {
		$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{administrar_message} $$lang_vars{cat_net_message}","$vars_file");
		$gip->print_error("$client_id","$$lang_vars{cat_red_message}");
	} elsif ( $cat_net !~ /^.{1,60}$/ ) {
		$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{administrar_message} $$lang_vars{cat_net_message}","$vars_file");
		$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (4)");
	}
	my $cat_net_id=$gip->get_cat_net_id("$client_id","$cat_net");
	if ( $cat_net_id ) {
		$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{administrar_message} $$lang_vars{cat_net_message}","$vars_file");
		$gip->print_error("$client_id","$$lang_vars{cat_exists_message}: $cat_net");
	}
	$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{admin_cat_add_message}: $cat_net","$vars_file");
	my $last_cat_net_id=$gip->get_last_cat_net_id("$client_id");
	$last_cat_net_id++;
	$last_cat_net_id = "1" if $last_cat_net_id == "0";
	$gip->cat_net_add("$client_id","$cat_net","$last_cat_net_id");
	my $audit_type="9";
	my $audit_class="5";
	my $update_type_audit="1";
	my $event="$cat_net";
	$gip->insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");

} elsif ( $admin_type eq "loc_rename" ) {
	my $loc_old_rename=$daten{'loc_old_rename'};
	my $loc_new_rename=$daten{'loc_new_rename'};
	if ( ! $daten{'loc_old_rename'} ) {
		$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{administrar_message} $$lang_vars{cat_net_message}","$vars_file");
		$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (5)");
	} elsif ( ! $daten{'loc_new_rename'} ) {
		$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{administrar_message} $$lang_vars{cat_net_message}","$vars_file");
		$gip->print_error("$client_id","$$lang_vars{introduce_loc_message}");
	} elsif ( $loc_old_rename !~ /^.{1,30}$/ || $loc_new_rename !~ /^.{1,30}$/) {
		$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{administrar_message} $$lang_vars{cat_net_message}","$vars_file");
		$gip->print_error("$client_id","<i>$$lang_vars{site_message}</i> $$lang_vars{max_signos_30_message}");
	}
	$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{admin_loc_renom_message}: $loc_old_rename -> $loc_new_rename","$vars_file");
	$gip->rename("$client_id","$loc_old_rename","$loc_new_rename","locations");
	my $audit_type="20";
	my $audit_class="5";
	my $update_type_audit="1";
	my $event="$loc_old_rename -> $loc_new_rename";
	$gip->insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");

} elsif ( $admin_type eq "cat_rename" ) {
	if ( ! $daten{'cat_old_rename'} ) {
		$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{administrar_message} $$lang_vars{cat_net_message}","$vars_file");
		$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (6)");
	} elsif ( ! $daten{'cat_new_rename'} ) {
		$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{administrar_message} $$lang_vars{cat_net_message}","$vars_file");
		$gip->print_error("$client_id","$$lang_vars{cat_red_message}");
	} elsif ( $daten{'cat_old_rename'} !~ /^.{1,30}$/ || $daten{'cat_new_rename'} !~ /^.{1,30}$/) {
		$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{administrar_message} $$lang_vars{cat_net_message}","$vars_file");
		$gip->print_error("$client_id","<i>$$lang_vars{cat_message}</i> $$lang_vars{max_signos_30_message}");
	}
	my $cat=$daten{'cat_old_rename'};
	my $cat_new_rename=$daten{'cat_new_rename'};
	if ( $cat eq "DB" || $cat eq "FW" || $cat eq "L2 Device" || $cat eq "L3 Device" || $cat eq "other" || $cat eq "VoIP" || $cat eq "server" || $cat eq "workst" ) {
		$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{administrar_message} $$lang_vars{cat_net_message}","$vars_file");
		$gip->print_error("$client_id","<b>$cat</b>: $$lang_vars{renombrar_default_cat_message}");
	}
	$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{admin_cat_renom_message}: $cat -> $cat_new_rename","$vars_file");
	$gip->rename("$client_id","$cat","$cat_new_rename","categorias");
	my $audit_type="21";
	my $audit_class="5";
	my $update_type_audit="1";
	my $event="$cat -> $cat_new_rename";
	$gip->insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");

} elsif ( $admin_type eq "cat_net_rename" ) {
	if ( ! $daten{'cat_net_old_rename'} ) {
		$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{administrar_message} $$lang_vars{cat_net_message}","$vars_file");
		$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (7)");
	} elsif ( ! $daten{'cat_net_new_rename'} ) {
		$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{administrar_message} $$lang_vars{cat_net_message}","$vars_file");
		$gip->print_error("$client_id","$$lang_vars{cat_red_message}");
	} elsif ( $daten{'cat_net_old_rename'} !~ /^.{1,60}$/ || $daten{'cat_net_new_rename'} !~ /^.{1,60}$/) {
		$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{administrar_message} $$lang_vars{cat_net_message}","$vars_file");
		$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (8)");
	}
	my $cat_net_old_rename=$daten{'cat_net_old_rename'};
	my $cat_net_new_rename=$daten{'cat_net_new_rename'};
	$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{admin_cat_renom_message}: $cat_net_old_rename -> $cat_net_new_rename","$vars_file");
	$gip->rename("$client_id","$cat_net_old_rename","$cat_net_new_rename","categorias_net");
	my $audit_type="22";
	my $audit_class="5";
	my $update_type_audit="1";
	my $event="$cat_net_old_rename -> $cat_net_new_rename";
	$gip->insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");


} elsif ( ! $admin_type ) {
	$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{administrar_cat_net_message}","$vars_file");
} else {
	$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{administrar_cat_net_message}","$vars_file");
	$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (9)");
}


my @values_locations=$gip->get_loc("$client_id");
my @values_categorias=$gip->get_cat("$client_id");
my @values_categorias_net=$gip->get_cat_net("$client_id");


print "<table border=\"0\" cellpadding=\"25\" cellspacing=\"1\" width=\"100%\"><tr><td $align1>\n\n";



print "<span class=\"headline_administrate_text\">$$lang_vars{locs_message}</span>\n";
print "<p><br>\n";
print "<table border=\"0\" cellpadding=\"5\" cellspacing=\"1\"><tr><td align=\"left\">";
print "<form method=\"POST\" name=\"admin2\" action=\"$server_proto://$base_uri/res/ip_admin.cgi\">\n";
print "<input type=\"text\" name=\"loc_add\" size=\"10\" maxlength=\"30\"></td></tr>\n";
print "<tr><td><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"submit\" value=\"$$lang_vars{crear_message}\" name=\"B2\" class=\"input_link_w\"><input type=\"hidden\" name=\"admin_type\" value=\"loc_add\"></form></td></tr></table>\n";

print "<p><br>\n";
print "<table border=\"0\" cellpadding=\"5\" cellspacing=\"1\"><tr><td align=\"left\">";
print "<form method=\"POST\" action=\"$server_proto://$base_uri/res/ip_admin.cgi\">\n";
print "<select name=\"loc_del\" size=\"1\">\n";
my $j=0;
foreach (@values_locations) {
	print "<option>$values_locations[$j]->[0]</option>\n" if $values_locations[$j]->[0] ne "NULL";
	$j++;
}
print "</select></td></tr><tr><td><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"submit\" value=\"$$lang_vars{borrar_message}\" name=\"B2\" class=\"input_link_w\"><input type=\"hidden\" name=\"admin_type\" value=\"loc_del\"></form></td></tr></table>\n";
	

print "<p><br>\n";
print "<table border=\"0\" cellpadding=\"5\" cellspacing=\"1\"><tr><td align=\"left\">";
print "<form method=\"POST\" action=\"$server_proto://$base_uri/res/ip_admin.cgi\">\n";
print "<i>$$lang_vars{nombre_actual_message}</i><br><select name=\"loc_old_rename\" size=\"1\">\n";
$j=0;
foreach (@values_locations) {
	print "<option>$values_locations[$j]->[0]</option>\n" if $values_locations[$j]->[0] ne "NULL";
	$j++;
}
print "</select></td><td valign=\"top\"><i>$$lang_vars{nombre_nuevo_message}</i><br><input type=\"text\" name=\"loc_new_rename\" size=\"10\" maxlength=\"30\"></td></tr><tr><td valign=\"top\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"submit\" value=\"$$lang_vars{rename_message}\" name=\"B2\" class=\"input_link_w\"><input type=\"hidden\" name=\"admin_type\" value=\"loc_rename\"></form></td><td></td></tr></table>\n";

print "<script type=\"text/javascript\">\n";
print "document.admin2.loc_add.focus();\n";
print "</script>\n";

print "</td><td $align1>\n\n";



print "<span class=\"headline_administrate_text\">$$lang_vars{host_cat_message}</span>\n";
print "<br>($$lang_vars{client_independent_message})<font color=\"white\">x</font>\n" if $count_clients > "1";
print "<p><br>\n";
print "<table border=\"0\" cellpadding=\"5\" cellspacing=\"1\"><tr><td align=\"left\">";
print "<form method=\"POST\" name=\"admin2\" action=\"$server_proto://$base_uri/res/ip_admin.cgi\">\n";
print "<input type=\"text\" name=\"cat_add\" size=\"10\" maxlength=\"30\"></td></tr><tr>\n";
print "<td><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"submit\" value=\"$$lang_vars{crear_message}\" name=\"B2\" class=\"input_link_w\"><input type=\"hidden\" name=\"admin_type\" value=\"cat_add\"></form></td></tr></table>\n";


print "<p><br>\n";
print "<table border=\"0\" cellpadding=\"5\" cellspacing=\"1\"><tr><td align=\"left\">";
print "<form method=\"POST\" action=\"$server_proto://$base_uri/res/ip_admin.cgi\">\n";
print "<select name=\"cat_del\" size=\"1\">\n";
$j=0;
foreach (@values_categorias) {
	print "<option>$values_categorias[$j]->[0]</option>\n" if $values_categorias[$j]->[0] ne "NULL";
	$j++;
}
print "</select></td></tr><tr><td><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"submit\" value=\"$$lang_vars{borrar_message}\" name=\"B2\" class=\"input_link_w\"><input type=\"hidden\" name=\"admin_type\" value=\"cat_del\"></form></td></tr></table>\n";
	

print "<p><br>\n";
print "<table border=\"0\" cellpadding=\"5\" cellspacing=\"1\"><tr><td align=\"left\">";
print "<form method=\"POST\" action=\"$server_proto://$base_uri/res/ip_admin.cgi\">\n";
print "<i>$$lang_vars{nombre_actual_message}</i><br><select name=\"cat_old_rename\" size=\"1\">\n";
$j=0;
foreach (@values_categorias) {
	print "<option>$values_categorias[$j]->[0]</option>\n" if $values_categorias[$j]->[0] ne "NULL";
	$j++;
}
print "</select></td><td valign=\"top\"><i>$$lang_vars{nombre_nuevo_message}</i><br><input type=\"text\" name=\"cat_new_rename\" size=\"10\" maxlength=\"30\"></td></tr><tr><td valign=\"top\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"submit\" value=\"$$lang_vars{rename_message}\" name=\"B2\" class=\"input_link_w\"><input type=\"hidden\" name=\"admin_type\" value=\"cat_rename\"></form></td><td></td></tr></table>\n";


print "</td><td $align1>\n\n";


print "<span class=\"headline_administrate_text\">$$lang_vars{cat_net_message}</span>\n";
print "<br>($$lang_vars{client_independent_message})<font color=\"white\">x</font>\n" if $count_clients > "1";
print "<p><br>\n";
print "<table border=\"0\" cellpadding=\"5\" cellspacing=\"1\"><tr><td align=\"left\">";
print "<form method=\"POST\" name=\"admin2\" action=\"$server_proto://$base_uri/res/ip_admin.cgi\">\n";
print "<input type=\"text\" name=\"cat_net_add\" size=\"10\" maxlength=\"30\"></td></tr><tr>\n";
print "<td><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"submit\" value=\"$$lang_vars{crear_message}\" name=\"B2\" class=\"input_link_w\"><input type=\"hidden\" name=\"admin_type\" value=\"cat_net_add\"></form></td></tr></table>\n";


print "<p><br>\n";
print "<table border=\"0\" cellpadding=\"5\" cellspacing=\"1\"><tr><td align=\"left\">";
print "<form method=\"POST\" action=\"$server_proto://$base_uri/res/ip_admin.cgi\">\n";
print "<select name=\"cat_net_del\" size=\"1\">\n";
$j=0;
foreach (@values_categorias_net) {
	print "<option>$values_categorias_net[$j]->[0]</option>\n" if $values_categorias_net[$j]->[0] ne "NULL";
	$j++;
}
print "</select></td></tr><tr><td><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"submit\" value=\"$$lang_vars{borrar_message}\" name=\"B2\" class=\"input_link_w\"><input type=\"hidden\" name=\"admin_type\" value=\"cat_net_del\"></form></td></tr></table>\n";
	

print "<p><br>\n";
print "<table border=\"0\" cellpadding=\"5\" cellspacing=\"1\"><tr><td align=\"left\">";
print "<form method=\"POST\" action=\"$server_proto://$base_uri/res/ip_admin.cgi\">\n";
print "<i>$$lang_vars{nombre_actual_message}</i><br><select name=\"cat_net_old_rename\" size=\"1\">\n";
$j=0;
foreach (@values_categorias_net) {
	print "<option>$values_categorias_net[$j]->[0]</option>\n" if $values_categorias_net[$j]->[0] ne "NULL";
	$j++;
}
print "</select></td><td valign=\"top\"><i>$$lang_vars{nombre_nuevo_message}</i><br><input type=\"text\" name=\"cat_net_new_rename\" size=\"10\" maxlength=\"30\"></td></tr><tr><td valign=\"top\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"submit\" value=\"$$lang_vars{rename_message}\" name=\"B2\" class=\"input_link_w\"><input type=\"hidden\" name=\"admin_type\" value=\"cat_net_rename\"></form></td><td></td></tr></table>\n";


print "</td></tr></table>\n";

$gip->print_end("$client_id","$vars_file");
