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
$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{edit_as_message}","$vars_file");

my $align="align=\"right\"";
my $align1="";
my $ori="left";
my $rtl_helper="<font color=\"white\">x</font>";
if ( $vars_file =~ /vars_he$/ ) {
        $align="align=\"left\"";
        $align1="align=\"right\"";
        $ori="right";
}

my $as_id=$daten{'as_id'} || "";
$gip->print_error("$client_id","$$lang_vars{formato_malo_message}") if ! $as_id;
my $as_number=$daten{'as_number'};
my $as_client_id=$daten{'as_client_id'};
my $comment=$daten{'comment'} || "";
my $description=$daten{'description'} || "";


my @values_clientes=$gip->get_as_clients("$client_id");
my $anz_as_clients=$gip->count_as_clients("$client_id");

print "<p>\n";
print "<form name=\"modas_form\" method=\"POST\" action=\"./ip_mod_as.cgi\">\n";
print "<table border=\"0\" cellpadding=\"5\" cellspacing=\"2\">\n";

print "<tr><td $align>$$lang_vars{as_number_message}</td><td $align1><b>$as_number</b></td></tr>\n";
print "<tr><td $align>$$lang_vars{description_message}</td><td $align1><input name=\"description\" type=\"text\" value=\"$description\"  size=\"15\" maxlength=\"50\"></td></tr>\n";
print "<tr><td $align>$$lang_vars{comentario_message}</td><td $align1><input name=\"comment\" type=\"text\" value=\"$comment\" size=\"30\" maxlength=\"500\"></td></tr>\n";
print "<tr><td $align>$$lang_vars{as_client_message}</td><td $align1>";
my $j=0;
if ( $anz_as_clients > "1" ) {

        print "<select name=\"as_client_id\" size=\"1\">";
        print "<option></option>\n";
        my $opt;
        foreach $opt(@values_clientes) {
		if ( $values_clientes[$j]->[0] == "-1" ) {
			$j++;
			next;
		}
		if ( $values_clientes[$j]->[0] == $as_client_id ) {
			print "<option value=\"$values_clientes[$j]->[0]\" selected>$values_clientes[$j]->[1]</option>";
		} else {
			print "<option value=\"$values_clientes[$j]->[0]\">$values_clientes[$j]->[1]</option>";
		}
                $j++;
        }
        print "</select></td></tr>\n";
} else {
        print "<font color=\"gray\"><i>$$lang_vars{no_as_clients_message}</i></font></td></tr>\n";
}

print "<td><input type=\"hidden\" name=\"as_id\" value=\"$as_id\"><input type=\"hidden\" name=\"as_number\" value=\"$as_number\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><br><input type=\"submit\" value=\"$$lang_vars{submit_message}\" name=\"B2\" class=\"input_link_w\"></td>\n";


print "</table>\n";
print "</form>\n";

print "<p><br><p><br><p>\n";

$gip->print_end("$client_id");

