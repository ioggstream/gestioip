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
$gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{edit_vlan_message}","$vars_file");


my $vlan_id=$daten{'vlan_id'} || "";
$gip->print_error("$client_id","$$lang_vars{formato_malo_message}") if ! $vlan_id;
my $vlan_name=$daten{'vlan_name'};
my $vlan_num=$daten{'vlan_num'};
my $vlan_provider_id=$daten{'vlan_provider_id'};
my $bg_color=$daten{'bg_color'} || "";
my $font_color=$daten{'font_color'} || "";
my $comment=$daten{'comment'} || "";


my @values_vlan=$gip->get_vlan("$client_id","$vlan_id");
my @values_clientes=$gip->get_vlan_providers("$client_id");

my $asso_vlan = $values_vlan[0]->[7] || "";
my ($bg_color_val,$font_color_val);

my $bg_color_old=$values_vlan[0]->[3];
if ( ! $values_vlan[0]->[3] ) { $bg_color_old = "white"; $bg_color_val="blan";}
if ( $bg_color_old eq "gold" ) { $bg_color_val="amar";
} elsif ( $bg_color_old eq "LightCyan" ) { $bg_color_val="azulcc";
} elsif ( $bg_color_old eq "LightBlue" ) { $bg_color_val="azulc";
} elsif ( $bg_color_old eq "dodgerblue" ) { $bg_color_val="azulo";
} elsif ( $bg_color_old eq "LimeGreen" ) { $bg_color_val="verc";
} elsif ( $bg_color_old eq "SeaGreen" ) { $bg_color_val="vero";
} elsif ( $bg_color_old eq "pink" ) { $bg_color_val="pink";
} elsif ( $bg_color_old eq "white" ) { $bg_color_val="blan";
} elsif ( $bg_color_old eq "black" ) { $bg_color_val="negr";
} elsif ( $bg_color_old eq "brown" ) { $bg_color_val="maro";
} elsif ( $bg_color_old eq "red" ) { $bg_color_val="rojo";
} elsif ( $bg_color_old eq "DarkOrange" ) { $bg_color_val="orano";
}

my $font_color_old=$values_vlan[0]->[4];
if ( ! $values_vlan[0]->[4] ) { $font_color_old = "black"; $font_color_val="negr"}
if ( $font_color_old eq "gold" ) { $font_color_val="amar";
} elsif ( $font_color_old eq "LightCyan" ) { $font_color_val="azulcc";
} elsif ( $font_color_old eq "LightBlue" ) { $font_color_val="azulc";
} elsif ( $font_color_old eq "dodgerblue" ) { $font_color_val="azulo";
#} elsif ( $font_color_old eq "LimeGreen" ) { $font_color_val="verc";
} elsif ( $font_color_old eq "SeaGreen" ) { $font_color_val="vero";
} elsif ( $font_color_old eq "pink" ) { $font_color_val="pink";
} elsif ( $font_color_old eq "white" ) { $font_color_val="blan";
} elsif ( $font_color_old eq "black" ) { $font_color_val="negr";
} elsif ( $font_color_old eq "negr" ) { $font_color_val="negr";
} elsif ( $font_color_old eq "brown" ) { $font_color_val="maro";
} elsif ( $font_color_old eq "red" ) { $font_color_val="rojo";
} elsif ( $font_color_old eq "DarkOrange" ) { $font_color_val="orano";
}


my $anz_vlan_providers=$gip->count_vlan_providers("$client_id");

#print "bg: $bg_color_old, font: $font_color_old: color_val: $bg_color_val - $font_color_val Oldval: $values_vlan[0]->[0] - $values_vlan[0]->[1]<br>\n";
print "<p>\n";
print "<form name=\"modvlan_form\" method=\"POST\" action=\"./ip_modvlan.cgi\">\n";
print "<table border=\"0\" cellpadding=\"1\">\n";
print "<center><font size=\"1\"><tr align=\"center\" valign=\"bottom\"><td><b>$$lang_vars{vlan_number_message}</b></td><td><b> $$lang_vars{vlan_name_message}</font></b></td><td><b>  $$lang_vars{description_message}</b></td><td><b>$$lang_vars{vlan_provider_message}</b></td><td><b> $$lang_vars{background_color_message}</b></td><td><b>$$lang_vars{font_color_message}</b></td></tr><tr valign=\"top\"></center>\n";

print "<td><input name=\"vlan_num\" type=\"text\" size=\"5\" maxlength=\"15\" value=\"$vlan_num\"></td>\n";
print "<td><input name=\"vlan_name\" type=\"text\" size=\"25\" maxlength=\"250\" value=\"$vlan_name\"></td>\n";
#print "<td><input name=\"comment\" type=\"text\" size=\"15\" maxlength=\"300\" value=\"$comment\"></td>\n";
print "<td><textarea name=\"comment\" cols=\"15\" rows=\"5\">$comment</textarea></td>\n";
if ( $anz_vlan_providers >= "1" ) {
	print "<td><select name=\"vlan_provider_id\" \"size=\"1\">";
	my $j=0;
	#print "<option></option>";
	foreach my $opt(@values_clientes) {
		if ( $vlan_provider_id eq $values_clientes[$j]->[1] ) {
			print "<option value=\"$values_clientes[$j]->[1]\" selected>$values_clientes[$j]->[0]</option>";
		} else {
			print "<option value=\"$values_clientes[$j]->[1]\">$values_clientes[$j]->[0]</option>";
		}
		$j++;
	}
	print "</select></td>\n";
} else {
	print "<td><font color=\"gray\"><i>$$lang_vars{no_vlan_providers_lf_message}</i></font></td>\n";
}

print "<td>\n";
print "<select name=\"bg_color\" size=\"3\">";
if ( $bg_color_old ) {
	print "<OPTION SELECTED class=\"$bg_color_old\">$bg_color_val</OPTION>\n";
}
print "<OPTION class=\"gold\">amar</OPTION>\n";
print "<OPTION class=\"DarkOrange\">orano</OPTION>\n";
print "<OPTION class=\"brown\">maro</OPTION>\n";
print "<OPTION class=\"red\">rojo</OPTION>\n";
print "<OPTION class=\"pink\">pink</OPTION>\n";
print "<OPTION class=\"LightCyan\">azulcc</OPTION>\n";
print "<OPTION class=\"LightBlue\">azulc</OPTION>\n";
print "<OPTION class=\"dodgerblue\">azulo</OPTION>\n";
print "<OPTION class=\"LimeGreen\">verc</OPTION>\n";
print "<OPTION class=\"SeaGreen\">vero</OPTION>\n";
#print "<OPTION class=\"DarkSeaGreen\">vero</OPTION>\n";
print "<OPTION class=\"white\">blan</OPTION>\n";
print "<OPTION class=\"black\">negr</OPTION>\n";
print "</SELECT>\n";
print "</td><td>\n";

print "<select name=\"font_color\" size=\"3\">";
if ( $font_color_old ) {
        print "<OPTION SELECTED class=\"$font_color_old\">$font_color_val</OPTION>\n";
}
print "<OPTION class=\"gold\">amar</OPTION>\n";
print "<OPTION class=\"DarkOrange\">orano</OPTION>\n";
print "<OPTION class=\"brown\">maro</OPTION>\n";
print "<OPTION class=\"red\">rojo</OPTION>\n";
print "<OPTION class=\"LightCyan\">azulcc</OPTION>\n";
print "<OPTION class=\"LightBlue\">azulc</OPTION>\n";
print "<OPTION class=\"dodgerblue\">azulo</OPTION>\n";
#print "<OPTION class=\"LimeGreen\">verc</OPTION>\n";
print "<OPTION class=\"SeaGreen\">vero</OPTION>\n";
#print "<OPTION class=\"DarkSeaGreen\">vero</OPTION>\n";
print "<OPTION class=\"white\">blan</OPTION>\n";
print "<OPTION class=\"black\">negr</OPTION>\n";
print "</SELECT>\n";
print "</td>\n";

if ( $asso_vlan ) {
	print "<td><input name=\"asso_vlan\" type=\"text\" size=\"4\" maxlength=\"4\" value=\"$asso_vlan\"></td>\n";
}

print "</td>\n";
print "<td><input type=\"hidden\" name=\"vlan_id\" value=\"$vlan_id\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><br><input type=\"submit\" value=\"$$lang_vars{submit_message}\" name=\"B2\" class=\"input_link_w\"></form></td>\n";
print "<script type=\"text/javascript\">\n";
	print "document.modvlan_form.vlan_num.focus();\n";
print "</script>\n";

print "</table>\n";

print "<p><br><p><br><p>\n";

$gip->print_end("$client_id");

