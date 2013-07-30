#!/usr/bin/perl -T -w

# Copyright (C) 2011 Marc Uebel

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


use strict;
use lib '../modules';
use GestioIP;
use Net::IP;
use Net::IP qw(:PROC);


my $daten=<STDIN>;
my $gip = GestioIP -> new();
my %daten=$gip->preparer($daten);

my $base_uri = $gip->get_base_uri();
my $server_proto=$gip->get_server_proto();

my $lang = $daten{'lang'} || "";
my ($lang_vars,$vars_file,$entries_per_page_hosts);
($lang_vars,$vars_file)=$gip->get_lang("","$lang");

if ( $daten{'entries_per_page_hosts'} && $daten{'entries_per_page_hosts'} =~ /^\d{1,4}$/ ) {
        $entries_per_page_hosts=$daten{'entries_per_page_hosts'};
} else {
        $entries_per_page_hosts = "254";
}

my $client_id = $daten{'client_id'} || $gip->get_first_client_id();


if ( $daten{'client_name'} && $daten{'client_name'} eq "DEFAULT" ) {
        $gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{manage_clients_message}","$vars_file");
        $gip->print_error("$client_id","$$lang_vars{palabra_reservada_client_default_message}");
}

my $client_name = $daten{'client_name'} || $gip->get_client_from_id("$client_id");
my $client_action = $daten{'client_action'} || "";
my $mode = $daten{'mode'} || "show_client";
my $B1_mod = "0";
$B1_mod = "1" if $ENV{HTTP_REFERER} !~ /ip_modclient.cgi/;
$B1_mod = "1" if $daten{'B1_mod'};

my ( $phone,$fax,$address,$comment,$contact_name_1,$contact_phone_1,$contact_cell_1,$contact_email_1,$contact_comment_1,$contact_name_2,$contact_phone_2,$contact_cell_2,$contact_email_2,$contact_comment_2,$contact_name_3,$contact_phone_3,$contact_cell_3,$contact_email_3,$contact_comment_3,$onclick);

$phone=$daten{'phone'} || "";
$fax=$daten{'fax'} || "";
$comment=$daten{'comment'} || "";
$contact_name_1=$daten{'contact_name_1'} || "";
$contact_phone_1=$daten{'contact_phone_1'} || "";
$contact_cell_1=$daten{'contact_cell_1'} || "";
$contact_email_1=$daten{'contact_email_1'} || "";
$contact_comment_1=$daten{'contact_comment_1'} || "";
$contact_name_2=$daten{'contact_name_2'} || "";
$contact_phone_2=$daten{'contact_phone_2'} || "";
$contact_cell_2=$daten{'contact_cell_2'} || "";
$contact_email_2=$daten{'contact_email_2'} || "";
$contact_comment_2=$daten{'contact_comment_2'} || "";
$contact_name_3=$daten{'contact_name_3'} || "";
$contact_phone_3=$daten{'contact_phone_3'} || "";
$contact_cell_3=$daten{'contact_cell_3'} || "";
$contact_email_3=$daten{'contact_email_3'} || "";
$contact_comment_3=$daten{'contact_comment_3'} || "";

my @clients = $gip->get_clients();
my @client_entries = $gip->get_client_entries("$client_id");
my $client_name_db=$gip->get_client_from_id("$client_id");
my $count_clients=$gip->count_clients();
my $last_client_id=$gip->get_last_client_id();

my $anz_red_client=$gip->count_red_entries_client("$client_id") || "0";
my $anz_host_client=$gip->count_host_entries_client("$client_id") || "0";

my $align="align=\"right\"";
my $align1="";
my $ori="left";
if ( $vars_file =~ /vars_he$/ ) {
	$align="align=\"left\"";
	$align1="align=\"right\"";
	$ori="right";
}


my $title_message = "";
if ( $client_action eq "insert_client" ) {
	$title_message=$$lang_vars{client_added_message};
	if ( ! $daten{'client_name'} ) {
		$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{manage_clients_message}","$vars_file");
		$gip->print_error("$client_id","$$lang_vars{introduce_client_name_message}");
	}
	if ( $daten{'client_name'} !~ /^.{2,30}$/ ) {
		$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{manage_clients_message}","$vars_file");
		$gip->print_error("$client_id","$$lang_vars{max_signos_clientname_message}");
	}
	if ( ! $daten{'loc'} ) {
		$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{manage_clients_message}","$vars_file");
		$gip->print_error("$client_id","$$lang_vars{introduce_loc_min_message}");
	}
	foreach my $ele( @clients ) {
		if ( $ele->[1] eq $client_name ) {
			$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{manage_clients_message}","$vars_file");
			$gip->print_error("$client_id","<i>$client_name</i>: $$lang_vars{client_exists_message}") if $ele->[1] eq $client_name;
		}
	}
	$last_client_id++;
	$client_id = $last_client_id;
	$address = $daten{'address'} || "";
	$comment = $daten{'comment'} || "";
	my $loc = $daten{'loc'} || "";

	if ( $loc ) {
		$loc =~ s/[\n\r\f\t]+//g;
		$loc =~ s/,\s*/,/g;
		$loc =~ s/\s*,/,/g;
		my @values_loc=split(",",$loc);
		foreach my $locs(@values_loc) {
			$locs =~ s/^\s*//;
			if ( $locs !~ /^.{1,30}$/ ) {
				$gip->print_error("$client_id","$$lang_vars{max_signos_loc_message}");
			}
		}
		foreach my $locs(@values_loc) {
			my $last_loc_id=$gip->get_last_loc_id("$client_id");
			$last_loc_id++;
			$gip->loc_add("$client_id","$locs","$last_loc_id");

		}
	}

	$gip->insert_client("$last_client_id","$client_name");
	$gip->insert_client_entry("$last_client_id", "$phone", "$fax", "$address", "$comment", "$contact_name_1", "$contact_phone_1", "$contact_cell_1", "$contact_email_1", "$contact_comment_1", "$contact_name_2", "$contact_phone_2", "$contact_cell_2", "$contact_email_2", "$contact_comment_2", "$contact_name_3", "$contact_phone_3", "$contact_cell_3", "$contact_email_3", "$contact_comment_3");

	my @config = $gip->get_config("$client_id");
	$gip->insert_config("$client_id","22","254","","yes","","no","n","2");


	my $audit_type="33";
	my $audit_class="5";
	my $update_type_audit="1";
	my $event="$client_name";
	$gip->insert_audit("9999","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");

	@clients = $gip->get_clients();
	@client_entries = $gip->get_client_entries("$client_id");

} elsif ( $client_action eq "delete_client" ) {
	$title_message=$$lang_vars{client_deleted_message};

	if ( $count_clients == "1" ) {
		$gip->delete_client("$client_id");
		$gip->insert_client("1","DEFAULT");
		$gip->update_default_client("1","1");
		$gip->insert_config("1","16","254","","yes","","no","n","2","yes");
		$gip->insert_client_entry("1");
	} else {
		my $default_client_id=$gip->get_default_client_id("$client_id") || "1";
		$gip->delete_client("$client_id");
		$gip->delete_config("$client_id");
		$gip->update_default_client("1","1") if $default_client_id == $client_id;
	}


	my $audit_type="34";
	my $audit_class="5";
	my $update_type_audit="1";
	my $event="$client_name";
	$gip->insert_audit("9999","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");



	$last_client_id=$gip->get_last_client_id();
	$client_id = $last_client_id;
	@clients = $gip->get_clients();
	@client_entries = $gip->get_client_entries("$client_id");

	$client_name = $client_entries[0]->[0];
	$phone=$client_entries[0]->[1] || "";
	$fax=$client_entries[0]->[2] || "";
	$address = $client_entries[0]->[3] || "";
	$comment=$client_entries[0]->[4] || "";
	$contact_name_1=$client_entries[0]->[5] || "";
	$contact_phone_1=$client_entries[0]->[6] || "";
	$contact_cell_1=$client_entries[0]->[7] || "";
	$contact_email_1=$client_entries[0]->[8] || "";
	$contact_comment_1=$client_entries[0]->[9] || "";
	$contact_name_2=$client_entries[0]->[10] || "";
	$contact_phone_2=$client_entries[0]->[11] || "";
	$contact_cell_2=$client_entries[0]->[12] || "";
	$contact_email_2=$client_entries[0]->[13] || "";
	$contact_comment_2=$client_entries[0]->[14] || "";
	$contact_name_3=$client_entries[0]->[15] || "";
	$contact_phone_3=$client_entries[0]->[16] || "";
	$contact_cell_3=$client_entries[0]->[17] || "";
	$contact_email_3=$client_entries[0]->[18] || "";
	$contact_comment_3=$client_entries[0]->[19] || "";


} elsif ( $client_action eq "mod_client" ) {
	$title_message=$$lang_vars{client_modificado_message};
	if ( ! $daten{'client_name'} ) {
		$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{manage_clients_message}","$vars_file");
		$gip->print_error("$client_id","$$lang_vars{introduce_client_name_message}");
	}
	foreach my $ele( @clients ) {
		if ( $ele->[1] eq $client_name && $client_name ne $client_name_db) {
			$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{manage_clients_message}","$vars_file");
			$gip->print_error("$client_id","<i>$client_name</i>: $$lang_vars{client_exists_message}") if $ele->[1] eq $client_name;
		}
	}
	$address = $daten{'address'};
	$comment = $daten{'comment'};
	if ( $client_name ne $client_name_db ) {
		$gip->update_client("$client_id","$client_name");
		@clients = $gip->get_clients();
	}
	if ( $clients[0]->[1] eq "DEFAULT" && ! $client_entries[0] ) {
		$gip->update_client("$client_id","$client_name");
		@clients = $gip->get_clients();
	}
	if ( $client_entries[0] ) {
		$gip->update_client_entry("$client_id", "$phone", "$fax", "$address", "$comment", "$contact_name_1", "$contact_phone_1", "$contact_cell_1", "$contact_email_1", "$contact_comment_1", "$contact_name_2", "$contact_phone_2", "$contact_cell_2", "$contact_email_2", "$contact_comment_2", "$contact_name_3", "$contact_phone_3", "$contact_cell_3", "$contact_email_3", "$contact_comment_3");
	} else {
		$gip->insert_client_entry("$client_id", "$phone", "$fax", "$address", "$comment", "$contact_name_1", "$contact_phone_1", "$contact_cell_1", "$contact_email_1", "$contact_comment_1", "$contact_name_2", "$contact_phone_2", "$contact_cell_2", "$contact_email_2", "$contact_comment_2", "$contact_name_3", "$contact_phone_3", "$contact_cell_3", "$contact_email_3", "$contact_comment_3");
	}

	my $audit_type="35";
	if ( $count_clients == "1" ) {
		$audit_type="33";
	}
	my $audit_class="5";
	my $update_type_audit="1";
	my $event="$client_name";
	$gip->insert_audit("9999","$audit_class","$audit_type","$event","$update_type_audit","$vars_file");

} elsif ( $client_action eq "update_view" ) {

	$client_name = $client_entries[0]->[0];
	$phone=$client_entries[0]->[1] || "";
	$fax=$client_entries[0]->[2] || "";
	$address = $client_entries[0]->[3] || "";
	$comment=$client_entries[0]->[4] || "";
	$contact_name_1=$client_entries[0]->[5] || "";
	$contact_phone_1=$client_entries[0]->[6] || "";
	$contact_cell_1=$client_entries[0]->[7] || "";
	$contact_email_1=$client_entries[0]->[8] || "";
	$contact_comment_1=$client_entries[0]->[9] || "";
	$contact_name_2=$client_entries[0]->[10] || "";
	$contact_phone_2=$client_entries[0]->[11] || "";
	$contact_cell_2=$client_entries[0]->[12] || "";
	$contact_email_2=$client_entries[0]->[13] || "";
	$contact_comment_2=$client_entries[0]->[14] || "";
	$contact_name_3=$client_entries[0]->[15] || "";
	$contact_phone_3=$client_entries[0]->[16] || "";
	$contact_cell_3=$client_entries[0]->[17] || "";
	$contact_email_3=$client_entries[0]->[18] || "";
	$contact_comment_3=$client_entries[0]->[19] || "";
} else {
	$client_name = $client_entries[0]->[0];
	$phone=$client_entries[0]->[1] || "";
	$fax=$client_entries[0]->[2] || "";
	$address = $client_entries[0]->[3] || "";
	$comment=$client_entries[0]->[4] || "";
	$contact_name_1=$client_entries[0]->[5] || "";
	$contact_phone_1=$client_entries[0]->[6] || "";
	$contact_cell_1=$client_entries[0]->[7] || "";
	$contact_email_1=$client_entries[0]->[8] || "";
	$contact_comment_1=$client_entries[0]->[9] || "";
	$contact_name_2=$client_entries[0]->[10] || "";
	$contact_phone_2=$client_entries[0]->[11] || "";
	$contact_cell_2=$client_entries[0]->[12] || "";
	$contact_email_2=$client_entries[0]->[13] || "";
	$contact_comment_2=$client_entries[0]->[14] || "";
	$contact_name_3=$client_entries[0]->[15] || "";
	$contact_phone_3=$client_entries[0]->[16] || "";
	$contact_cell_3=$client_entries[0]->[17] || "";
	$contact_email_3=$client_entries[0]->[18] || "";
	$contact_comment_3=$client_entries[0]->[19] || "";
}

if ( $title_message ) {
	$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{manage_clients_message}: $title_message","$vars_file");
} else {
	$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{manage_clients_message}","$vars_file");
}

if ( $clients[0]->[1] eq "DEFAULT" && $count_clients == "1" ) {

	print "<br><b style=\"float: $ori\">$$lang_vars{define_client_message}</b><br><p>\n";
	print "<p><form name=\"insert_client_form\" method=\"POST\" action=\"$server_proto://$base_uri/res/ip_modclient.cgi\">\n";
	print "<table border=\"0\">\n";
	print "<tr><td $align>$$lang_vars{client_message}</td><td $align1><input name=\"client_name\" type=\"text\"  size=\"15\" maxlength=\"30\"></td></tr>";

	print "<tr><td $align><img src=\"$server_proto://$base_uri/imagenes/telefon.png\" title=\"$$lang_vars{phone_message}\"></td><td colspan=\"9\" $align1><input name=\"phone\" type=\"text\"  size=\"15\" maxlength=\"30\" value=\"\"></td></tr>";
	print "<tr><td $align><img src=\"$server_proto://$base_uri/imagenes/fax.png\" title=\"$$lang_vars{fax_message}\"></td><td colspan=\"9\" $align1><input name=\"fax\" type=\"text\"  size=\"15\" maxlength=\"30\" value=\"\"></td></tr>";
	print "<tr><td $align>$$lang_vars{address_message}</td><td colspan=\"9\" $align1><textarea name=\"address\" cols=\"40\" rows=\"4\" maxlength=\"500\">$address</textarea></td></tr>";
	print "<tr><td $align>$$lang_vars{comentario_message}</td><td colspan=\"9\" $align1><input name=\"comment\" type=\"text\"  size=\"35\" maxlength=\"200\" value=\"$comment\"></td></tr>";
	print "<tr><td colspan=\"10\"></td></tr>\n";
	print "<tr nowrap><td $align>$$lang_vars{contact_message}</td><td $align1><input name=\"contact_name_1\" type=\"text\" size=\"18\" maxlength=\"200\" value=\"$contact_name_1\"></td><td>&nbsp; <img src=\"$server_proto://$base_uri/imagenes/telefon.png\" title=\"$$lang_vars{phone_message}\"></td><td><input name=\"contact_phone_1\" type=\"text\"  size=\"12\" maxlength=\"25\" value=\"$contact_phone_1\"></td><td>&nbsp; <img src=\"$server_proto://$base_uri/imagenes/handy.png\" title=\"$$lang_vars{cell_message}\"></td><td><input name=\"contact_cell_1\" type=\"text\"  size=\"10\" maxlength=\"25\" value=\"$contact_cell_1\"> </td><td>&nbsp; <img src=\"$server_proto://$base_uri/imagenes/email.png\" title=\"$$lang_vars{mail_message}\"></td><td><input name=\"contact_email_1\" type=\"text\"  size=\"15\" maxlength=\"50\" value=\"$contact_email_1\"> </td><td>&nbsp; $$lang_vars{comentario_message}</td><td><input name=\"contact_comment_1\" type=\"text\"  size=\"22\" maxlength=\"50\" value=\"$contact_comment_1\"></td></tr>";
	print "<tr nowrap><td $align>$$lang_vars{contact_message}</td><td $align1><input name=\"contact_name_2\" type=\"text\" size=\"18\" maxlength=\"200\" value=\"$contact_name_2\"></td><td>&nbsp; <img src=\"$server_proto://$base_uri/imagenes/telefon.png\" title=\"$$lang_vars{phone_message}\"></td><td><input name=\"contact_phone_2\" type=\"text\"  size=\"12\" maxlength=\"25\" value=\"$contact_phone_2\"></td><td>&nbsp; <img src=\"$server_proto://$base_uri/imagenes/handy.png\" title=\"$$lang_vars{cell_message}\"></td><td><input name=\"contact_cell_2\" type=\"text\"  size=\"10\" maxlength=\"25\" value=\"$contact_cell_2\"> </td><td>&nbsp; <img src=\"$server_proto://$base_uri/imagenes/email.png\" title=\"$$lang_vars{mail_message}\"></td><td><input name=\"contact_email_2\" type=\"text\"  size=\"15\" maxlength=\"50\" value=\"$contact_email_2\"> </td><td>&nbsp; $$lang_vars{comentario_message}</td><td><input name=\"contact_comment_2\" type=\"text\"  size=\"22\" maxlength=\"50\" value=\"$contact_comment_2\"></td></tr>";
	print "<tr nowrap><td $align>$$lang_vars{contact_message}</td><td $align1><input name=\"contact_name_3\" type=\"text\" size=\"18\" maxlength=\"200\" value=\"$contact_name_3\"></td><td>&nbsp; <img src=\"$server_proto://$base_uri/imagenes/telefon.png\" title=\"$$lang_vars{phone_message}\"></td><td><input name=\"contact_phone_3\" type=\"text\"  size=\"12\" maxlength=\"25\" value=\"$contact_phone_3\"></td><td>&nbsp; <img src=\"$server_proto://$base_uri/imagenes/handy.png\" title=\"$$lang_vars{cell_message}\"></td><td><input name=\"contact_cell_3\" type=\"text\"  size=\"10\" maxlength=\"25\" value=\"$contact_cell_3\"> </td><td>&nbsp; <img src=\"$server_proto://$base_uri/imagenes/email.png\" title=\"$$lang_vars{mail_message}\"></td><td><input name=\"contact_email_3\" type=\"text\"  size=\"15\" maxlength=\"50\" value=\"$contact_email_3\"> </td><td>&nbsp; $$lang_vars{comentario_message}</td><td><input name=\"contact_comment_3\" type=\"text\"  size=\"22\" maxlength=\"50\" value=\"$contact_comment_3\"></td></tr>";
	print "<tr><td><br><input name=\"client_action\" type=\"hidden\" value=\"mod_client\"><input type=\"submit\" value=\"$$lang_vars{crear_message}\" name=\"B1\" class=\"input_link_w\"></td><td></td></tr>";
	print "</table>\n";
	print "</form>\n";
	print "<p><br>\n";

	$gip->print_end("$client_id","$vars_file","go_to_top");
}


my $j = 0;
if ( $mode eq "show_client" && $B1_mod == "1" ) {

$address=~s//<br>/g;

print <<EOF;
<script type="text/javascript">
function DisableEnableForm(xForm,xHow){
objElems = xForm.elements;
for(i=0;i<objElems.length;i++){
objElems[i].disabled = xHow;
}
}
</script>

<script type="text/javascript">
<!--
function confirmation() {

	var SI=document.modificar_client_form.client_id.selectedIndex;
	var CLIENT= document.modificar_client_form.client_id[SI].text;

        answer = confirm(CLIENT + ": $$lang_vars{delete_client_confirme_message}?")

        if (answer){
                return true;
        }
        else{
                return false;
        }

}
//-->
</script>

EOF

	my $confirmation = $gip->get_config_confirmation("$client_id") || "yes";
	$onclick = "";
	if ( $confirmation eq "yes" ) {
		$onclick =  "onclick=\"return confirmation();\"";
	}


	print "<p><b style=\"float: $ori\">$$lang_vars{edit_client_message}</b><br>\n";
	print "<p><form name=\"modificar_client_form\" id=\"modificar_client_form\" method=\"POST\" action=\"$server_proto://$base_uri/res/ip_modclient.cgi\">\n";
	print "<table border=\"0\">\n";
	print "<tr><td $align>$$lang_vars{client_message}</td><td colspan=\"1\" $align1>";

	print "<select name=\"client_id\" id=\"client_id\" size=\"1\" onchange=\"DisableEnableForm(document.modificar1_client_form,true);B2_mod.style.display='none';B1_mod.style.display='inline';\">\n";
	$j=0;
	foreach (@clients) {
		if ( $clients[$j]->[0] == "$client_id") {
			print "<option value=\"$clients[$j]->[0]\" selected>$clients[$j]->[1]</option>";
			$j++;
			next;
		}
		print "<option value=\"$clients[$j]->[0]\">$clients[$j]->[1]</option>";
		$j++;
	}
	print "</select>\n";

	print "</td><td colspan=\"8\"><input name=\"client_action\" type=\"hidden\" value=\"update_view\"><input type=\"submit\" value=\"\" name=\"B2_mod\" class=\"edit_client_button\" id=\"B2_mod\" style='display:inline;' title=\"$$lang_vars{actualize_client}\">\n";
#	print "<input name=\"client_action\" type=\"hidden\" value=\"update_view\"><input name=\"mode\" type=\"hidden\" value=\"edit_client\"> <input type=\"submit\" value=\"\" name=\"B2_mod\" class=\"edit_button\" id=\"B2_mod\" style='display:inline;' title=\"$$lang_vars{actualize_client}\">\n";

	print "<input name=\"mode\" type=\"hidden\" value=\"show_client\"> <input type=\"submit\" value=\" \" name=\"B1_mod\" class=\"change_client_button\" id=\"B1_mod\" style='display:none;' title=\"$$lang_vars{actualize_client}\" onclick=\"B2.style.display='inline';\">\n";

	print "</form></td></tr>";

	print "<tr><td $align colspan=\"10\"><form name=\"modificar1_client_form\" id=\"modificar1_client_form\" method=\"POST\" action=\"$server_proto://$base_uri/res/ip_modclient.cgi\">\n";
print "</td></tr>";

	print "<tr><td $align><img src=\"$server_proto://$base_uri/imagenes/telefon.png\" title=\"$$lang_vars{phone_message}\"></td><td colspan=\"9\" $align1>$phone</td></tr>" if $phone;
	print "<tr><td $align><img src=\"$server_proto://$base_uri/imagenes/fax.png\" title=\"$$lang_vars{fax_message}\"></td><td colspan=\"9\" $align1>$fax</td></tr>" if $fax;
	print "<tr><td $align valign=\"top\"><b>$$lang_vars{address_message}</b></td><td colspan=\"9\" $align1>$address</td></tr>" if $address;
	print "<tr><td $align><b>$$lang_vars{comentario_message}</b></td><td colspan=\"9\" $align1>$comment</td></tr>" if $comment;
	print "<tr><td colspan=\"10\"></td></tr>\n";
	print "<tr nowrap><td $align><b>$$lang_vars{contact_message}</b></td><td>$contact_name_1</td><td>&nbsp; <img src=\"$server_proto://$base_uri/imagenes/telefon.png\" title=\"$$lang_vars{phone_message}\"></td><td>$contact_phone_1</td><td>&nbsp; <img src=\"$server_proto://$base_uri/imagenes/handy.png\" title=\"$$lang_vars{cell_message}\"></td><td>$contact_cell_1</td><td>&nbsp; <img src=\"$server_proto://$base_uri/imagenes/email.png\" title=\"$$lang_vars{mail_message}\"></td><td>$contact_email_1 </td><td>&nbsp;</td><td>$contact_comment_1</td></tr>\n" if $contact_name_1;
	print "<tr nowrap><td $align><b>$$lang_vars{contact_message}</b></td><td>$contact_name_2</td><td>&nbsp; <img src=\"$server_proto://$base_uri/imagenes/telefon.png\" title=\"$$lang_vars{phone_message}\"></td><td>$contact_phone_2</td><td>&nbsp; <img src=\"$server_proto://$base_uri/imagenes/handy.png\" title=\"$$lang_vars{cell_message}\"></td><td>$contact_cell_2 </td><td>&nbsp; <img src=\"$server_proto://$base_uri/imagenes/email.png\" title=\"$$lang_vars{mail_message}\"></td><td>$contact_email_2 </td><td>&nbsp;</td><td>$contact_comment_2</td></tr>\n" if $contact_name_2;
	print "<tr nowrap><td $align><b>$$lang_vars{contact_message}</b></td><td>$contact_name_3</td><td>&nbsp; <img src=\"$server_proto://$base_uri/imagenes/telefon.png\" title=\"$$lang_vars{phone_message}\"></td><td>$contact_phone_3</td><td>&nbsp; <img src=\"$server_proto://$base_uri/imagenes/handy.png\" title=\"$$lang_vars{cell_message}\"></td><td>$contact_cell_3 </td><td>&nbsp; <img src=\"$server_proto://$base_uri/imagenes/email.png\" title=\"$$lang_vars{mail_message}\"></td><td>$contact_email_3 </td><td>&nbsp;</td><td>$contact_comment_3</td></tr>\n" if $contact_name_3;
	print "</table>\n";
	print "</form>\n";
	print "<p><br>\n";

} else {
$j=0;

print <<EOF;
<script type="text/javascript">
function DisableEnableForm(xForm,xHow){
objElems = xForm.elements;
for(i=0;i<objElems.length;i++){
objElems[i].disabled = xHow;
}
}
</script>

<script type="text/javascript">
<!--
function confirmation() {

	var SI=document.modificar_client_form.client_id.selectedIndex;
	var CLIENT= document.modificar_client_form.client_id[SI].text;

        answer = confirm(CLIENT + ": $$lang_vars{delete_client_confirme_message}?")

        if (answer){
                return true;
        }
        else{
                return false;
        }

}
//-->
</script>

EOF

my $confirmation = $gip->get_config_confirmation("$client_id") || "yes";
$onclick = "";
if ( $confirmation eq "yes" ) {
        $onclick =  "onclick=\"return confirmation();\"";
}


print "<p><b style=\"float: $ori\">$$lang_vars{edit_client_message}</b><br>\n";
print "<p><form name=\"modificar_client_form\" id=\"modificar_client_form\" method=\"POST\" action=\"$server_proto://$base_uri/res/ip_modclient.cgi\">\n";
print "<table border=\"0\">\n";
print "<tr><td $align>$$lang_vars{client_message}</td><td colspan=\"9\" $align1>";

print "<select name=\"client_id\" id=\"client_id\" size=\"1\" onchange=\"DisableEnableForm(document.modificar1_client_form,true);B1.style.display='inline';\">\n";
foreach (@clients) {
	if ( $clients[$j]->[0] == "$client_id") {
		print "<option value=\"$clients[$j]->[0]\" selected>$clients[$j]->[1]</option>";
		$j++;
		next;
	}
	print "<option value=\"$clients[$j]->[0]\">$clients[$j]->[1]</option>";
	$j++;
}
print "<input name=\"client_action\" type=\"hidden\" value=\"update_view\"><input name=\"mode\" type=\"hidden\" value=\"$mode\"> <input type=\"submit\" value=\"\" name=\"B1\" class=\"change_client_button\" id=\"B1\" style='display:none;' title=\"$$lang_vars{actualize_client}\"></form></td></tr>";

print "<tr><td colspan=\"10\"></td></tr>\n";

print "<tr><td $align><form name=\"modificar1_client_form\" id=\"modificar1_client_form\" method=\"POST\" action=\"$server_proto://$base_uri/res/ip_modclient.cgi\">$$lang_vars{client_message}</td><td colspan=\"9\" $align1><input name=\"client_name\" type=\"text\"  size=\"15\" maxlength=\"30\" value=\"$client_name\"></td></tr>";

print "<tr><td $align><img src=\"$server_proto://$base_uri/imagenes/telefon.png\" title=\"$$lang_vars{phone_message}\"></td><td colspan=\"9\" $align1><input name=\"phone\" type=\"text\"  size=\"15\" maxlength=\"30\" value=\"$phone\"></td></tr>";
print "<tr><td $align><img src=\"$server_proto://$base_uri/imagenes/fax.png\" title=\"$$lang_vars{fax_message}\"></td><td colspan=\"9\" $align1><input name=\"fax\" type=\"text\"  size=\"15\" maxlength=\"30\" value=\"$fax\"></td></tr>";
print "<tr><td $align>$$lang_vars{address_message}</td><td colspan=\"9\" $align1><textarea name=\"address\" cols=\"40\" rows=\"4\" maxlength=\"500\">$address</textarea></td></tr>";
print "<tr><td $align>$$lang_vars{comentario_message}</td><td colspan=\"9\" $align1><input name=\"comment\" type=\"text\"  size=\"35\" maxlength=\"200\" value=\"$comment\"></td></tr>";
print "<tr><td colspan=\"10\"></td></tr>\n";
print "<tr nowrap><td $align>$$lang_vars{contact_message}</td><td><input name=\"contact_name_1\" type=\"text\" size=\"18\" maxlength=\"200\" value=\"$contact_name_1\"></td><td>&nbsp; <img src=\"$server_proto://$base_uri/imagenes/telefon.png\" title=\"$$lang_vars{phone_message}\"></td><td><input name=\"contact_phone_1\" type=\"text\"  size=\"12\" maxlength=\"25\" value=\"$contact_phone_1\"></td><td>&nbsp; <img src=\"$server_proto://$base_uri/imagenes/handy.png\" title=\"$$lang_vars{cell_message}\"></td><td><input name=\"contact_cell_1\" type=\"text\"  size=\"10\" maxlength=\"25\" value=\"$contact_cell_1\"> </td><td>&nbsp; <img src=\"$server_proto://$base_uri/imagenes/email.png\" title=\"$$lang_vars{mail_message}\"></td><td><input name=\"contact_email_1\" type=\"text\"  size=\"15\" maxlength=\"50\" value=\"$contact_email_1\"> </td><td>&nbsp; $$lang_vars{comentario_message}</td><td><input name=\"contact_comment_1\" type=\"text\"  size=\"22\" maxlength=\"50\" value=\"$contact_comment_1\"></td></tr>";
print "<tr nowrap><td $align>$$lang_vars{contact_message}</td><td><input name=\"contact_name_2\" type=\"text\" size=\"18\" maxlength=\"200\" value=\"$contact_name_2\"></td><td>&nbsp; <img src=\"$server_proto://$base_uri/imagenes/telefon.png\" title=\"$$lang_vars{phone_message}\"></td><td><input name=\"contact_phone_2\" type=\"text\"  size=\"12\" maxlength=\"25\" value=\"$contact_phone_2\"></td><td>&nbsp; <img src=\"$server_proto://$base_uri/imagenes/handy.png\" title=\"$$lang_vars{cell_message}\"></td><td><input name=\"contact_cell_2\" type=\"text\"  size=\"10\" maxlength=\"25\" value=\"$contact_cell_2\"> </td><td>&nbsp; <img src=\"$server_proto://$base_uri/imagenes/email.png\" title=\"$$lang_vars{mail_message}\"></td><td><input name=\"contact_email_2\" type=\"text\"  size=\"15\" maxlength=\"50\" value=\"$contact_email_2\"> </td><td>&nbsp; $$lang_vars{comentario_message}</td><td><input name=\"contact_comment_2\" type=\"text\"  size=\"22\" maxlength=\"50\" value=\"$contact_comment_2\"></td></tr>";
print "<tr nowrap><td $align>$$lang_vars{contact_message}</td><td><input name=\"contact_name_3\" type=\"text\" size=\"18\" maxlength=\"200\" value=\"$contact_name_3\"></td><td>&nbsp; <img src=\"$server_proto://$base_uri/imagenes/telefon.png\" title=\"$$lang_vars{phone_message}\"></td><td><input name=\"contact_phone_3\" type=\"text\"  size=\"12\" maxlength=\"25\" value=\"$contact_phone_3\"></td><td>&nbsp; <img src=\"$server_proto://$base_uri/imagenes/handy.png\" title=\"$$lang_vars{cell_message}\"></td><td><input name=\"contact_cell_3\" type=\"text\"  size=\"10\" maxlength=\"25\" value=\"$contact_cell_3\"> </td><td>&nbsp; <img src=\"$server_proto://$base_uri/imagenes/email.png\" title=\"$$lang_vars{mail_message}\"></td><td><input name=\"contact_email_3\" type=\"text\"  size=\"15\" maxlength=\"50\" value=\"$contact_email_3\"> </td><td>&nbsp; $$lang_vars{comentario_message}</td><td><input name=\"contact_comment_3\" type=\"text\"  size=\"22\" maxlength=\"50\" value=\"$contact_comment_3\"></td></tr>";
print "<tr><td><br><input name=\"client_action\" type=\"hidden\" value=\"mod_client\"><input name=\"client_id\" type=\"hidden\" value=\"$client_id\"><input name=\"mode\" type=\"hidden\" value=\"$mode\"><input type=\"submit\" value=\"$$lang_vars{update_message}\" name=\"B1\" id=\"B1\" class=\"input_link_w\"></td><td></td></tr>";
print "</table>\n";
print "</form>\n";
print "<p><br>\n";

}


print "<p><b style=\"float: $ori\">$$lang_vars{add_client_message}</b><br>\n";

print "<p><form name=\"insert_client_form\" method=\"POST\" action=\"$server_proto://$base_uri/res/ip_modclient.cgi\">\n";
print "<table border=\"0\">\n";
print "<tr><td $align>$$lang_vars{client_name_message}</td><td $align1><input name=\"client_name\" type=\"text\" size=\"15\" maxlength=\"30\"></td></tr>";
print "<tr><td $align>sites</td><td colspan=\"4\" $align1><input name=\"loc\" type=\"text\"  size=\"20\" maxlength=\"200\"> <i>$$lang_vars{list_of_sites_message}</i></td></tr>";

print "<tr><td $align><img src=\"$server_proto://$base_uri/imagenes/telefon.png\" title=\"$$lang_vars{phone_message}\"></td><td colspan=\"9\" $align1><input name=\"phone\" type=\"text\"  size=\"15\" maxlength=\"30\" value=\"\"></td></tr>";
print "<tr><td $align><img src=\"$server_proto://$base_uri/imagenes/fax.png\" title=\"$$lang_vars{fax_message}\"></td><td colspan=\"9\" $align1><input name=\"fax\" type=\"text\"  size=\"15\" maxlength=\"30\" value=\"\"></td></tr>";
print "<tr><td $align>$$lang_vars{address_message}</td><td colspan=\"9\" $align1><textarea name=\"address\" cols=\"40\" rows=\"4\" maxlength=\"500\"></textarea></td></tr>";
print "<tr><td $align>$$lang_vars{comentario_message}</td><td colspan=\"9\" $align1><input name=\"comment\" type=\"text\"  size=\"35\" maxlength=\"200\" value=\"\"></td></tr>";
print "<tr><td colspan=\"10\"></td></tr>\n";
print "<tr nowrap><td $align>$$lang_vars{contact_message}</td><td><input name=\"contact_name_1\" type=\"text\" size=\"18\" maxlength=\"200\" value=\"\"></td><td>&nbsp; <img src=\"$server_proto://$base_uri/imagenes/telefon.png\" title=\"$$lang_vars{phone_message}\"></td><td><input name=\"contact_phone_1\" type=\"text\"  size=\"12\" maxlength=\"25\" value=\"\"></td><td>&nbsp; <img src=\"$server_proto://$base_uri/imagenes/handy.png\" title=\"$$lang_vars{cell_message}\"></td><td><input name=\"contact_cell_1\" type=\"text\"  size=\"10\" maxlength=\"25\" value=\"\"> </td><td>&nbsp; <img src=\"$server_proto://$base_uri/imagenes/email.png\" title=\"$$lang_vars{mail_message}\"></td><td><input name=\"contact_email_1\" type=\"text\"  size=\"15\" maxlength=\"50\" value=\"\"> </td><td>&nbsp; $$lang_vars{comentario_message}</td><td><input name=\"contact_comment_1\" type=\"text\"  size=\"22\" maxlength=\"50\" value=\"\"></td></tr>";
print "<tr nowrap><td $align>$$lang_vars{contact_message}</td><td><input name=\"contact_name_2\" type=\"text\" size=\"18\" maxlength=\"200\" value=\"\"></td><td>&nbsp; <img src=\"$server_proto://$base_uri/imagenes/telefon.png\" title=\"$$lang_vars{phone_message}\"></td><td><input name=\"contact_phone_2\" type=\"text\"  size=\"12\" maxlength=\"25\" value=\"\"></td><td>&nbsp; <img src=\"$server_proto://$base_uri/imagenes/handy.png\" title=\"$$lang_vars{cell_message}\"></td><td><input name=\"contact_cell_2\" type=\"text\"  size=\"10\" maxlength=\"25\" value=\"\"> </td><td>&nbsp; <img src=\"$server_proto://$base_uri/imagenes/email.png\" title=\"$$lang_vars{mail_message}\"></td><td><input name=\"contact_email_2\" type=\"text\"  size=\"15\" maxlength=\"50\" value=\"\"> </td><td>&nbsp; $$lang_vars{comentario_message}</td><td><input name=\"contact_comment_2\" type=\"text\"  size=\"22\" maxlength=\"50\" value=\"\"></td></tr>";
print "<tr nowrap><td $align>$$lang_vars{contact_message}</td><td><input name=\"contact_name_3\" type=\"text\" size=\"18\" maxlength=\"200\" value=\"\"></td><td>&nbsp; <img src=\"$server_proto://$base_uri/imagenes/telefon.png\" title=\"$$lang_vars{phone_message}\"></td><td><input name=\"contact_phone_3\" type=\"text\"  size=\"12\" maxlength=\"25\" value=\"\"></td><td>&nbsp; <img src=\"$server_proto://$base_uri/imagenes/handy.png\" title=\"$$lang_vars{cell_message}\"></td><td><input name=\"contact_cell_3\" type=\"text\"  size=\"10\" maxlength=\"25\" value=\"\"> </td><td>&nbsp; <img src=\"$server_proto://$base_uri/imagenes/email.png\" title=\"$$lang_vars{mail_message}\"></td><td><input name=\"contact_email_3\" type=\"text\"  size=\"15\" maxlength=\"50\" value=\"\"> </td><td>&nbsp; $$lang_vars{comentario_message}</td><td><input name=\"contact_comment_3\" type=\"text\"  size=\"22\" maxlength=\"50\" value=\"\"></td></tr>";
print "<tr><td><br><input name=\"client_action\" type=\"hidden\" value=\"insert_client\"><input name=\"client_id\" type=\"hidden\" value=\"$last_client_id\"><input name=\"mode\" type=\"hidden\" value=\"$mode\"><input type=\"submit\" value=\"$$lang_vars{crear_message}\" name=\"B1\" class=\"input_link_w\"></td><td></td></tr>";
print "</table>\n";
print "</form>\n";
print "<p><br>\n";


print "<p><b style=\"float: $ori\">$$lang_vars{delete_client_message}</b><br>\n";
print "<form  method=\"POST\" action=\"$server_proto://$base_uri/res/ip_modclient.cgi\">\n";
print "<table border=\"0\">\n";
print "<tr><td $align1><select name=\"client_id\" size=\"1\">\n";
$j=0;
foreach (@clients) {
	if ( $clients[$j]->[0] == "$client_id") {
		print "<option value=\"$clients[$j]->[0]\" selected>$clients[$j]->[1]</option>";
		$j++;
		next;
	}
	print "<option value=\"$clients[$j]->[0]\">$clients[$j]->[1]</option>";
	$j++;
}
print "</select></td></tr>\n";
print "<tr><td $align1><p><input name=\"client_action\" type=\"hidden\" value=\"delete_client\"><input name=\"client_name\" type=\"hidden\" value=\"\"><input name=\"mode\" type=\"hidden\" value=\"$mode\"><input type=\"submit\" value=\"$$lang_vars{borrar_message}\" name=\"B1\" class=\"input_link_w\" $onclick></td></tr>\n";
print "</table>\n";
print "</form>\n";
print "<p>\n";


print "<script type=\"text/javascript\">\n";
print "document.insert_client_form.client_name.focus();\n";
print "</script>\n";



$gip->print_end("$client_id","$vars_file","go_to_top");
