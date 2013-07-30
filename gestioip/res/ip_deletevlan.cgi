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

my $vlan_id = $daten{'vlan_id'};
my $vlan_name = $daten{'vlan_name'};
my $vlan_num = $daten{'vlan_num'};

if ( $vlan_id !~ /^\d{1,10}/ ) {
	$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{delete_vlan_message}","$vars_file");
	$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (1)")
}

if ( ! $vlan_name || ! $vlan_num ) {
	$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{delete_vlan_message}","$vars_file");
	$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (2)")
}

$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{vlan_deleted_message}: \"$vlan_num - $vlan_name\"","$vars_file");


my $comment = $daten{'vlan_comment'} || "";

my @values_vlan=$gip->get_vlan("$client_id","$vlan_id");
my $asso_vlan_id=$values_vlan[0]->[7] || "";
my $switches=$values_vlan[0]->[6] || "";

if ( $switches ) {
	$switches =~ s/^,//;
	$switches =~ s/,$//;
	my @switches=split(",",$switches);
	my @values_asso_vlan=$gip->get_vlan("$client_id","$asso_vlan_id");
	my $asso_switches=$values_asso_vlan[0]->[6] || "";
	$asso_switches =~ s/^,//;
	$asso_switches =~ s/,$//;
	foreach ( @switches ) {
		if ( $asso_switches =~ /^$_$/ ) {
			$asso_switches = ""; 
		} elsif ( $asso_switches =~ /^$_,/ ) {
			$asso_switches =~ s/^$_,//;
		} elsif ( $asso_switches =~ /,$_,/ ) {
			$asso_switches =~ s/,$_//;
		} elsif ( $asso_switches =~ /,$_$/ ) {
			$asso_switches =~ s/,$_$//;
		}
	}
	$gip->update_vlan_switches("$client_id","$asso_vlan_id","$asso_switches");
}


my @asso_vlans=$gip->get_asso_vlans("$client_id","$vlan_id");
foreach my $assos ( @asso_vlans ) {
	my $asso_id=$assos->[1];
	my $asso_name=$assos->[2];
	my $asso_comment=$assos->[3];
	my $entry=$asso_id . " - " . $asso_name;
	$gip->delete_custom_net_column_entry("$client_id","$entry");	
	$gip->delete_vlan("$client_id","$asso_id","$asso_name");

	my $audit_type="37";
	my $audit_class="7";
	my $update_type_audit="1";
	my $event="$asso_id, $asso_name";
	$event=$event . "," . $asso_comment if $asso_comment;
	$event=$event . " (unified VLAN)";
	$gip->insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");
}

my $vlan_entry = "$vlan_num - $vlan_name";
$gip->delete_vlan("$client_id","$vlan_id","$vlan_entry");


my $audit_type="37";
my $audit_class="7";
my $update_type_audit="1";
my $event="$vlan_num, $vlan_name";
$event=$event . "," . $comment if $comment;
$gip->insert_audit("$client_id","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");


my @vlans=$gip->get_vlans("$client_id");

$gip->PrintVLANTab("$client_id",\@vlans,"show_ip.cgi","detalles","$vars_file");

$gip->print_end("$client_id");

