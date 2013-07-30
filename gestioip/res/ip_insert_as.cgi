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
$daten{'as_number'}=~s/^\s+//;
$daten{'as_number'}=~s/\s+$//;

if ( ! $as_number ) {
        $gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{add_as_message}","$vars_file");
        $gip->print_error("$client_id","$$lang_vars{insert_as_number_message}")
}

if ( $as_number !~ /^\d{1,10}$/ ) {
        $gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{add_as_message}","$vars_file");
        $gip->print_error("$client_id","$$lang_vars{check_as_number_message}")
}


##### pruefen, ob die AS number schon vergeben ist

my @as=$gip->get_as("$client_id");
foreach ( @as ) {
	if ( $_->[1] eq $as_number ) {
		$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{insert_as_message}","$vars_file");
		$gip->print_error("$client_id","$as_number - $$lang_vars{as_exists_message}");
	}
}

$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{as_added_message}: \"$as_number\"","$vars_file");


my $comment=$daten{'comment'} || "";
$gip->print_error("$client_id","$$lang_vars{check_as_number_message}") if $daten{'as_number'} !~ /^\d{1,10}$/;
my $as_client_id=$daten{'as_client_id'} || '-1';
my $description=$daten{'description'} || "";


##### as in datenbank einstellen

$gip->insert_as("$client_id","$as_number","$comment","$description","$as_client_id");


my $audit_type="48";
my $audit_class="11";
my $update_type_audit="1";
my $event="$as_number";
$event=$event . "," .  $comment if $comment;
$gip->insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");


@as=$gip->get_as("$client_id");
if ( $as[0] ) {
        $gip->PrintASTab("$client_id",\@as,"$vars_file");
} else {
        print "<p class=\"NotifyText\">$$lang_vars{no_resultado_message}</p><br>\n";
}


$gip->print_end("$client_id","$vars_file");

