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
use lib './modules';
use GestioIP;
use Cwd;
use Net::IP;
use Net::IP qw(:PROC);

my $daten=<STDIN>;
my $gip = GestioIP -> new();
my %daten=$gip->preparer($daten);

my $base_uri = $gip->get_base_uri();
my $server_proto=$gip->get_server_proto();

my $lang = $daten{'lang'} || "";
my ($lang_vars,$vars_file)=$gip->get_lang("","$lang");


my $client_id = $daten{'client_id'} || $gip->get_first_client_id();
if ( $client_id !~ /^\d{1,4}$/ ) {
	$client_id = 1;
	$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{ipv6_address_plan_message}","$vars_file");
	$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (0)");
}


my @config = $gip->get_config("$client_id");
my $confirmation = $config[0]->[7] || "no";
my $anz_locs=$gip->count_locs("$client_id");
my $anz_cats=$gip->count_cats("$client_id");
$anz_cats--;

$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{ipv6_address_plan_message}","$vars_file");


print "<p>\n";

print "<p>\n";
print "<b>$$lang_vars{create_mapped_ipv6_message}</b>\n";
print "<p><br>\n";
print "$$lang_vars{direct_translation_mapped_explic_message}</b>\n";
print "<br><p>\n";
print "<form name=\"mig_form\"action=\"$server_proto://$base_uri/ip_migrate_to_v6_mapped.cgi\" method=\"post\">\n";
print "<input type=\"hidden\" name=\"client_id\" value=\"$client_id\">\n";
print "<table border=\"0\">\n";
print "<tr align=\"center\"><td width=\"85\">$$lang_vars{first_oct_message}</td><td width=\"85\">$$lang_vars{second_oct_message}</td><td width=\"85\">$$lang_vars{third_oct_message}</td></tr>\n";
print "<tr align=\"center\"><td><input type=\"text\" name=\"first_oct\" size=\"3\"></td><td><input type=\"text\" name=\"second_oct\" size=\"3\"></td><td><input type=\"text\" name=\"third_oct\" size=\"3\"></td></tr>\n";
print "</table>\n";
print "<p><input type=\"submit\" name=\"Submit\" value=\"$$lang_vars{submit_message}\" class=\"input_link_w\"></p>\n";
print "</form>\n";


$gip->print_end("$client_id");
