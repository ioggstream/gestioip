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

my $as_id = $daten{'as_id'} || "";
my $as_number = $daten{'as_number'} || "";

if ( $as_id !~ /^\d{1,10}/ ) {
	$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{delete_as_message}","$vars_file");
	$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (1)")
}

if ( ! $as_number ) {
	$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{delete_as_message}","$vars_file");
	$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (2)")
}

$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{as_deleted_message}: \"$as_number\"","$vars_file");


my $comment = $daten{'as_comment'} || "";

my @values_as=$gip->get_as("$client_id","$as_id");

my $as_entry = "$as_id";
$gip->delete_as("$client_id","$as_id");


my $audit_type="50";
my $audit_class="11";
my $update_type_audit="1";
my $event="$as_number";
$event=$event . "," . $comment if $comment;
$gip->insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");


my @as=$gip->get_as("$client_id");

if ( $as[0] ) {
	print "<p>\n";
	$gip->PrintASTab("$client_id",\@as,"$vars_file");
} else {
	print "<p class=\"NotifyText\">$$lang_vars{no_resultado_message}</p><br>\n";
}


$gip->print_end("$client_id");

