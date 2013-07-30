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
use DBI;
use lib './modules';
use GestioIP;


my $daten=<STDIN>;
my $gip = GestioIP -> new();
my %daten=$gip->preparer($daten);

my $lang = $daten{'lang'} || "";
my ($lang_vars,$vars_file)=$gip->get_lang("","$lang");
my $server_proto=$gip->get_server_proto();
my $base_uri=$gip->get_base_uri();

my $client_id = $daten{'client_id'} || $gip->get_first_client_id();
if ( $client_id !~ /^\d{1,4}$/ ) {
        $gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{busqueda_red_message}","$vars_file");
	$client_id=$gip->get_first_client_id();
        $gip->print_error("$client_id","$$lang_vars{client_id_invalid_message}","");
}

my @global_config = $gip->get_global_config("$client_id");
my $ipv4_only_mode=$global_config[0]->[5] || "yes";
my $ip_version_ele="";
if ( $ipv4_only_mode eq "no" ) {
        $ip_version_ele = $daten{'ip_version_ele'} || "";
        if ( $ip_version_ele ) {
                $ip_version_ele = $gip->set_ip_version_ele("$ip_version_ele");
        } else {
                $ip_version_ele = $gip->get_ip_version_ele();
        }
} else {
        $ip_version_ele = "v4";
}


my $modred=$daten{modred} || "";
my $client_independent=$daten{client_independent} || "n";

my $cc_search_only="0";
foreach my $key (keys %daten) {
        if ( $key=~ /cc_id_/ ) {
                $cc_search_only="1";
                last;
        }
}

if ( ! $daten{'red_search'} && ! $daten{'red'} && ! $daten{'descr'} && ! $daten{'loc'} && ! $daten{'vigilada'} && ! $daten{'cat_red'} && ! $daten{'comentario'} && $cc_search_only != "1" ) {
	my $back_button="<p><br><p><FORM><INPUT TYPE=\"BUTTON\" VALUE=\"back\" ONCLICK=\"history.go(-1)\" class=\"error_back_link\"></FORM>";
        $gip->print_init("search ip","$$lang_vars{busqueda_red_message}","$$lang_vars{no_search_string_message} $back_button","$vars_file","$client_id");
        $gip->print_end("$client_id");
        exit 1;
}

$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{resultado_busqueda_message}","$vars_file");


#my @values_red=$gip->search_db_red("$client_id",\@search,\@ignore_search,"$search_index","$client_independent") if $search[0] || $ignore_search[0];
my ( @values_red ) = $gip->search_db_red("$client_id","$vars_file",\%daten);


if ( $values_red[0] ) {
	my $hidden_form_fields = "";
	$hidden_form_fields .= "<input type=\"hidden\" name=\"red\" value=\"$daten{'red'}\">" if $daten{'red'};
	$hidden_form_fields .= "<input type=\"hidden\" name=\"descr\" value=\"$daten{'descr'}\">" if $daten{'descr'};
	$hidden_form_fields .= "<input type=\"hidden\" name=\"comentario\" value=\"$daten{'comentario'}\">" if $daten{'comentario'};
	$hidden_form_fields .= "<input type=\"hidden\" name=\"loc\" value=\"$daten{'loc'}\">" if $daten{'loc'};
	$hidden_form_fields .= "<input type=\"hidden\" name=\"cat_red\" value=\"$daten{'cat_red'}\">" if $daten{'cat_red'};
	$hidden_form_fields .= "<input type=\"hidden\" name=\"vigilada\" value=\"$daten{'vigilada'}\">" if $daten{'vigilada'};
	$hidden_form_fields .= "<input type=\"hidden\" name=\"red_search\" value=\"$daten{'red_search'}\">" if $daten{'red_search'};
	$hidden_form_fields .= "<input type=\"hidden\" name=\"client_independent\" value=\"$daten{'client_independent'}\">" if $daten{'client_independent'};

	my @cc_values=$gip->get_custom_columns("$client_id");
	for ( my $k = 0; $k < scalar(@cc_values); $k++ ) {
		$hidden_form_fields .= "<input type=\"hidden\" name=\"cc_id_$cc_values[$k]->[1]\" value=\"$daten{\"cc_id_$cc_values[$k]->[1]\"}\">" if $daten{"cc_id_$cc_values[$k]->[1]"};
	}

	print "<form name=\"export_redlist_form\" method=\"POST\" action=\"$server_proto://$base_uri/res/ip_export.cgi\">\n";
	print "<input name=\"export_type\" type=\"hidden\" value=\"red_search\"><input type=\"hidden\" name=\"export_radio\" value=\"red_search\"><input type=\"hidden\" name=\"ipv4\" value=\"ipv4\"><input type=\"hidden\" name=\"ipv6\" value=\"ipv6\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\">${hidden_form_fields}<input type=\"submit\" value=\"$$lang_vars{export_search_result_message}\" name=\"B2\" class=\"input_link_w_right\"></form><br>\n";
	print "<p>\n";
}

my $values_red_num = @values_red || "0";
my $colorcomment;

if ( ! $values_red[0] ) {
	print "<p class=\"NotifyText\">$$lang_vars{no_resultado_message}</p><br>\n";
	$colorcomment="nocomment";
} elsif ( $values_red_num > 500 ) {
        print "<p class=\"NotifyText\">$$lang_vars{max_search_result_net_superado_message}</p><br>\n";
} else {
	print "<p>\n";
	if ( $modred eq "y" ) {
		$gip->PrintRedTab("$client_id",\@values_red,"$vars_file","extended","","","","","$client_independent","","$ip_version_ele");
	} else { 
		$gip->PrintRedTab("$client_id",\@values_red,"$vars_file","simple","","","","","$client_independent","","$ip_version_ele");
	}
	$colorcomment="nocomment";
}

$gip->print_end("$client_id","$vars_file");
