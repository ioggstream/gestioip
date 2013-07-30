#!/usr/bin/perl -w -T

use strict;
use DBI;
use lib '../modules';
use GestioIP;


my $gip = GestioIP -> new();
my $daten=<STDIN>;
my %daten=$gip->preparer($daten);

my $lang = $daten{'lang'} || "";
my ($lang_vars,$vars_file,$entries_per_page)=$gip->get_lang("","$lang");
my $base_uri = $gip->get_base_uri();

my $client_id = $daten{'client_id'} || $gip->get_first_client_id();
my $as_number=$daten{'as_number'};

if ( ! $as_number ) {
        $gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{edit_as_message}","$vars_file");
        $gip->print_error("$client_id","$$lang_vars{insert_as_number_message}")
}

if ( $as_number !~ /^\d{1,10}$/ ) {
        $gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{edit_as_message}","$vars_file");
        $gip->print_error("$client_id","$$lang_vars{check_as_number_message}")
}


$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","AS $as_number: $$lang_vars{parameter_changed_message}","$vars_file");


my $as_id=$daten{'as_id'} || $gip->print_error("$client_id","$$lang_vars{formato_malo_message} (1)");
my $comment=$daten{'comment'} || "";
my $description=$daten{'description'} || "";
my $as_client_id=$daten{'as_client_id'} || "-1";


my @values_as=$gip->get_one_as("$client_id","$as_id");

my @value_as_client=$gip->get_one_as_client("$client_id","$as_client_id");
my $as_client=$value_as_client[0]->[1];

$gip->update_as("$client_id","$as_id","$comment","$description","$as_client_id");

my $old_description=$values_as[0]->[2];
my $old_comment=$values_as[0]->[3];
my $old_as_client=$values_as[0]->[5];
$comment = "---" if ! $comment;
$old_as_client="---" if $old_as_client eq "_DEFAULT_";
$as_client="---" if $as_client eq "_DEFAULT_";
my $audit_type="49";
my $audit_class="11";
my $update_type_audit="1";
my $event1="$old_comment,$old_description,$old_as_client";
my $event2="$comment, $description, $as_client";
my $event = "AS $as_number: " . $event1 . " -> " . $event2;
$gip->insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");


my @as=$gip->get_as("$client_id");

print "<p>\n";

$gip->PrintASTab("$client_id",\@as,"$vars_file");

$gip->print_end("$client_id");

