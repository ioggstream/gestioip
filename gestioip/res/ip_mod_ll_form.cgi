#!/usr/bin/perl -w -T

use strict;
use Socket;
use DBI;
use lib '../modules';
use GestioIP;


my $gip = GestioIP -> new();
my $daten=<STDIN>;
my %daten=$gip->preparer($daten);

my $lang = $daten{'lang'} || "";
my ($lang_vars,$vars_file)=$gip->get_lang("","$lang");
my $base_uri = $gip->get_base_uri();


my $client_id = $daten{'client_id'} || $gip->get_first_client_id();
$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{edit_ll_message}","$vars_file");

my $align="align=\"right\"";
my $align1="";
my $ori="left";
my $rtl_helper="<font color=\"white\">x</font>";
if ( $vars_file =~ /vars_he$/ ) {
        $align="align=\"left\"";
        $align1="align=\"right\"";
        $ori="right";
}

my $ll_id=$daten{'ll_id'} || "";
$gip->print_error("$client_id","$$lang_vars{formato_malo_message}") if ! $ll_id;
my $phone_number=$daten{'phone_number'};
$phone_number = "" if $phone_number eq "0";
my $ll_client_id=$daten{'ll_client_id'};
my $comment=$daten{'comment'} || "";
my $description=$daten{'description'} || "";
my $loc=$daten{'loc'} || "";
my $loc_id=$daten{'loc_id'} || "-1";
my $type=$daten{'type'} || "";
my $service=$daten{'service'} || "";
my $device=$daten{'device'} || "";
my $room=$daten{'room'} || "";
my $ad_number=$daten{'ad_number'} || "";


my @values_clientes=$gip->get_ll_clients("$client_id");
my $anz_ll_clients=$gip->count_ll_clients("$client_id");
my @values_locations=$gip->get_loc_all("$client_id");

print "<p>\n";
print "<form name=\"modll_form\" method=\"POST\" action=\"./ip_mod_ll.cgi\">\n";
print "<table border=\"0\" cellpadding=\"5\" cellspacing=\"2\">\n";

print "<tr><td $align>$$lang_vars{ll_client_message}</td><td $align1>";
my $j=0;
if ( $anz_ll_clients > "1" ) {

        print "<select name=\"ll_client_id\" size=\"1\">";
        print "<option></option>\n";
        my $opt;
        foreach $opt(@values_clientes) {
		if ( $values_clientes[$j]->[0] == "-1" ) {
			$j++;
			next;
		}
		if ( $values_clientes[$j]->[0] == $ll_client_id ) {
			print "<option value=\"$values_clientes[$j]->[0]\" selected>$values_clientes[$j]->[1]</option>";
		} else {
			print "<option value=\"$values_clientes[$j]->[0]\">$values_clientes[$j]->[1]</option>";
		}
                $j++;
        }
        print "</select></td></tr>\n";
} else {
        print "<font color=\"gray\"><i>$$lang_vars{no_ll_clients_message}</i></font></td></tr>\n";
}
print "<tr><td $align>$$lang_vars{tipo_message}</td><td $align1><input name=\"type\" type=\"text\" value=\"$type\" size=\"15\" maxlength=\"50\"></td></tr>\n";
print "<tr><td $align>$$lang_vars{service_message}</td><td $align1><input name=\"service\" type=\"text\" value=\"$service\" size=\"15\" maxlength=\"50\"></td></tr>\n";
print "<tr><td $align>$$lang_vars{description_message}</td><td $align1><input name=\"description\" type=\"text\" value=\"$description\" size=\"15\" maxlength=\"50\"></td></tr>\n";
print "<tr><td $align>$$lang_vars{phone_number_message}</td><td $align1><input name=\"phone_number\" type=\"text\" value=\"$phone_number\" size=\"15\" maxlength=\"30\"></td></tr>\n";
print "<tr><td $align>$$lang_vars{administrative_number_message}</td><td $align1><input name=\"ad_number\" type=\"text\" value=\"$ad_number\"  size=\"15\" maxlength=\"50\"></td></tr>\n";

print "<tr><td $align>$$lang_vars{loc_message}</td><td $align1><select name=\"loc_id\" size=\"1\">";
print "<option value=\"-1\"></option>";

$j=0;
foreach (@values_locations) {
	if ( $values_locations[$j]->[0] eq "-1" ) {
		$j++;
		next;
	}
	if ( $values_locations[$j]->[0] eq $loc_id ) {
		print "<option value=\"$loc_id\" selected>$values_locations[$j]->[1]</option>";
	} else {
		print "<option value=\"$values_locations[$j]->[0]\">$values_locations[$j]->[1]</option>";
	}
	$j++;
}

print "</td><td>";
print "<tr><td $align>$$lang_vars{room_message}</td><td $align1><input name=\"room\" type=\"text\" value=\"$room\" size=\"15\" maxlength=\"100\"></td></tr>\n";
print "<tr><td $align>$$lang_vars{connected_device_message}</td><td $align1><input name=\"device\" type=\"text\" value=\"$device\" size=\"15\" maxlength=\"100\"></td></tr>\n";
print "<tr><td $align>$$lang_vars{comentario_message}</td><td $align1><input name=\"comment\" type=\"text\" value=\"$comment\" size=\"30\" maxlength=\"500\"></td></tr>\n";

print "<td><input type=\"hidden\" name=\"ll_id\" value=\"$ll_id\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><br><input type=\"submit\" value=\"$$lang_vars{submit_message}\" name=\"B2\" class=\"input_link_w\"></td>\n";


print "</table>\n";
print "</form>\n";

print "<p><br><p><br><p>\n";

$gip->print_end("$client_id");

