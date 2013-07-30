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
my $server_proto=$gip->get_server_proto();

my $lang = $daten{'lang'} || "";
my ($lang_vars,$vars_file)=$gip->get_lang("","$lang");


my $client_id = $daten{'client_id'} || $gip->get_first_client_id();


my $ll_client_name=$daten{'ll_client_name'} || "";
my $type=$daten{'type'} || "";
my $comment=$daten{'comment'} || "";
my $description=$daten{'description'} || "";
my $address=$daten{'address'} || "";
my $phone=$daten{'phone'} || "";
my $fax=$daten{'fax'} || "";
my $contact=$daten{'contact'} || "";
my $contact_email=$daten{'contact_email'} || "";
my $contact_phone=$daten{'contact_phone'} || "";
my $contact_cell=$daten{'contact_cell'} || "";

if ( ! $ll_client_name ) {
	$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{insert_ll_client_message}","$vars_file");
	$gip->print_error("$client_id","$$lang_vars{insert_ll_client_name_message}");
}

$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{insert_ll_client_message}: $ll_client_name","$vars_file");

my $ll_client_id=$gip->check_ll_client_exists("$client_id","$ll_client_name") || "";
$gip->print_error("$client_id","$$lang_vars{ll_client_exists_message}: $ll_client_name") if $ll_client_id;


$gip->insert_ll_client("$client_id","$ll_client_name","$type","$description","$comment","$phone","$fax","$address","$contact","$contact_email","$contact_phone","$contact_cell");

my $audit_type="57";
my $audit_class="14";
my $update_type_audit="1";
my $event="$ll_client_name,$type,$description,$comment,$phone,$fax,$address,$contact,$contact_email,$contact_phone,$contact_cell";
$event = $event . " - " . $comment if $comment;
$gip->insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");


my @ll_clients=$gip->get_ll_clients("$client_id");

print "<p>\n";
$gip->PrintLLClientTab("$client_id",\@ll_clients,"$vars_file");


$gip->print_end("$client_id");
