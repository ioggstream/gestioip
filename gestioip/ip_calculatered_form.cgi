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
my %daten=$gip->preparer($daten) if $daten;

my $base_uri = $gip->get_base_uri();
my ($lang_vars,$vars_file)=$gip->get_lang();
my $server_proto=$gip->get_server_proto();



print <<EOF;
Content-type: text/html\n
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
"http://www.w3.org/TR/html4/loose.dtd">
<HTML>
<head><title>Gesti&oacute;IP subnet calculator</title>
<meta http-equiv="content-type" content="text/html; charset=UTF-8">
<link rel="stylesheet" type="text/css" href="./stylesheet.css">
<link rel="shortcut icon" href="/favicon.ico">
</head>

<script language="JavaScript" type="text/javascript" charset="utf-8">
<!--
function change_BM_select(version){
   var values_v4=new Array("CLASS A","255.0.0.0 - 16.777.214 hosts","255.128.0.0 - 8.388.606 hosts","255.192.0.0 - 4.194.302 hosts","255.224.0.0 - 2.097.150 hosts","255.240.0.0 - 1.048.574 hosts","255.248.0.0 - 524.286 hosts","255.252.0.0 - 262.142 hosts","255.254.0.0 - 131.070 hosts","CLASS B","255.255.0.0 - 65.534 hosts","255.255.128.0 - 32766 hosts","255.255.192.0 - 16.382 hosts","255.255.224.0 - 8.190 hosts","255.255.240.0 - 4.094 hosts","255.255.248.0 - 2.046 hosts","255.255.252.0 - 1.022 hosts","255.255.254.0 - 510 hosts","CLASS C","255.255.255.0 - 254 hosts","255.255.255.128 - 126 hosts","255.255.255.192 - 62 hosts","255.255.255.224 - 30 hosts","255.255.255.240 - 14 hosts","255.255.255.248 - 6 hosts","255.255.255.252 - 2 hosts","255.255.255.254 - 0 hosts","255.255.255.255 - 0 hosts")
    if (version == 'v4') {
       num_values = 28
       document.calculate_form.BM.length = num_values
       j=8
       for(i=0;i<num_values;i++){
          if ( i == '0' )
          {
             document.calculate_form.BM.options[i].text=values_v4[i]
             document.calculate_form.BM.options[i].disabled=true
          }
          else if ( i == '9' )
                   { 
             document.calculate_form.BM.options[i].text=values_v4[i]
             document.calculate_form.BM.options[i].disabled=true
                   } 
          else if ( i == '18' )
                   {
             document.calculate_form.BM.options[i].text=values_v4[i]
             document.calculate_form.BM.options[i].disabled=true
                   } 
          else {
            document.calculate_form.BM.options[i].text=j + ' (' + values_v4[i] + ')'
            document.calculate_form.BM.options[i].value=j
            document.calculate_form.BM.options[i].disabled=false
	    j++
          }
          if ( i == '19' ) { 
             document.calculate_form.BM.options[i].selected = true
          }
       }
    }else{
       num_values = '129'
       document.calculate_form.BM.length = num_values
       j=1
       for(i=0;i<128;i++){
          document.calculate_form.BM.options[i].value=j
          document.calculate_form.BM.options[i].text=j
          document.calculate_form.BM.options[121].selected = true
          j++
       }
    }
}
-->
</script>

<script language="JavaScript" type="text/javascript" charset="utf-8">
<!--
function create_hidden_selected_index(){
  var selIndex = document.calculate_form.BM.selectedIndex;
  document.getElementById('selected_index').innerHTML = '<input type=\"hidden\" name=\"selected_index\" value=\"' + selIndex + '\">';
}
-->
</script>



<body>
<div id="TopBoxCalc">
<table border="0" width="100%"><tr height="50px" valign="middle"><td>
  <span class="TopTextGestio">Gesti&oacute;IP</span></td>
  <td><span class="TopText">$$lang_vars{subnet_calculator_message}</span></td><tr>
</td></table>
</div>
<p>
EOF

print "<div id=\"CalcBox\">\n";

print "<p><form name=\"calculate_form\" method=\"POST\" action=\"$server_proto://$base_uri/ip_calculatered.cgi\">\n";
print "<table border=\"0\" cellpadding=\"2\">";
print "<tr><td></td><td>IPv4<input type=\"radio\" name=\"ip_version\" value=\"v4\" onchange=\"change_BM_select('v4'); document.calculate_form.red.size='15';  document.calculate_form.red.maxlength='15';\" checked> IPv6<input type=\"radio\" name=\"ip_version\" value=\"v6\" onchange=\"change_BM_select('v6'); document.calculate_form.red.size='40'; document.calculate_form.red.maxLength='40'\"><span id=\"selected_index\"></span></td></tr>\n";
print "<tr><td class=\"table_text\">$$lang_vars{ip_address_message}</td>\n";
print "<td><input name=\"red\" type=\"text\" size=\"20\" maxlength=\"15\" value=\"\"></td></tr>";
print "<tr><td class=\"table_text\">$$lang_vars{BM_message}</td>\n";
print "<td><select name=\"BM\" size=\"1\">\n";
my $bm_i_message;
for (my $i = 8; $i < 31; $i++) {
	print "<option disabled>CLASS A</option>" if $i == "8"; 
	print "<option disabled>CLASS B</option>" if $i == "16"; 
	print "<option disabled>CLASS C</option>" if $i == "24"; 
        if ( $i =~ /^\d$/ ) {
                $bm_i_message = "bm_0" . $i . "_message";
        } else {
                $bm_i_message = "bm_" . $i . "_message";
        }
        if ( $i == 24 ) {
                print "<option selected>$i ($$lang_vars{$bm_i_message})</option>";
        } else {
                print "<option>$i ($$lang_vars{$bm_i_message})</option>";
        }
}
print "</select>&nbsp;&nbsp;&nbsp;<input type=\"submit\" value=\"$$lang_vars{calcular_message}\" name=\"B2\" class=\"input_link_w_net\" onclick=\"create_hidden_selected_index();\"></td></tr></table>\n";
print "</form>";

print "<script type=\"text/javascript\">\n";
print "document.calculate_form.red.focus();\n";
print "</script>\n";

print "<p><br><span class=\"close_window\" onClick=\"window.close()\" style=\"cursor:pointer;\"> close </span>";

print "</div>\n";
print "<p><br>\n";
print "</div>\n";
print "</body>\n";
print "</html>\n";
exit 0;
