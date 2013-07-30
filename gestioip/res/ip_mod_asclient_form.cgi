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
$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{edit_as_client_message}","$vars_file");

my $align="align=\"right\"";
my $align1="";
my $ori="left";
my $rtl_helper="<font color=\"white\">x</font>";
if ( $vars_file =~ /vars_he$/ ) {
        $align="align=\"left\"";
        $align1="align=\"right\"";
        $ori="right";
}

my $as_client_id=$daten{'as_client_id'} || "";
$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (1)") if ! $as_client_id;
#my $name=$daten{'name'};
#my $type=$daten{'type'};
#my $comment=$daten{'comment'} || "";
#my $description=$daten{'description'} || "";
#my $phone=$daten{'phone'} || "";
#my $fax=$daten{'fax'} || "";
#my $address=$daten{'address'} || "";
#my $contact=$daten{'contact'} || "";
#my $contact_email=$daten{'contact_email'} || "";
#my $contact_phone=$daten{'contact_phone'} || "";
#my $contact_cell=$daten{'contact_cell'} || "";

my @as_client_values=$gip->get_one_as_client("$client_id","$as_client_id");
my $name=$as_client_values[0]->[1] || "";
my $type=$as_client_values[0]->[2] || "";
my $comment=$as_client_values[0]->[3] || "";
my $description=$as_client_values[0]->[4] || "";
my $phone=$as_client_values[0]->[5] || "";
my $fax=$as_client_values[0]->[6] || "";
my $address=$as_client_values[0]->[7] || "";
my $contact=$as_client_values[0]->[8] || "";
my $contact_email=$as_client_values[0]->[9] || "";
my $contact_phone=$as_client_values[0]->[10] || "";
my $contact_cell=$as_client_values[0]->[11] || "";



#my @values_clientes=$gip->get_as_client("$client_id");
#my $anz_as_client_clients=$gip->count_as_client_clients("$client_id");

print "<p>\n";
print "<form name=\"modas_client_form\" method=\"POST\" action=\"./ip_mod_asclient.cgi\">\n";
print "<table border=\"0\" cellpadding=\"5\" cellspacing=\"1\"><tr><td $align>";
print "$$lang_vars{as_client_name_message}</td><td><input type=\"text\" name=\"name\" value=\"$name\" size=\"10\" maxlength=\"30\"></td></tr>\n";
print "<tr><td $align>$$lang_vars{tipo_message}</td><td $align1><input type=\"text\" name=\"type\" value=\"$type\" size=\"10\" maxlength=\"30\"></td></tr>\n";
print "<tr><td $align>$$lang_vars{comentario_message}</td><td $align1><input type=\"text\" name=\"comment\" value=\"$comment\" size=\"10\" maxlength=\"30\"></td></tr>\n";
print "<tr><td $align>$$lang_vars{description_message}</td><td $align1><input type=\"text\" name=\"description\" value=\"$description\" size=\"10\" maxlength=\"30\"></td></tr>\n";
print "<tr><td $align>$$lang_vars{phone_message}</td><td $align1><input type=\"text\" name=\"phone\" size=\"10\" value=\"$phone\" maxlength=\"30\"></td></tr>\n";
print "<tr><td $align>$$lang_vars{fax_message}</td><td $align1><input type=\"text\" name=\"fax\" value=\"$fax\" size=\"10\" maxlength=\"30\"></td></tr>\n";
print "<tr><td $align>$$lang_vars{address_message}</td><td colspan=\"4\" $align1><textarea name=\"address\" cols=\"40\" rows=\"4\" maxlength=\"500\">$address</textarea></td></tr>\n";
print "<tr><td $align>$$lang_vars{contact_message}</td><td $align1><input type=\"text\" name=\"contact\" value=\"$contact\" size=\"10\" maxlength=\"30\"></td><td $align>&nbsp;&nbsp;$$lang_vars{mail_message}</td><td $align1><input type=\"text\" name=\"contact_email\" value=\"$contact_email\" size=\"10\" maxlength=\"30\"></td><td $align>&nbsp;&nbsp;$$lang_vars{phone_message}</td><td $align1><input type=\"text\" name=\"contact_phone\" value=\"$contact_phone\" size=\"10\" maxlength=\"30\"></td><td $align>&nbsp;&nbsp;$$lang_vars{cell_message}</td><td $align1><input type=\"text\" name=\"contact_cell\" value=\"$contact_cell\" size=\"10\" maxlength=\"30\"></td></tr>\n";
print "<tr><td $align1><p><input type=\"hidden\" name=\"as_client_id\" value=\"$as_client_id\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"submit\" value=\"$$lang_vars{submit_message}\" name=\"B2\" class=\"input_link_w\"><input type=\"hidden\" name=\"admin_type\" value=\"as_client_add\"></form></td><td></td></tr></table>\n";

print "</form>\n";

print "<p><br><p><br><p>\n";

$gip->print_end("$client_id");

