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

my $phone_number=$daten{'phone_number'} || "";
$daten{'phone_number'}=~s/^\s+//;
$daten{'phone_number'}=~s/\s+$//;

#if ( ! $phone_number ) {
#        $gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{insert_ll_message}","$vars_file");
#        $gip->print_error("$client_id","$$lang_vars{insert_ll_phone_message}")
#}

#if ( $phone_number && $phone_number !~ /^\d{1,10}/ ) {
#        $gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{insert_ll_message}","$vars_file");
#        $gip->print_error("$client_id","$$lang_vars{insert_ll_phone_message}")
#}


##### pruefen, ob die LL number schon vergeben ist

my @as=$gip->get_ll("$client_id");
if ( $phone_number ) {
	foreach ( @as ) {
		if ( $_->[1] eq $phone_number ) {
			$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{insert_ll_message}","$vars_file");
			$gip->print_error("$client_id","$phone_number - $$lang_vars{ll_exists_message}");
		}
	}
}

$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{ll_added_message}","$vars_file");


my $comment=$daten{'comment'} || "";
my $loc_id=$daten{'loc_id'} || "-1";
#$gip->print_error("$client_id","$$lang_vars{check_phone_number_message}") if $daten{'phone_number'} !~ /^\d{1,10}$/;
my $ll_client_id=$daten{'ll_client_id'} || '-1';
my $description=$daten{'description'} || "";
my $type=$daten{'type'} || "";
my $service=$daten{'service'} || "";
my $device=$daten{'device'} || "";
my $room=$daten{'room'} || "";
my $ad_number=$daten{'ad_number'} || "";


##### as in datenbank einstellen

$gip->insert_ll("$client_id","$phone_number","$loc_id","$comment","$description","$ll_client_id","$type","$service","$device","$room","$ad_number");


my $audit_type="54";
my $audit_class="13";
my $update_type_audit="1";
my $event="$phone_number";
$event=$event . "," .  $comment if $comment;
$gip->insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");


@as=$gip->get_ll("$client_id");
if ( $as[0] ) {
        $gip->PrintLLTab("$client_id",\@as,"$vars_file");
} else {
        print "<p class=\"NotifyText\">$$lang_vars{no_resultado_message}</p><br>\n";
}


$gip->print_end("$client_id","$vars_file");

