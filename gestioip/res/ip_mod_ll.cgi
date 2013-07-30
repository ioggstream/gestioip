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

#if ( ! $phone_number ) {
#        $gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{edit_ll_message} (1)","$vars_file");
#        $gip->print_error("$client_id","$$lang_vars{formato_malo_message} (1)")
#}
#
#if ( $phone_number !~ /^\d{1,10}/ ) {
#        $gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{formato_malo_message} (2)","$vars_file");
#        $gip->print_error("$client_id","$$lang_vars{edit_ll_message}")
#}


$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{parameter_changed_message}","$vars_file");


my $ll_id=$daten{'ll_id'} || $gip->print_error("$client_id","$$lang_vars{formato_malo_message} (3)");
my $comment=$daten{'comment'} || "";
my $description=$daten{'description'} || "";
my $ll_client_id=$daten{'ll_client_id'} || "-1";
my $loc_id=$daten{'loc_id'} || "-1";
my $type=$daten{'type'} || "";
my $service=$daten{'service'} || "";
my $device=$daten{'device'} || "";
my $room=$daten{'room'} || "";
my $ad_number=$daten{'ad_number'} || "";


my @values_ll=$gip->get_one_ll("$client_id","$ll_id");
my @value_ll_client=$gip->get_one_ll_client("$client_id","$ll_client_id");
my $loc=$gip->get_loc_from_id("$client_id","$loc_id") || "NULL";

my $ll_client=$value_ll_client[0]->[1];

$gip->update_ll("$client_id","$ll_id","$comment","$description","$ll_client_id","$loc_id","$type","$service","$device","$room","$phone_number","$ad_number");

my $old_description=$values_ll[0]->[2] || "---";
my $old_comment=$values_ll[0]->[3] || "---";
my $old_ll_client=$values_ll[0]->[5] || "---";
my $old_loc=$values_ll[0]->[9] || "---";
my $old_type=$values_ll[0]->[10] || "---";
my $old_service=$values_ll[0]->[11] || "---";
my $old_device=$values_ll[0]->[12] || "---";
my $old_room=$values_ll[0]->[13] || "---";
my $old_ad_number=$values_ll[0]->[14] || "---";
$old_ll_client="---" if $old_ll_client eq "_DEFAULT_";
$ll_client="---" if $ll_client eq "_DEFAULT_";
$loc="---" if $loc eq "NULL";
$type="---" if ! $type;
$service="---" if ! $service;
$device="---" if ! $device;
$room="---" if ! $room;
$ad_number="---" if ! $ad_number;

my $audit_type="55";
my $audit_class="13";
my $update_type_audit="1";
my $event1="$old_comment, $old_description, $old_ll_client, $old_loc, $old_type, $old_service, $old_device, $old_room, $old_ad_number";
my $event2="$comment, $description, $ll_client, $loc, $type, $service, $device, $room, $ad_number";
my $event = "LL $phone_number: " . $event1 . " -> " . $event2;
$gip->insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");


my @as=$gip->get_ll("$client_id");

print "<p>\n";

$gip->PrintLLTab("$client_id",\@as,"$vars_file");

$gip->print_end("$client_id");

