#!/usr/bin/perl -w -T

use strict;
use DBI;
use lib '../modules';
use GestioIP;


my $gip = GestioIP -> new();
my $daten=<STDIN>;
my %daten=$gip->preparer($daten);

my ($lang_vars,$vars_file,$entries_per_page)=$gip->get_lang();
my $base_uri = $gip->get_base_uri();

my $client_id = $daten{'client_id'} || $gip->get_first_client_id();

my $as_client_id = $daten{'as_client_id'} || "";
my $name = $daten{'name'} || "";

if ( $as_client_id !~ /^\d{1,10}/ ) {
	$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{delete_as_client_message}","$vars_file");
	$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (1)")
}


$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{as_client_deleted_message}: \"$name\"","$vars_file");

$gip->delete_as_client("$client_id","$as_client_id");

my $audit_type="53";
my $audit_class="12";
my $update_type_audit="1";
my $event="$name";
$gip->insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");


my @as_clients=$gip->get_as_clients("$client_id");

if ( $as_clients[1] ) {
	print "<p>\n";
	$gip->PrintASClientTab("$client_id",\@as_clients,"$vars_file");
} else {
	print "<p class=\"NotifyText\">$$lang_vars{no_resultado_message}</p><br>\n";
}


$gip->print_end("$client_id");

