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
use Net::IP;
use Net::IP qw(:PROC);
use POSIX qw(ceil);
use Math::BigInt;

my $daten=<STDIN>;
my $gip = GestioIP -> new();
my %daten=$gip->preparer("$daten") if $daten;

my $base_uri = $gip->get_base_uri();
my ($lang_vars,$vars_file)=$gip->get_lang();
my $server_proto=$gip->get_server_proto();

my $client_id=1;

my $ip_version = $daten{'ip_version'} || 'v4';
my $selected_index="no_index";
if ( defined($daten{'selected_index'})) {
	$selected_index=$daten{'selected_index'};
#	$selected_index=0 if $daten{'selected_index'} == 0;
} else {
	if ( $ip_version eq "v4") {
		$selected_index=19;
	} else {
		$selected_index="56";
	}
}

my $more_possible_subnets=$daten{'more_possible_subnets'} || "";
my $BM_l2=$daten{'BM_l2'} || "";
my $BM_l3=$daten{'BM_l3'} || "";
my $BM_l4=$daten{'BM_l4'} || "";
my $BM_l5=$daten{'BM_l5'} || "";
my $BM_l6=$daten{'BM_l6'} || "";
my $BM_l7=$daten{'BM_l7'} || "";
my $BM_l8=$daten{'BM_l8'} || "";
my $bin_show_more=$daten{'bin_show_more'} || "";

my $red="";
my $BM="";

if ( $ENV{'QUERY_STRING'} ) {
	my $QUERY_STRING = $ENV{'QUERY_STRING'};
	$QUERY_STRING =~ /ip=(.*)&BM=(.*)&ip_version=(.*)$/;
	$red=$1; 
	$BM=$2;
	$ip_version=$3 if $3;
	if ( $ip_version eq "v6" ) {
		$selected_index = $BM - 8 if $ip_version eq "v6";
	} else {
		if ( $BM >= 24 ) {
			$selected_index = $BM - 5 if $ip_version eq "v4";
		} elsif ( $BM >= 16 ) {
			$selected_index = $BM - 6 if $ip_version eq "v4";
		} elsif ( $BM >= 8 ) {
			$selected_index = $BM - 7 if $ip_version eq "v4";
		}
	}
	

	
}


print <<EOF;
Content-type: text/html\n
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
"http://www.w3.org/TR/html4/loose.dtd">
<HTML>
<head><title>Gesti&oacute;IP subnet calculator</title>
<meta http-equiv="content-type" content="text/html; charset=UTF-8">
<meta http-equiv="Author" content="Marc Uebel">
<meta http-equiv="Pragma" content="no-cache">
<link rel="stylesheet" type="text/css" href="./stylesheet.css">
<link rel="shortcut icon" href="/favicon.ico">
</head>

<body onLoad="JavaScript:checkRefresh('$ip_version','$selected_index');">
<div id="TopBoxCalc">
<table border="0" width="100%"><tr height="50px" valign="middle"><td>
  <span class="TopTextGestio">Gesti&oacute;IP</span></td>
  <td><span class="TopText">$$lang_vars{subnet_calculator_message}</span></td><tr>
</td></table>
</div>
<p>

EOF

if ( $ip_version !~ /^(v4|v6)$/ || $selected_index !~ /^\d+$/ ) {
        $gip->print_error("$client_id","$$lang_vars{formato_malo_message} (1a)");
}

if ( $ip_version eq "v4" ) {
	if ( $daten{red} && $daten{red} =~ /^\d{8,10}$/ ) {
		$daten{red} =~ s/^\s*//;
		$daten{red} =~ s/\s*$//;
		$red = $gip->int_to_ip("$client_id","$daten{red}","$ip_version");
		$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (1)") if ! $red;
		$BM = $daten{BM};
	} else {
		
		if ( $daten{red} ) {
			$daten{red} =~ s/^\s*//;
			$daten{red} =~ s/\s*$//;
			$gip->CheckInIP("$client_id","$daten{'red'}","$$lang_vars{formato_ip_malo_message} <p><br><p><FORM style=\"display:inline;\"><INPUT TYPE=\"BUTTON\" VALUE=\"back\" ONCLICK=\"history.go(-1)\" class=\"error_back_link\"></FORM><p><br><p><br><p><br><span class=\"close_window\" onClick=\"window.close()\" style=\"cursor:pointer;\"> $$lang_vars{close_message} </span>");
			$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (2) $daten{BM}") if $daten{BM} !~ /^\d{1,2}.+\(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\s-\s[0-9\.]+\shosts\)/ && $daten{BM} !~ /^\d{1,2}$/;
			$red=$daten{red};
			$BM = $daten{BM};
#		} elsif ( $ENV{'QUERY_STRING'} ) {
#			my $QUERY_STRING = $ENV{'QUERY_STRING'};
#			$QUERY_STRING =~ /ip=(.*)&BM=(.*)$/;
#			$red=$1; 
#			$BM=$2;
		}
	}
	$BM=24 if ! $BM;
} else {
	if ( $daten{red} ) {
		$daten{red} =~ s/^\s*//;
		$daten{red} =~ s/\s*$//;
		if ( $daten{red} && $daten{red} =~ /^\d{8,50}$/ ) {
			$red = $gip->int_to_ip("$client_id","$daten{red}","$ip_version");
			$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (4)") if ! $red;
		} else {
			$red = $daten{red};
			my $valid_v6 = $gip->check_valid_ipv6("$red") || "0";
			my $red_exp= ip_expand_address ($red,6);
			$gip->print_error("$client_id","$$lang_vars{no_valid_ipv6_address_message} <b>$red</b>") if $valid_v6 != "1";
			$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (3)") if $daten{BM} !~ /^\d{1,3}/;
#			$gip->print_error("$client_id","$$lang_vars{formato_ip_malo_message} (5)") if $red_exp eq "0000:0000:0000:0000:0000:0000:0000:0000";
		}
		$BM = $daten{BM};
	}
}

my $red_orig=$red;
my %bm=$gip->get_anz_hosts_bm_hash("1","$ip_version");

print <<EOF;

<script type="text/javascript">
<!--
function resettxt() {
document.forms.calculate_form.red.value = "";
}
-->
</script>

<script type="text/javascript">
<!--
function checkRefresh(version,selected_index) {
 if (version == 'v4') {
  num_values = 28
  document.calculate_form.BM.length = num_values
  var bm_index=document.calculate_form.BM.options[1].value
  document.forms.calculate_form.ip_version[0].checked=true
  document.forms.calculate_form.red.size='15';
  document.forms.calculate_form.BM.options[selected_index].selected=true
 } else {
  document.forms.calculate_form.ip_version[1].checked=true
  num_values = '121'
  document.calculate_form.BM.length = num_values
  document.forms.calculate_form.red.size='38';
  var network_message="$$lang_vars{entradas_redes_message}"
  var values_v6=new Array("8 (72,057,594,037,927,936 " + network_message + ")","9 (36,028,797,018,963,968 " + network_message + ")","10 (18,014,398,509,481,984 " + network_message + ")","11 (9,007,199,254,740,992 " + network_message + ")","12 (4,503,599,627,370,496 " + network_message + ")","13 (2,251,799,813,685,248 " + network_message + ")","14 (1,125,899,906,842,624 " + network_message + ")","15 (562,949,953,421,312 " + network_message + ")","16 (281,474,976,710,656 " + network_message + ")","17 (140,737,488,355,328 " + network_message + ")","18 (70,368,744,177,664 " + network_message + ")","19 (35,184,372,088,832 " + network_message + ")","20 (17,592,186,044,416 " + network_message + ")","21 (8,796,093,022,208 " + network_message + ")","22 (4,398,046,511,104 " + network_message + ")","23 (2,199,023,255,552 " + network_message + ")","24 (1,099,511,627,776 " + network_message + ")","25 (549,755,813,888 " + network_message + ")","26 (274,877,906,944 " + network_message + ")","27 (137,438,953,472 " + network_message + ")","28 (68,719,476,736 " + network_message + ")","29 (34,359,738,36 " + network_message + ")","30 (17,179,869,184 " + network_message + ")","31 (8,589,934,592 " + network_message + ")","32 (4,294,967,296 " + network_message + ")","33 (2,147,483,648 " + network_message + ")","34 (1,073,741,824 " + network_message + ")","35 (536,870,912 " + network_message + ")","36 (268,435,456 " + network_message + ")","37 (134,217,728 " + network_message + ")","38 (67,108,864 " + network_message + ")","39 (33,554,432 " + network_message + ")","40 (16,777,216 " + network_message + ")","41 (8,388,608 " + network_message + ")","42 (4,194,304 " + network_message + ")","43 (2,097,152 " + network_message + ")","44 (1,048,576 " + network_message + ")","45 (524,288 " + network_message + ")","46 (262,144 " + network_message + ")","47 (131,072 " + network_message + ")","48 (65,536 " + network_message + ")","49 (32,768 " + network_message + ")","50 (16,384 " + network_message + ")","51 (8,192 " + network_message + ")","52 (4,096 " + network_message + ")","53 (2,048 " + network_message + ")","54 (1,024 " + network_message + ")","55 (512 " + network_message + ")","56 (256 " + network_message + ")","57 (128 " + network_message + ")","58 (64 " + network_message + ")","59 (32 " + network_message + ")","60 (16 " + network_message + ")","61 (8 " + network_message + ")","62 (4 " + network_message + ")","63 (2 " + network_message + ")","64 (18,446,744,073,709,551,616 addresses)","65 (9,223,372,036,854,775,808 addresses)","66 (4,611,686,018,427,387,904 addresses)","67 (2,305,843,009,213,693,952 addresses)","68 (1,152,921,504,606,846,976 addresses)","69 (576,460,752,303,423,488 addresses)","70 (288,230,376,151,711,744 addresses)","71 (144,115,188,075,855,872 addresses)","72 (72,057,594,037,927,936 addresses)","73 (36,028,797,018,963,968 addresses)","74 (18,014,398,509,481,984 addresses)","75 (9,007,199,254,740,992 addresses)","76 (4,503,599,627,370,496 addresses)","77 (2,251,799,813,685,248 addresses)","78 (1,125,899,906,842,624 addresses)","79 (562,949,953,421,312 addresses)","80 (281,474,976,710,656 addresses)","81 (140,737,488,355,328 addresses)","82 (70,368,744,177,664 addresses)","83 (35,184,372,088,832 addresses)","84 (17,592,186,044,416 addresses)","85 (8,796,093,022,208 addresses)","86 (4,398,046,511,104 addresses)","87 (2,199,023,255,552 addresses)","88 (1,099,511,627,776 addresses)","89 (549,755,813,888 addresses)","90 (274,877,906,944 addresses)","91 (137,438,953,472 addresses)","92 (68,719,476,736 addresses)","93 (34,359,738,36 addresses)","94 (17,179,869,184 addresses)","95 (8,589,934,592 addresses)","96 (4,294,967,296 addresses)","97 (2,147,483,648 addresses)","98 (1,073,741,824 addresses)","99 (536,870,912 addresses)","100 (268,435,456 addresses)","101 (134,217,728 addresses)","102 (67,108,864 addresses)","103 (33,554,432 addresses)","104 (16,777,216 addresses)","105 (8,388,608 addresses)","106 (4,194,304 addresses)","107 (2,097,152 addresses)","108 (1,048,576 addresses)","109 (524,288 addresses)","110 (262,144 addresses)","111 (131,072 addresses)","112 (65,536 addresses)","113 (32,768 addresses)","114 (16,384 addresses)","115 (8,192 addresses)","116 (4,096 addresses)","117 (2,048 addresses)","118 (1,024 addresses)","119 (512 addresses)","120 (256 addresses)","121 (128 addresses)","122 (64 addresses)","123 (32 addresses)","124 (16 addresses)","125 (8 addresses)","126 (4 addresses)","127 (2 addresses)","128 (1 address)")
       j=8
       for(i=0;i<121;i++){
//          document.calculate_form.BM.options[i].value=j
          document.calculate_form.BM.options[i].value=values_v6[i]
          document.calculate_form.BM.options[i].text=values_v6[i]
          document.calculate_form.BM.options[selected_index].selected = true
          document.calculate_form.BM.options[i].disabled=false
          j++
       }
//  document.forms.calculate_form.BM.options[selected_index].selected=true
 }
}
-->
</script>

<script language="JavaScript" type="text/javascript" charset="utf-8">
<!--
function calculate_red()
{
var IP=document.calculate_form.red.value;
var BM=document.calculate_form.BM.value;
var opciones="toolbar=no,scrollbars=1,right=100,top=100,width=475,height=550,resizable", i=0;
var URL="$server_proto://$base_uri/ip_calculatered.cgi?ip=" + IP + "&BM=" + BM; 
host_info=window.open(URL,"",opciones);
}
-->
</script>

<script language="JavaScript" type="text/javascript" charset="utf-8">
<!--
function change_BM_select(version,network_message,selected_index){
   var values_v4=new Array("CLASS A","255.0.0.0 - 16.777.214 hosts","255.128.0.0 - 8.388.606 hosts","255.192.0.0 - 4.194.302 hosts","255.224.0.0 - 2.097.150 hosts","255.240.0.0 - 1.048.574 hosts","255.248.0.0 - 524.286 hosts","255.252.0.0 - 262.142 hosts","255.254.0.0 - 131.070 hosts","CLASS B","255.255.0.0 - 65.534 hosts","255.255.128.0 - 32766 hosts","255.255.192.0 - 16.382 hosts","255.255.224.0 - 8.190 hosts","255.255.240.0 - 4.094 hosts","255.255.248.0 - 2.046 hosts","255.255.252.0 - 1.022 hosts","255.255.254.0 - 510 hosts","CLASS C","255.255.255.0 - 254 hosts","255.255.255.128 - 126 hosts","255.255.255.192 - 62 hosts","255.255.255.224 - 30 hosts","255.255.255.240 - 14 hosts","255.255.255.248 - 6 hosts","255.255.255.252 - 2 hosts","255.255.255.254 - 0 hosts","255.255.255.255 - 0 hosts")
    if (version == 'v4') {
//       document.calculate_form.red.size='15'
       document.calculate_form.red.maxLength='40'
       document.calculate_form.ip_version[0].checked=true
       num_values = 28
       document.calculate_form.BM.length = num_values
       j=8
       for(i=0;i<28;i++){
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
          if ( i == selected_index ) { 
             document.calculate_form.BM.options[i].selected = true
          }
       }
    }else{
//       document.calculate_form.red.size='38'
       document.calculate_form.red.maxLength='40'
       document.calculate_form.ip_version[1].checked=true
       var values_v6=new Array("8 (72,057,594,037,927,936 " + network_message + ")","9 (36,028,797,018,963,968 " + network_message + ")","10 (18,014,398,509,481,984 " + network_message + ")","11 (9,007,199,254,740,992 " + network_message + ")","12 (4,503,599,627,370,496 " + network_message + ")","13 (2,251,799,813,685,248 " + network_message + ")","14 (1,125,899,906,842,624 " + network_message + ")","15 (562,949,953,421,312 " + network_message + ")","16 (281,474,976,710,656 " + network_message + ")","17 (140,737,488,355,328 " + network_message + ")","18 (70,368,744,177,664 " + network_message + ")","19 (35,184,372,088,832 " + network_message + ")","20 (17,592,186,044,416 " + network_message + ")","21 (8,796,093,022,208 " + network_message + ")","22 (4,398,046,511,104 " + network_message + ")","23 (2,199,023,255,552 " + network_message + ")","24 (1,099,511,627,776 " + network_message + ")","25 (549,755,813,888 " + network_message + ")","26 (274,877,906,944 " + network_message + ")","27 (137,438,953,472 " + network_message + ")","28 (68,719,476,736 " + network_message + ")","29 (34,359,738,36 " + network_message + ")","30 (17,179,869,184 " + network_message + ")","31 (8,589,934,592 " + network_message + ")","32 (4,294,967,296 " + network_message + ")","33 (2,147,483,648 " + network_message + ")","34 (1,073,741,824 " + network_message + ")","35 (536,870,912 " + network_message + ")","36 (268,435,456 " + network_message + ")","37 (134,217,728 " + network_message + ")","38 (67,108,864 " + network_message + ")","39 (33,554,432 " + network_message + ")","40 (16,777,216 " + network_message + ")","41 (8,388,608 " + network_message + ")","42 (4,194,304 " + network_message + ")","43 (2,097,152 " + network_message + ")","44 (1,048,576 " + network_message + ")","45 (524,288 " + network_message + ")","46 (262,144 " + network_message + ")","47 (131,072 " + network_message + ")","48 (65,536 " + network_message + ")","49 (32,768 " + network_message + ")","50 (16,384 " + network_message + ")","51 (8,192 " + network_message + ")","52 (4,096 " + network_message + ")","53 (2,048 " + network_message + ")","54 (1,024 " + network_message + ")","55 (512 " + network_message + ")","56 (256 " + network_message + ")","57 (128 " + network_message + ")","58 (64 " + network_message + ")","59 (32 " + network_message + ")","60 (16 " + network_message + ")","61 (8 " + network_message + ")","62 (4 " + network_message + ")","63 (2 " + network_message + ")","64 (18,446,744,073,709,551,616 addresses)","65 (9,223,372,036,854,775,808 addresses)","66 (4,611,686,018,427,387,904 addresses)","67 (2,305,843,009,213,693,952 addresses)","68 (1,152,921,504,606,846,976 addresses)","69 (576,460,752,303,423,488 addresses)","70 (288,230,376,151,711,744 addresses)","71 (144,115,188,075,855,872 addresses)","72 (72,057,594,037,927,936 addresses)","73 (36,028,797,018,963,968 addresses)","74 (18,014,398,509,481,984 addresses)","75 (9,007,199,254,740,992 addresses)","76 (4,503,599,627,370,496 addresses)","77 (2,251,799,813,685,248 addresses)","78 (1,125,899,906,842,624 addresses)","79 (562,949,953,421,312 addresses)","80 (281,474,976,710,656 addresses)","81 (140,737,488,355,328 addresses)","82 (70,368,744,177,664 addresses)","83 (35,184,372,088,832 addresses)","84 (17,592,186,044,416 addresses)","85 (8,796,093,022,208 addresses)","86 (4,398,046,511,104 addresses)","87 (2,199,023,255,552 addresses)","88 (1,099,511,627,776 addresses)","89 (549,755,813,888 addresses)","90 (274,877,906,944 addresses)","91 (137,438,953,472 addresses)","92 (68,719,476,736 addresses)","93 (34,359,738,36 addresses)","94 (17,179,869,184 addresses)","95 (8,589,934,592 addresses)","96 (4,294,967,296 addresses)","97 (2,147,483,648 addresses)","98 (1,073,741,824 addresses)","99 (536,870,912 addresses)","100 (268,435,456 addresses)","101 (134,217,728 addresses)","102 (67,108,864 addresses)","103 (33,554,432 addresses)","104 (16,777,216 addresses)","105 (8,388,608 addresses)","106 (4,194,304 addresses)","107 (2,097,152 addresses)","108 (1,048,576 addresses)","109 (524,288 addresses)","110 (262,144 addresses)","111 (131,072 addresses)","112 (65,536 addresses)","113 (32,768 addresses)","114 (16,384 addresses)","115 (8,192 addresses)","116 (4,096 addresses)","117 (2,048 addresses)","118 (1,024 addresses)","119 (512 addresses)","120 (256 addresses)","121 (128 addresses)","122 (64 addresses)","123 (32 addresses)","124 (16 addresses)","125 (8 addresses)","126 (4 addresses)","127 (2 addresses)","128 (1 address)")
       num_values = '121'
       document.calculate_form.BM.length = num_values
       j=8
       for(i=0;i<121;i++){
//          document.calculate_form.BM.options[i].value=j
          document.calculate_form.BM.options[i].value=values_v6[i]
          document.calculate_form.BM.options[i].text=values_v6[i]
          document.calculate_form.BM.options[selected_index].selected = true
          document.calculate_form.BM.options[i].disabled=false
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
  document.getElementById('selected_indexA').innerHTML = '<input type=\"hidden\" name=\"selected_index\" value=\"' + selIndex + '\">';
  document.getElementById('selected_indexB').innerHTML = '<input type=\"hidden\" name=\"selected_index\" value=\"' + selIndex + '\">';
  for(i=0;i<64;i++){
     var element=document.getElementById('selected_index' + i);
     if ( element ){
        document.getElementById('selected_index' + i).innerHTML = '<input type=\"hidden\" name=\"selected_index\" value=\"' + selIndex + '\">';
     }
     element='';
  }
}
-->
</script>

<SCRIPT LANGUAGE="Javascript" TYPE="text/javascript">
<!--
function createCookie(name,value,days)
{
  if (days)
  {
      var date = new Date();
      date.setTime(date.getTime()+(days*24*60*60*1000));
      var expires = "; expires="+date.toGMTString();
  }
  else var expires = "";
  document.cookie = name+"="+value+expires+"; path=/";
}

function readCookie(name)
{
  var nameEQ = name + "=";
  var ca = document.cookie.split(';');
  for(var i=0;i < ca.length;i++)
  {
      var c = ca[i];
      while (c.charAt(0)==' ') c = c.substring(1,c.length);
      if (c.indexOf(nameEQ) == 0) return c.substring(nameEQ.length,c.length);
  }
  return null;
}

function eraseCookie(name)
{
  createCookie(name,"",-1);
}
// -->
</SCRIPT>


<SCRIPT LANGUAGE="Javascript" TYPE="text/javascript">
<!--

function scrollToCoordinates() {
  var x = readCookie('scrollx');
  var y = readCookie('scrolly');
  window.scrollTo(x, y);
  eraseCookie('scrollx')
  eraseCookie('scrolly')
}

function saveScrollCoordinates() {
  var x = (document.all)?document.body.scrollLeft:window.pageXOffset;
  var y = (document.all)?document.body.scrollTop:window.pageYOffset;
  createCookie('scrollx', x, 0);
  createCookie('scrolly', y, 0);
  return;
}

//function scrollToTop() {
//  var x = '0';
//  var y = '0';
//  window.scrollTo(x, y);
//  eraseCookie('net_scrollx')
//  eraseCookie('net_scrolly')
//}

//-->
</SCRIPT>


<div id="CalcBox">

EOF

print "<p><form name=\"calculate_form\" id=\"calculate_form\" method=\"POST\" action=\"$server_proto://$base_uri/ip_calculatered.cgi\">\n";
print "<table border=\"0\" cellpadding=\"2\">";
print "<tr><td></td><td>IPv4<input type=\"radio\" name=\"ip_version\" value=\"v4\" onchange=\"change_BM_select('v4',\'$$lang_vars{entradas_redes_message}\','19');\" checked> IPv6<input type=\"radio\" name=\"ip_version\" value=\"v6\" onchange=\"change_BM_select('v6',\'$$lang_vars{entradas_redes_message}\','56');\"><span id=\"selected_indexA\"></span></td></tr>\n";

print "<tr><td class=\"table_text\" nowrap>$$lang_vars{ip_address_message}</td>\n";
print "<td colspan=\"2\"><input name=\"red\" id=\"red\" type=\"text\" size=\"48\" maxlength=\"48\" value=\"$red\"><input type=\"button\" value=\"\" class=\"reset_text_field_button\" onClick=\"resettxt()\"></td></tr>";
if ( $ip_version eq "v4" ) {
	print "<tr><td class=\"table_text\">$$lang_vars{BM_message}</td>\n";
} else {
	print "<tr><td class=\"table_text\">Prefix lenght</td>\n";
}
print "<td><select name=\"BM\" size=\"1\" style=\"width:17em\">\n";


my $bm_i_message;
$BM =~ /^(\d{1,3})/;
my $BM_select=$1 || "";
$BM=$BM_select if $ip_version eq "v6";
if ( $ip_version eq "v4" ) {
	for (my $i = 8; $i < 33; $i++) {
		print "<option disabled>CLASS A</option>" if $i == "8";
		print "<option disabled>CLASS B</option>" if $i == "16";
		print "<option disabled>CLASS C</option>" if $i == "24";
		if ( $i =~ /^\d$/ ) {
			$bm_i_message = "bm_0" . $i . "_message";
		} else {
			$bm_i_message = "bm_" . $i . "_message";
		}
		if ( $i == $BM_select ) {
			print "<option selected>$i ($$lang_vars{$bm_i_message})</option>";
		} else {
			print "<option >$i ($$lang_vars{$bm_i_message})</option>";
		}
	}
} else {
	for (my $i = 1; $i <= 128; $i++) {
		next if $i < 8;
		my $host_red_noti = "hosts";
		$host_red_noti = "$$lang_vars{'entradas_redes_message'}" if $i < 64;
		my $anz_host_loop_message="";
		$anz_host_loop_message="($bm{$i} $host_red_noti)";
		if ( $i eq "$BM") {
			print "<option value=\"$i\" selected><b>$i</b> $anz_host_loop_message</option>";
		} else {
			print "<option value=\"$i\">$i $anz_host_loop_message</option>";
		}
	}

}
print "</select></td><td>&nbsp;&nbsp;<input type=\"submit\" value=\"$$lang_vars{calcular_message}\" name=\"B2\" class=\"input_link_w_net\" onclick=\"create_hidden_selected_index();\"></td></tr></table>\n";
print "</form>\n";

if ( ! $red ) {
print "</div>\n";
print "</div>\n";
print "</body>\n";
print "</html>\n";
exit 0;
}

my $redob = "$red/$BM";

my ($ipob_red,$address_32);
$ipob_red = new Net::IP ($redob);

if ( ! $ipob_red && $ip_version eq "v4" ) {
	my $BM_32 = "32";
	$redob = "$red/$BM_32";
	$ipob_red = new Net::IP ($redob) || die "Can not create ip object $redob: $!\n";
	$address_32="1";	
} elsif ( ! $ipob_red ) {
	my $BM_128 = "128";
	$redob = "$red/$BM_128";
	$ipob_red = new Net::IP ($redob) || die "Can not create ip object $redob: $!\n";
	$address_32="1";	
}

my $ip_int=($ipob_red->intip());
my $prefix_address=($ipob_red->mask()) if $ip_version eq "v6";

my $red_orig_show="";
my $red_exp= ip_expand_address ($red,6) if $ip_version eq "v6";
my $red_exp_orig=$red_exp;

my ( $netmask_in, $binmask_in, $class);
if ( $ip_version eq "v4" ) {
	if ( $BM =~ /^(\d\d).*/ && ! $ENV{'QUERY_STRING'} ) {
		$BM =~ /^(\d\d).+\((\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}).+/;
		$BM = $1;
		$netmask_in = $2;
		if ( ! $netmask_in ) {
			my %bm_to_mask=$gip->get_bm_to_netmask();
			$netmask_in=$bm_to_mask{$BM};
		}
	} else {
		if ( $BM =~ /^(\d\d).*/ ) {
			$BM =~ /^(\d\d).+\((\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}).+/;
			$BM = $1;
			$netmask_in = $2;
		} elsif ( $BM =~ /^(\d).+/ ) {
			$BM =~ /^(\d).+\((\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}).+/;
			$BM = $1;
			$netmask_in = $2;
		}
		if ( ! $netmask_in ) {
			my %bm_to_mask=$gip->get_bm_to_netmask();
			$netmask_in=$bm_to_mask{$BM};
		}
	}

	$netmask_in =~ /(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})/;
	my $first_mask_oc = $1;
	my $sec_mask_oc = $2;
	my $thi_mask_oc = $3;
	my $fou_mask_oc = $4;
	my $first_mask_oc_bin=dec2bin("$first_mask_oc");
	my $sec_mask_oc_bin=dec2bin("$sec_mask_oc");
	my $thi_mask_oc_bin=dec2bin("$thi_mask_oc");
	my $fou_mask_oc_bin=dec2bin("$fou_mask_oc");

	$binmask_in = "$first_mask_oc_bin" . "$sec_mask_oc_bin" . "$thi_mask_oc_bin" . "$fou_mask_oc_bin";
	my $len_first = length($first_mask_oc_bin);
	my $len_sec = length($sec_mask_oc_bin);
	my $len_thi = length($thi_mask_oc_bin);
	my $len_fou = length($fou_mask_oc_bin);
	my $len_falta;
	if ( $len_first < 8 ) { 
		$len_falta=8-$len_first; 
		$first_mask_oc_bin = "$first_mask_oc_bin" . 0 x $len_falta;
	}
	if ( $len_sec < 8 ) { 
		$len_falta=8-$len_sec; 
		$sec_mask_oc_bin = "$sec_mask_oc_bin" . 0 x $len_falta;
	}
	if ( $len_thi < 8 ) { 
		$len_falta=8-$len_thi; 
		$thi_mask_oc_bin = "$thi_mask_oc_bin" . 0 x $len_falta;
	}
	if ( $len_fou < 8 ) { 
		$len_falta=8 - $len_fou; 
		$fou_mask_oc_bin = "$fou_mask_oc_bin" . 0 x $len_falta;
	}
	$binmask_in = "$first_mask_oc_bin" . "$sec_mask_oc_bin" . "$thi_mask_oc_bin" . "$fou_mask_oc_bin";

	if ( $ip_int <= 2147483647 ) {
		$class = "A";
	} elsif ( $ip_int >= 2147483648 && $ip_int <= 3221225471 ) {
		$class = "B";
	} elsif ( $ip_int >= 3221225472 && $ip_int <= 3758096383 ) {
		$class = "C";
	} elsif ( $ip_int >= 3758096384 && $ip_int <= 4160749567 ) {
		$class = "D";
	} else {
		$class = "E";
	}
}

$netmask_in=($ipob_red->mask()) if ! $netmask_in;
my $type=($ipob_red->iptype());
#$type="Site-Local Unicast Addresses" if $red =~ /^fec0:/;
$type="Unique Local Address" if $red =~ /^fc00:/;
$type="GLOBAL-UNICAST (reserved for documentation purpose [RFC3849])" if $red =~ /^2001:0?db8:/;
my $hexip=($ipob_red->hexip());
my $hex = unpack('H*', "$red"); 
my $bin=($ipob_red->binip());
my $bin_show=$bin;

if ($ip_version eq "v6" && ! $bin_show_more ) {
	$bin_show =~ /(\d{32})(\d{32})(\d{32})(\d+)/;
#	$bin_show="<form name=\"calculate_form_bin\" id=\"calculate_form_bin\" method=\"POST\" action=\"$server_proto://$base_uri/ip_calculatered.cgi\" style=\"display:inline\"> <input type=\"hidden\" name=\"ip_version\" value=\"$ip_version\"><input type=\"hidden\" name=\"red\" value=\"$red_orig\"><input type=\"hidden\" name=\"BM\" value=\"$daten{BM}\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"hidden\" name=\"bin_show_more\" value=\"yes\"><span id=\"selected_indexB\"></span><input type=\"submit\" value=\"$1...\" name=\"B2\" class=\"input_link_w_calc\" onclick=\"create_hidden_selected_index();\"></form>";
	$bin_show="<form name=\"calculate_form_bin\" id=\"calculate_form_bin\" method=\"POST\" action=\"$server_proto://$base_uri/ip_calculatered.cgi\" style=\"display:inline\"> <input type=\"hidden\" name=\"ip_version\" value=\"$ip_version\"><input type=\"hidden\" name=\"red\" value=\"$red_orig\"><input type=\"hidden\" name=\"BM\" value=\"$BM\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"hidden\" name=\"bin_show_more\" value=\"yes\"><span id=\"selected_indexB\"></span><input type=\"submit\" value=\"$1...\" name=\"B2\" class=\"input_link_w_calc\" onclick=\"create_hidden_selected_index();\"></form>";
} elsif ( $ip_version eq "v6" ) {
	my ($o1,$o2,$o3,$o4,$o5,$o6,$o7,$o8,$o9,$o10,$o11,$o12,$o13,$o14,$o15,$o16,$o17,$o18,$o19,$o20,$o21,$o22,$o23,$o24,$o25,$o26,$o27,$o28,$o29,$o30,$o31,$o32,$a1,$a2,$a3,$a4,$a5,$a6,$a7,$a8);
	$red_exp_orig =~ /^(\w{4})\:(\w{4})\:(\w{4})\:(\w{4})\:(\w{4})\:(\w{4})\:(\w{4})\:(\w{4})$/;
	$a1=$1;
	$a2=$2;
	$a3=$3;
	$a4=$4;
	$a5=$5;
	$a6=$6;
	$a7=$7;
	$a8=$8;

	$bin_show =~ /(\d{4})(\d{4})(\d{4})(\d{4})(\d{4})(\d{4})(\d{4})(\d{4})(\d{4})(\d{4})(\d{4})(\d{4})(\d{4})(\d{4})(\d{4})(\d{4})(\d{4})(\d{4})(\d{4})(\d{4})(\d{4})(\d{4})(\d{4})(\d{4})(\d{4})(\d{4})(\d{4})(\d{4})(\d{4})(\d{4})(\d{4})(\d{4})/;
	$o1=$1;
	$o2=$2;
	$o3=$3;
	$o4=$4;
	$o5=$5;
	$o6=$6;
	$o7=$7;
	$o8=$8;
	$o9=$9;
	$o10=$10;
	$o11=$11;
	$o12=$12;
	$o13=$13;
	$o14=$14;
	$o15=$15;
	$o16=$16;
	$o17=$17;
	$o18=$18;
	$o19=$19;
	$o20=$20;
	$o21=$21;
	$o22=$22;
	$o23=$23;
	$o24=$24;
	$o25=$25;
	$o26=$26;
	$o27=$27;
	$o28=$27;
	$o29=$29;
	$o30=$30;
	$o31=$31;
	$o32=$32;
	$bin_show.="<p><table border=\"1px\" cellpadding=\"5\"><tr align=\"center\"><td></td><td>Hexadecimal</td><td>Binary</td></tr><tr align=\"center\"><td>1. field</td><td>$a1</td><td>$o1 $o2 $o3 $o4</td></tr><tr align=\"center\"><td>2. field</td><td>$a2</td><td>$o5 $o6 $o7 $o8</td></tr><tr align=\"center\"><td>3. field</td><td>$a3</td><td>$o9 $o10 $o11 $o12</td></tr><tr align=\"center\"><td>4. field</td><td>$a4</td><td>$o13 $o14 $o15 $o16</td></tr><tr align=\"center\"><td>5. field</td><td>$a5</td><td>$o17 $o18 $o19 $o20</td></tr><tr align=\"center\"><td>6. field</td><td>$a6</td><td>$o21 $o22 $o23 $o24</td></tr><tr align=\"center\"><td>7. field</td><td>$a7</td><td>$o25 $o26 $o27 $o28</td></tr><tr align=\"center\"><td>8. field</td><td>$a8</td><td>$o29 $o30 $o31 $o32</td></tr></table>";
}
my $short=($ipob_red->short());
$short=$short . "/" . $BM;

my ($red_in,$red_in_bin,$nibbles,$nibbles_red,$rest);
if ( $address_32 ) {
	my $binmask=($ipob_red->binmask());
	if ( $ip_version eq "v4" ) {
		$red_in_bin = $binmask_in & $bin;
		$red_in_bin =~ /([01]{8})([01]{8})([01]{8})([01]{8})/;
		my $red_in_bin_first_oc=$1;
		my $red_in_bin_sec_oc=$2;
		my $red_in_bin_thi_oc=$3;
		my $red_in_bin_fou_oc=$4;
		my $red_in_first = bin2dec("$red_in_bin_first_oc");
		my $red_in_sec = bin2dec("$red_in_bin_sec_oc");
		my $red_in_thi = bin2dec("$red_in_bin_thi_oc");
		my $red_in_fou = bin2dec("$red_in_bin_fou_oc");
		$red_in = $red_in_first . "." . $red_in_sec . "." . $red_in_thi . "." . $red_in_fou;
	} else {
		$binmask_in= "";
		for (my $i = 1; $i <= $BM; $i++) {
			$binmask_in = $binmask_in . "1";
		}
		$rest=128-$BM;
		for (my $i=1;$i<=$rest;$i++) {
			$binmask_in = $binmask_in . "0";
		}
		$red_in_bin = $binmask_in & $bin;
		$red_in=ip_bintoip ($red_in_bin,6);
	}
}

if ( $ip_version eq "v6" ) {
	my $nibbles_pre=$red_exp;
	$nibbles_pre =~ s/://g;
	my @nibbles=split(//,$nibbles_pre);
	my @nibbles_reverse=reverse @nibbles;
	$nibbles="";
	$rest=128-$BM;
	my $red_part_helper = ($rest-1)/4;
	my $bc="1";
	if ( $red_part_helper =~ /\./ ) {
		$red_part_helper =~ /\d\.(\d)/;
		$bc=$1;
	}

	$red_part_helper =~ s/\.\d*//;
	$red_part_helper++ if $bc > 5;


	my $i=1;
	foreach my $num (@nibbles_reverse ) {
		if ( $i==$red_part_helper && $nibbles =~ /\w/) {
			$nibbles = "<span style=\"color: #3B5858;\">". $nibbles . "." . $num . "</span>";
		} elsif ( $i==$red_part_helper && $nibbles eq "") {
			$nibbles = "<span style=\"color: #3B5858;\">". $num . "</span>";
		} elsif ( $nibbles =~ /\w/) {
			$nibbles .= "." . $num;
		} else {
			$nibbles = $num;
		}
		$i++;
	}
	$nibbles .= ".ip6.arpa.";

	my $red_part_helper1 = ($BM+1)/4;
	$bc="1";
	if ( $red_part_helper1 =~ /\./ ) {
		$red_part_helper1 =~ /\d\.(\d)/;
		$bc=$1;
	}
	$red_part_helper1 =~ s/\.\d*//;
	$red_part_helper1++ if $bc >= 5;

	$red_exp="";
	$red_part_helper = 32 - $red_part_helper;
	$i=0;
	foreach my $nib (@nibbles ) {
		if ( $i == 4 || $i==8 || $i==12 || $i==16 || $i==20 || $i==24 || $i==28 ) {
			$red_exp .= ":";
		}
		if ( $i==$red_part_helper1 ) {
			$red_exp .= "<span style=\"color: #3B5858;\">" . $nib;
		} else {
			$red_exp .= $nib;
		}
		$i++;
	}
	$red_exp .= "</span>";
	$red_orig_show = $red_exp;
} else {
	$red_orig_show = $red_orig;
}


$red = $red_in if $red_in;


my $redob_in = $red . "/" . $BM;
my $ipob_red_in = new Net::IP ($redob_in) or die "Can not create IP object: $!\n";;
my $redint=($ipob_red_in->intip()) || 0;
$redint = Math::BigInt->new("$redint") if $ip_version eq "v6";
my $broadcast=($ipob_red_in->last_ip());
my $first_ip_int=$redint+1;
my $first_ip = $gip->int_to_ip("$client_id","$first_ip_int","$ip_version");
my $last_ip_int = ($ipob_red_in->last_int());
$last_ip_int = Math::BigInt->new("$last_ip_int");
my $ip_total=$last_ip_int-$first_ip_int;
my ($red_base85);
if ( $ip_version eq "v4" ) {
	$last_ip_int--;
} else {
	my $base85 = ($gip->GenerateBase("85"))[0];
	$red_base85=$base85->( $redint );
	$ip_total+=2;
}
my $last_ip = $gip->int_to_ip("$client_id","$last_ip_int","$ip_version");
my ($v6,$wildcard);
my $embedded_ipv4="";
if ( $ip_version eq "v4" ) {
	$netmask_in =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/;
	my $first_oc_wi = 255 - $1;
	my $sec_oc_wi = 255 - $2;
	my $thi_oc_wi = 255 - $3;
	my $fou_oc_wi = 255 - $4;
	$wildcard = $first_oc_wi . "." . "$sec_oc_wi" . "." . $thi_oc_wi . "." . $fou_oc_wi;
	$hexip =~ /.x(.*)/;
	$v6=$1;
	my $length_v6=length($v6);
	$v6 = "0" . "$v6" if $length_v6 == 7;
	$v6 =~ /(.{4})(.{4})/;
	$v6="::ffff:" .  $1 . ":" . $2;
} else {
#	$embedded_ipv4 = ip_get_embedded_ipv4($red);
}

print "<script type=\"text/javascript\">\n";
print "document.calculate_form.red.focus();\n";
print "</script>\n";
print "<p><table border=\"0\" cellpadding=\"2\">";
print "<tr><td nowrap>$$lang_vars{ip_address_message}</td><td><b>$red_orig_show</b></td></tr>\n";
print "<tr><td nowrap>$$lang_vars{clase_message}</td><td><b>$class</b></td></tr>\n" if $ip_version eq "v4";
print "<tr><td nowrap>$$lang_vars{tipo_message}</td><td><b>$type</b></td></tr>\n";
print "<tr><td nowrap>$$lang_vars{redes_message}</td><td><b>$red</b></td></tr>\n";
if ( $ip_version eq "v4" ) {
	print "<tr><td nowrap>$$lang_vars{bitmask_message}</td><td><b>$BM</b></td></tr>\n";
	print "<tr><td nowrap>$$lang_vars{netmask_message}</td><td><b>$netmask_in</b></td></tr>\n";
	print "<tr><td nowrap>$$lang_vars{wildcardmask_message}</td><td><b>$wildcard</b></td></tr>\n";
} else {
	print "<tr><td nowrap>Prefix length</td><td><b>$BM</b></td></tr>\n";
	print "<tr><td nowrap>Prefix address</td><td><b>$prefix_address</b></td></tr>\n";
}


if (( $BM == "31" || $BM =="32" && $ip_version eq "v4" )) {
	print "<tr><td>$$lang_vars{host_range_message}</td><td><b>N/A</b></td></tr>\n";
} else {
	if ( $ip_version eq "v4" ) {
		print "<tr><td>$$lang_vars{host_range_message}</td><td><b>$first_ip-<br>$last_ip</b></td></tr>\n";
	} else {
		print "<tr><td>$$lang_vars{address_range_message}</td><td><b>$red_exp_orig-<br>$broadcast</b></td></tr>\n";
	}
}
print "<tr><td nowrap>$$lang_vars{broadcast_message}</td><td><b>$broadcast</b></td></tr>\n" if $ip_version eq "v4";
if (( $BM == "31" || $BM =="32" && $ip_version eq "v4" )) {
	print "<tr><td nowrap>$$lang_vars{ip_en_total_message}</td><td><b>0</b></td></tr>\n";
} else {
	print "<tr><td nowrap>$$lang_vars{ip_en_total_message}</td><td><b>$ip_total</b></td></tr>\n";
}


print "<tr><td><br></td></tr>\n";
my $short_message=$$lang_vars{corto_message};
$short_message="compressed" if $ip_version eq "v6";
print "<tr><td nowrap>$short_message</td><td><b>$short</b></td></tr>\n";
print "<tr><td nowrap>$$lang_vars{int_id_message}</td><td><b>$ip_int</b></td></tr>\n";
print "<tr><td nowrap>$$lang_vars{hex_id_message} I </td><td><b>$hexip</b></td></tr>\n";
print "<tr><td nowrap>$$lang_vars{hex_id_message} II</td><td><b>$hex</b></td></tr>\n";
print "<tr><td nowrap>$$lang_vars{base85_id_message}</td><td><b>$red_base85</b></td></tr>\n" if $ip_version eq "v6";
print "<tr><td><br></td><td></td></tr>\n" if $bin_show_more;
print "<tr><td nowrap valign=\"top\">$$lang_vars{bin_id_message}</td><td><b>$bin_show</b></td></tr>\n";
print "<tr><td><br></td><td></td></tr>\n" if $bin_show_more;
print "<tr><td nowrap>$$lang_vars{ipv6_arpa_format_message}</td><td><b>$nibbles</b></td></tr>\n" if $ip_version eq "v6";
print "<tr><td nowrap>$$lang_vars{mapeada_message}</td><td><b>$v6</b></td></tr>\n" if $ip_version eq "v4";
#print "<tr><td nowrap>$$lang_vars{embedded_ipv4_message}</td><td><b> $red - $embedded_ipv4</b></td></tr>\n" if $ip_version eq "v6" && $embedded_ipv4;
print "<tr><td><br></td></tr>\n";

my $possible_subnets_message=$$lang_vars{subnet_level_message};
$bm{'1'}='9,223,372,036,854,775,808';
$bm{'2'}='4,611,686,018,427,387,904';
$bm{'3'}='2,305,843,009,213,693,952';
$bm{'4'}='1,152,921,504,606,846,976';
$bm{'5'}='576,460,752,303,423,488';
$bm{'6'}='288,230,376,151,711,744';
$bm{'7'}='144,115,188,075,855,872';
$bm{'31'}='2' if $ip_version eq "v4";

my $k=0;
my $test=31;
$test=63 if $ip_version eq "v6";
my $last=32;
$last = 128 if $ip_version eq "v6";
if ( ! $BM_l2 ) {
	my $start = $BM+1;
	my $net_host_message="";
	$possible_subnets_message .= " I";
	for (my $i=$start; $i<=$last; $i++) {
		last if ! defined($bm{$test});
		$bm{$i}-=2 if $ip_version eq "v4";
		$net_host_message = "($bm{$i} $$lang_vars{direcciones_message})" if $more_possible_subnets;
		$net_host_message = "($bm{$i} $$lang_vars{entradas_redes_message})" if $i < 64 && $ip_version eq "v6" && $more_possible_subnets;
		$net_host_message = "" if $ip_version eq "v4" && ( $i == 31 || $i == 32 );
#		print "<tr><td>$possible_subnets_message</td><td><b><form name=\"calculate_form_more\" id=\"calculate_form_more\" method=\"POST\" action=\"$server_proto://$base_uri/ip_calculatered.cgi\" style=\"display:inline\"><input type=\"hidden\" name=\"red\" value=\"$red_orig\"><input type=\"hidden\" name=\"BM\" value=\"$daten{BM}\"><input type=\"hidden\" name=\"ip_version\" value=\"$ip_version\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"hidden\" name=\"more_possible_subnets\" value=\"yes\"><input type=\"hidden\" name=\"BM_l2\" value=\"${i}\"><input type=\"hidden\" name=\"BM_l2_anz\" value=\"$bm{$test}\"><span id=\"selected_index${k}\"></span><input type=\"submit\" value=\"$bm{$test} networks /${i}\" name=\"B2\" class=\"input_link_w_net\" onclick=\"create_hidden_selected_index();saveScrollCoordinates();\"></form></b> $net_host_message</td></tr>\n";
		print "<tr><td>$possible_subnets_message</td><td><b><form name=\"calculate_form_more\" id=\"calculate_form_more\" method=\"POST\" action=\"$server_proto://$base_uri/ip_calculatered.cgi\" style=\"display:inline\"><input type=\"hidden\" name=\"red\" value=\"$red_orig\"><input type=\"hidden\" name=\"BM\" value=\"$BM\"><input type=\"hidden\" name=\"ip_version\" value=\"$ip_version\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"hidden\" name=\"more_possible_subnets\" value=\"yes\"><input type=\"hidden\" name=\"BM_l2\" value=\"${i}\"><input type=\"hidden\" name=\"BM_l2_anz\" value=\"$bm{$test}\"><span id=\"selected_index${k}\"></span><input type=\"submit\" value=\"$bm{$test} networks /${i}\" name=\"B2\" class=\"input_link_w_net\" onclick=\"create_hidden_selected_index();saveScrollCoordinates();\"></form></b> $net_host_message</td></tr>\n";
		$possible_subnets_message="";
		if ( ! $more_possible_subnets && $k==2 ) {
#			print "<tr><td></td><td><form name=\"calculate_form_more\" id=\"calculate_form_more\" method=\"POST\" action=\"$server_proto://$base_uri/ip_calculatered.cgi\"><input type=\"hidden\" name=\"red\" value=\"$red_orig\"><input type=\"hidden\" name=\"BM\" value=\"$daten{BM}\"><input type=\"hidden\" name=\"ip_version\" value=\"$ip_version\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"hidden\" name=\"more_possible_subnets\" value=\"yes\"><span id=\"selected_index3\"></span><input type=\"submit\" value=\"$$lang_vars{more_message}\" name=\"B2\" class=\"input_link_w_net\" onclick=\"create_hidden_selected_index();saveScrollCoordinates();\"></form></td></tr>\n";
			print "<tr><td></td><td><form name=\"calculate_form_more\" id=\"calculate_form_more\" method=\"POST\" action=\"$server_proto://$base_uri/ip_calculatered.cgi\"><input type=\"hidden\" name=\"red\" value=\"$red_orig\"><input type=\"hidden\" name=\"BM\" value=\"$BM\"><input type=\"hidden\" name=\"ip_version\" value=\"$ip_version\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"hidden\" name=\"more_possible_subnets\" value=\"yes\"><span id=\"selected_index3\"></span><input type=\"submit\" value=\"$$lang_vars{more_message}\" name=\"B2\" class=\"input_link_w_net\" onclick=\"create_hidden_selected_index();saveScrollCoordinates();\"></form></td></tr>\n";
			last;
		}
		$test--;
		$k++;
		last if $k == "63";
	}
} elsif ( $BM_l2 && ! $BM_l3 ) {

	my $redob_in_l2 = $red . "/" . $BM_l2;
	my $ipob_red_in_l2 = new Net::IP ($redob_in_l2) or die "Can not create IP object: $!\n";
	my $last_ip_int_l2 = ($ipob_red_in_l2->last_int());
	$last_ip_int_l2 = Math::BigInt->new("$last_ip_int_l2");
	my $redint_l2=($ipob_red_in_l2->intip()) || 0;
	$redint_l2 = Math::BigInt->new("$redint_l2");
	$redint_l2--;
	my $BM_l2_anz=$daten{BM_l2_anz};
	my $BM_l2_value=$last_ip_int_l2-$redint_l2;
	$BM_l2_value = Math::BigInt->new("$BM_l2_value");
	my $first_ip_last_red_int=$last_ip_int - $BM_l2_value + 2;

	$first_ip_last_red_int-- if $ip_version eq "v6";
	$first_ip_last_red_int = Math::BigInt->new("$first_ip_last_red_int");
	my $first_ip_last_red = $gip->int_to_ip("$client_id","$first_ip_last_red_int","$ip_version");
	$first_ip_last_red=ip_compress_address ($first_ip_last_red, 6) if $ip_version eq "v6";
	print "<tr><td>$$lang_vars{subnet_level_message} I</td><td><b>$BM_l2_anz networks /${BM_l2}</b><br>($red/${BM_l2} - $first_ip_last_red/${BM_l2}) <INPUT TYPE=\"BUTTON\" VALUE=\"back\" ONCLICK=\"history.go(-1)\" class=\"error_back_link\"></FORM></td></tr>\n";
	my $start = $BM_l2+1;
	my $net_host_message="";
	$possible_subnets_message .= " II";
	for (my $i=$start; $i<=$last; $i++) {
		last if ! defined($bm{$test});
		$bm{$i}-=2 if $ip_version eq "v4";
		$net_host_message = "($bm{$i} $$lang_vars{direcciones_message})";
		$net_host_message = "($bm{$i} $$lang_vars{entradas_redes_message})" if $i < 64 && $ip_version eq "v6";
		$net_host_message = "" if $ip_version eq "v4" && ( $i == 31 || $i == 32 );
#		print "<tr><td>$possible_subnets_message</td><td>&nbsp;&nbsp;&nbsp;&nbsp;<b><form name=\"calculate_form_more\" id=\"calculate_form_more\" method=\"POST\" action=\"$server_proto://$base_uri/ip_calculatered.cgi\" style=\"display:inline\"><input type=\"hidden\" name=\"red\" value=\"$red_orig\"><input type=\"hidden\" name=\"BM\" value=\"$daten{BM}\"><input type=\"hidden\" name=\"ip_version\" value=\"$ip_version\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"hidden\" name=\"more_possible_subnets\" value=\"yes\"><input type=\"hidden\" name=\"BM_l2\" value=\"${BM_l2}\"><input type=\"hidden\" name=\"BM_l2_anz\" value=\"$BM_l2_anz\"><input type=\"hidden\" name=\"first_ip_last_red_l2\" value=\"$first_ip_last_red\"><input type=\"hidden\" name=\"BM_l3\" value=\"${i}\"><input type=\"hidden\" name=\"BM_l3_anz\" value=\"$bm{$test}\"><span id=\"selected_index${k}\"></span><input type=\"submit\" value=\"$bm{$test} networks /${i}\" name=\"B2\" class=\"input_link_w_net\" onclick=\"create_hidden_selected_index();saveScrollCoordinates();\"></form></b> $net_host_message</td></tr>\n";
		print "<tr><td>$possible_subnets_message</td><td>&nbsp;&nbsp;&nbsp;&nbsp;<b><form name=\"calculate_form_more\" id=\"calculate_form_more\" method=\"POST\" action=\"$server_proto://$base_uri/ip_calculatered.cgi\" style=\"display:inline\"><input type=\"hidden\" name=\"red\" value=\"$red_orig\"><input type=\"hidden\" name=\"BM\" value=\"$BM\"><input type=\"hidden\" name=\"ip_version\" value=\"$ip_version\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"hidden\" name=\"more_possible_subnets\" value=\"yes\"><input type=\"hidden\" name=\"BM_l2\" value=\"${BM_l2}\"><input type=\"hidden\" name=\"BM_l2_anz\" value=\"$BM_l2_anz\"><input type=\"hidden\" name=\"first_ip_last_red_l2\" value=\"$first_ip_last_red\"><input type=\"hidden\" name=\"BM_l3\" value=\"${i}\"><input type=\"hidden\" name=\"BM_l3_anz\" value=\"$bm{$test}\"><span id=\"selected_index${k}\"></span><input type=\"submit\" value=\"$bm{$test} networks /${i}\" name=\"B2\" class=\"input_link_w_net\" onclick=\"create_hidden_selected_index();saveScrollCoordinates();\"></form></b> $net_host_message</td></tr>\n";
		$possible_subnets_message="";
		$test--;
		$k++;
		last if $k == "63";
	}
} elsif ( $BM_l3 && !$BM_l4 ) {
	my $first_ip_last_red_l2=$daten{first_ip_last_red_l2};
	my $BM_l2_anz=$daten{BM_l2_anz};
	my $first_ip_last_red=ip_compress_address ($first_ip_last_red_l2, 6) if $ip_version eq "v6";

	my $redob_in_l3 = $red . "/" . $BM_l3;
	my $ipob_red_in_l3 = new Net::IP ($redob_in_l3) or die "Can not create IP object: $!\n";
	my $last_ip_int_l3 = ($ipob_red_in_l3->last_int());
	$last_ip_int_l3 = Math::BigInt->new("$last_ip_int_l3");
	my $redint_l3=($ipob_red_in_l3->intip()) || 0;
	$redint_l3 = Math::BigInt->new("$redint_l3");
	$redint_l3--;
	my $BM_l3_anz=$daten{BM_l3_anz};
	my $BM_l3_value=$last_ip_int_l3-$redint_l3;
	$BM_l3_value = Math::BigInt->new("$BM_l3_value");
	my $first_ip_last_red_int_l3=$last_ip_int - $BM_l3_value + 2;
	my $first_ip_last_red_l3 = $gip->int_to_ip("$client_id","$first_ip_last_red_int_l3","$ip_version");
	$first_ip_last_red_l3=ip_compress_address ($first_ip_last_red_l3, 6) if $ip_version eq "v6";
	print "<tr><td>$$lang_vars{subnet_level_message} I</td><td><b>$BM_l2_anz networks /${BM_l2}</b><br>($red/${BM_l2} - $first_ip_last_red/${BM_l2})</td></tr>\n";
	print "<tr><td>$$lang_vars{subnet_level_message} II</td><td>&nbsp;&nbsp;&nbsp;&nbsp;<b>$BM_l3_anz networks /${BM_l3}</b><br>&nbsp;&nbsp;&nbsp;&nbsp;($red/${BM_l3} - $first_ip_last_red_l3/${BM_l3}) <INPUT TYPE=\"BUTTON\" VALUE=\"back\" ONCLICK=\"history.go(-1)\" class=\"error_back_link\"></FORM></td></tr>\n";
	my $start = $BM_l3+1;
	my $net_host_message="";
	$possible_subnets_message .= " III";
	for (my $i=$start; $i<=$last; $i++) {
		last if ! defined($bm{$test});
		$bm{$i}-=2 if $ip_version eq "v4";
		$net_host_message = "($bm{$i} $$lang_vars{direcciones_message})";
		$net_host_message = "($bm{$i} $$lang_vars{entradas_redes_message})" if $i < 64 && $ip_version eq "v6";
		$net_host_message = "" if $ip_version eq "v4" && ( $i == 31 || $i == 32 );
#		print "<tr><td>$possible_subnets_message</td><td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<b><form name=\"calculate_form_more\" id=\"calculate_form_more\" method=\"POST\" action=\"$server_proto://$base_uri/ip_calculatered.cgi\" style=\"display:inline\"><input type=\"hidden\" name=\"red\" value=\"$red_orig\"><input type=\"hidden\" name=\"BM\" value=\"$daten{BM}\"><input type=\"hidden\" name=\"ip_version\" value=\"$ip_version\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"hidden\" name=\"more_possible_subnets\" value=\"yes\"><input type=\"hidden\" name=\"BM_l2\" value=\"${BM_l2}\"><input type=\"hidden\" name=\"BM_l2_anz\" value=\"$BM_l2_anz\"><input type=\"hidden\" name=\"first_ip_last_red_l2\" value=\"$first_ip_last_red_l2\"><input type=\"hidden\" name=\"BM_l3\" value=\"${BM_l3}\"><input type=\"hidden\" name=\"BM_l3_anz\" value=\"$BM_l3_anz\"><input type=\"hidden\" name=\"first_ip_last_red_l3\" value=\"$first_ip_last_red_l3\"><input type=\"hidden\" name=\"BM_l4\" value=\"${i}\"><input type=\"hidden\" name=\"BM_l4_anz\" value=\"$bm{$test}\"><span id=\"selected_index${k}\"></span><input type=\"submit\" value=\"$bm{$test} networks /${i}\" name=\"B2\" class=\"input_link_w_net\" onclick=\"create_hidden_selected_index();saveScrollCoordinates();\"></form></b> $net_host_message</td></tr>\n";
		print "<tr><td>$possible_subnets_message</td><td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<b><form name=\"calculate_form_more\" id=\"calculate_form_more\" method=\"POST\" action=\"$server_proto://$base_uri/ip_calculatered.cgi\" style=\"display:inline\"><input type=\"hidden\" name=\"red\" value=\"$red_orig\"><input type=\"hidden\" name=\"BM\" value=\"$BM\"><input type=\"hidden\" name=\"ip_version\" value=\"$ip_version\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"hidden\" name=\"more_possible_subnets\" value=\"yes\"><input type=\"hidden\" name=\"BM_l2\" value=\"${BM_l2}\"><input type=\"hidden\" name=\"BM_l2_anz\" value=\"$BM_l2_anz\"><input type=\"hidden\" name=\"first_ip_last_red_l2\" value=\"$first_ip_last_red_l2\"><input type=\"hidden\" name=\"BM_l3\" value=\"${BM_l3}\"><input type=\"hidden\" name=\"BM_l3_anz\" value=\"$BM_l3_anz\"><input type=\"hidden\" name=\"first_ip_last_red_l3\" value=\"$first_ip_last_red_l3\"><input type=\"hidden\" name=\"BM_l4\" value=\"${i}\"><input type=\"hidden\" name=\"BM_l4_anz\" value=\"$bm{$test}\"><span id=\"selected_index${k}\"></span><input type=\"submit\" value=\"$bm{$test} networks /${i}\" name=\"B2\" class=\"input_link_w_net\" onclick=\"create_hidden_selected_index();saveScrollCoordinates();\"></form></b> $net_host_message</td></tr>\n";
		$possible_subnets_message="";
		$test--;
		$k++;
		last if $k == "63";
	}
} elsif ( $BM_l4 && ! $BM_l5 ) {

	my $first_ip_last_red_l2=$daten{first_ip_last_red_l2};
	my $first_ip_last_red_l3=$daten{first_ip_last_red_l3};
	my $BM_l2_anz=$daten{BM_l2_anz};
	my $BM_l3_anz=$daten{BM_l3_anz};
	my $first_ip_last_red=ip_compress_address ($first_ip_last_red_l2, 6) if $ip_version eq "v6";
	$first_ip_last_red_l3=ip_compress_address ($first_ip_last_red_l3, 6) if $ip_version eq "v6";

	my $redob_in_l4 = $red . "/" . $BM_l4;
	my $ipob_red_in_l4 = new Net::IP ($redob_in_l4) or die "Can not create IP object: $!\n";
	my $last_ip_int_l4 = ($ipob_red_in_l4->last_int());
	$last_ip_int_l4 = Math::BigInt->new("$last_ip_int_l4");
	my $redint_l4=($ipob_red_in_l4->intip()) || 0;
	$redint_l4 = Math::BigInt->new("$redint_l4");
	$redint_l4--;
	my $BM_l4_anz=$daten{BM_l4_anz};
	my $BM_l4_value=$last_ip_int_l4-$redint_l4;
	$BM_l4_value = Math::BigInt->new("$BM_l4_value");
	my $first_ip_last_red_int_l4=$last_ip_int - $BM_l4_value + 2;
	my $first_ip_last_red_l4 = $gip->int_to_ip("$client_id","$first_ip_last_red_int_l4","$ip_version");
	$first_ip_last_red_l4=ip_compress_address ($first_ip_last_red_l4, 6) if $ip_version eq "v6";

	print "<tr><td>$$lang_vars{subnet_level_message} I</td><td><b>$BM_l2_anz networks /${BM_l2}</b><br>($red/${BM_l2} - $first_ip_last_red/${BM_l2})</td></tr>\n";
	print "<tr><td>$$lang_vars{subnet_level_message} II</td><td>&nbsp;&nbsp;&nbsp;&nbsp;<b>$BM_l3_anz networks /${BM_l3}</b><br>&nbsp;&nbsp;&nbsp;&nbsp;($red/${BM_l3} - $first_ip_last_red_l3/${BM_l3})</td></tr>\n";
	print "<tr><td>$$lang_vars{subnet_level_message} III</td><td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<b>$BM_l4_anz networks /${BM_l4}</b><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;($red/${BM_l4} - $first_ip_last_red_l4/${BM_l4}) <INPUT TYPE=\"BUTTON\" VALUE=\"back\" ONCLICK=\"history.go(-1)\" class=\"error_back_link\"></FORM></td></tr>\n";
	my $start = $BM_l4+1;
	my $net_host_message="";
	$possible_subnets_message .= " IV";
	for (my $i=$start; $i<=$last; $i++) {
		last if ! defined($bm{$test});
		$bm{$i}-=2 if $ip_version eq "v4";
		$net_host_message = "($bm{$i} $$lang_vars{direcciones_message})";
		$net_host_message = "($bm{$i} $$lang_vars{entradas_redes_message})" if $i < 64 && $ip_version eq "v6";
		$net_host_message = "" if $ip_version eq "v4" && ( $i == 31 || $i == 32 );
		print "<tr><td>$possible_subnets_message</td><td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<b><form name=\"calculate_form_more\" id=\"calculate_form_more\" method=\"POST\" action=\"$server_proto://$base_uri/ip_calculatered.cgi\" style=\"display:inline\"><input type=\"hidden\" name=\"red\" value=\"$red_orig\"><input type=\"hidden\" name=\"BM\" value=\"$daten{BM}\"><input type=\"hidden\" name=\"ip_version\" value=\"$ip_version\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"hidden\" name=\"more_possible_subnets\" value=\"yes\"><input type=\"hidden\" name=\"BM_l2\" value=\"${BM_l2}\"><input type=\"hidden\" name=\"BM_l2_anz\" value=\"$BM_l2_anz\"><input type=\"hidden\" name=\"first_ip_last_red_l2\" value=\"$first_ip_last_red_l2\"><input type=\"hidden\" name=\"BM_l3\" value=\"${BM_l3}\"><input type=\"hidden\" name=\"BM_l3_anz\" value=\"$BM_l3_anz\"><input type=\"hidden\" name=\"first_ip_last_red_l3\" value=\"$first_ip_last_red_l3\"><input type=\"hidden\" name=\"BM_l4\" value=\"${BM_l4}\"><input type=\"hidden\" name=\"BM_l4_anz\" value=\"$BM_l4_anz\"><input type=\"hidden\" name=\"first_ip_last_red_l4\" value=\"$first_ip_last_red_l4\"><input type=\"hidden\" name=\"BM_l5\" value=\"${i}\"><input type=\"hidden\" name=\"BM_l5_anz\" value=\"$bm{$test}\"><span id=\"selected_index${k}\"></span><input type=\"submit\" value=\"$bm{$test} networks /${i}\" name=\"B2\" class=\"input_link_w_net\" onclick=\"create_hidden_selected_index();saveScrollCoordinates();\"></form></b> $net_host_message</td></tr>\n";
		$possible_subnets_message="";
		$test--;
		$k++;
		last if $k == "63";
		last if $k == "63";
	}
} elsif ( $BM_l5 && ! $BM_l6 ) {

	my $first_ip_last_red_l2=$daten{first_ip_last_red_l2};
	my $first_ip_last_red_l3=$daten{first_ip_last_red_l3};
	my $first_ip_last_red_l4=$daten{first_ip_last_red_l4};
	my $BM_l2_anz=$daten{BM_l2_anz};
	my $BM_l3_anz=$daten{BM_l3_anz};
	my $BM_l4_anz=$daten{BM_l4_anz};
	my $first_ip_last_red=ip_compress_address ($first_ip_last_red_l2, 6) if $ip_version eq "v6";
	$first_ip_last_red_l3=ip_compress_address ($first_ip_last_red_l3, 6) if $ip_version eq "v6";
	$first_ip_last_red_l4=ip_compress_address ($first_ip_last_red_l4, 6) if $ip_version eq "v6";

	my $redob_in_l5 = $red . "/" . $BM_l5;
	my $ipob_red_in_l5 = new Net::IP ($redob_in_l5) or die "Can not create IP object: $!\n";
	my $last_ip_int_l5 = ($ipob_red_in_l5->last_int());
	$last_ip_int_l5 = Math::BigInt->new("$last_ip_int_l5");
	my $redint_l5=($ipob_red_in_l5->intip()) || 0;
	$redint_l5 = Math::BigInt->new("$redint_l5");
	$redint_l5--;
	my $BM_l5_anz=$daten{BM_l5_anz};
	my $BM_l5_value=$last_ip_int_l5-$redint_l5;
	$BM_l5_value = Math::BigInt->new("$BM_l5_value");
	my $first_ip_last_red_int_l5=$last_ip_int - $BM_l5_value + 2;
	my $first_ip_last_red_l5 = $gip->int_to_ip("$client_id","$first_ip_last_red_int_l5","$ip_version");
	$first_ip_last_red_l5=ip_compress_address ($first_ip_last_red_l5, 6) if $ip_version eq "v6";

	print "<tr><td>$$lang_vars{subnet_level_message} I</td><td><b>$BM_l2_anz networks /${BM_l2}</b><br>($red/${BM_l2} - $first_ip_last_red/${BM_l2})</td></tr>\n";
	print "<tr><td>$$lang_vars{subnet_level_message} II</td><td>&nbsp;&nbsp;&nbsp;&nbsp;<b>$BM_l3_anz networks /${BM_l3}</b><br>&nbsp;&nbsp;&nbsp;&nbsp;($red/${BM_l3} - $first_ip_last_red_l3/${BM_l3})</td></tr>\n";
	print "<tr><td>$$lang_vars{subnet_level_message} III</td><td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<b>$BM_l4_anz networks /${BM_l4}</b><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;($red/${BM_l4} - $first_ip_last_red_l4/${BM_l4})</td></tr>\n";
	print "<tr><td>$$lang_vars{subnet_level_message} IV</td><td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<b>$BM_l5_anz networks /${BM_l5}</b><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;($red/${BM_l5} - $first_ip_last_red_l5/${BM_l5}) <FORM style=\"display:inline\"><INPUT TYPE=\"BUTTON\" VALUE=\"back\" ONCLICK=\"history.go(-1)\" class=\"error_back_link\"></FORM></td></tr>\n";
	my $start = $BM_l5+1;
	my $net_host_message="";
	$possible_subnets_message .= " V";
	for (my $i=$start; $i<=$last; $i++) {
		last if ! defined($bm{$test});
		$bm{$i}-=2 if $ip_version eq "v4";
		$net_host_message = "($bm{$i} $$lang_vars{direcciones_message})";
		$net_host_message = "($bm{$i} $$lang_vars{entradas_redes_message})" if $i < 64 && $ip_version eq "v6";
		$net_host_message = "" if $ip_version eq "v4" && ( $i == 31 || $i == 32 );
		print "<tr><td>$possible_subnets_message</td><td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<b><form name=\"calculate_form_more\" id=\"calculate_form_more\" method=\"POST\" action=\"$server_proto://$base_uri/ip_calculatered.cgi\" style=\"display:inline\"><input type=\"hidden\" name=\"red\" value=\"$red_orig\"><input type=\"hidden\" name=\"BM\" value=\"$daten{BM}\"><input type=\"hidden\" name=\"ip_version\" value=\"$ip_version\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"hidden\" name=\"more_possible_subnets\" value=\"yes\"><input type=\"hidden\" name=\"BM_l2\" value=\"${BM_l2}\"><input type=\"hidden\" name=\"BM_l2_anz\" value=\"$BM_l2_anz\"><input type=\"hidden\" name=\"first_ip_last_red_l2\" value=\"$first_ip_last_red_l2\"><input type=\"hidden\" name=\"BM_l3\" value=\"${BM_l3}\"><input type=\"hidden\" name=\"BM_l3_anz\" value=\"$BM_l3_anz\"><input type=\"hidden\" name=\"first_ip_last_red_l3\" value=\"$first_ip_last_red_l3\"><input type=\"hidden\" name=\"BM_l4\" value=\"${BM_l4}\"><input type=\"hidden\" name=\"BM_l4_anz\" value=\"$BM_l4_anz\"><input type=\"hidden\" name=\"first_ip_last_red_l4\" value=\"$first_ip_last_red_l4\"><input type=\"hidden\" name=\"BM_l5\" value=\"${BM_l5}\"><input type=\"hidden\" name=\"BM_l5_anz\" value=\"$BM_l5_anz\"><input type=\"hidden\" name=\"first_ip_last_red_l5\" value=\"$first_ip_last_red_l5\"><input type=\"hidden\" name=\"BM_l6\" value=\"${i}\"><input type=\"hidden\" name=\"BM_l6_anz\" value=\"$bm{$test}\"><span id=\"selected_index${k}\"></span><input type=\"submit\" value=\"$bm{$test} networks /${i}\" name=\"B2\" class=\"input_link_w_net\" onclick=\"create_hidden_selected_index();saveScrollCoordinates();\"></form></b> $net_host_message</td></tr>\n";
		$possible_subnets_message="";
		$test--;
		$k++;
		last if $k == "63";
	}
} elsif ( $BM_l6 && ! $BM_l7 ) {

	my $first_ip_last_red_l2=$daten{first_ip_last_red_l2};
	my $first_ip_last_red_l3=$daten{first_ip_last_red_l3};
	my $first_ip_last_red_l4=$daten{first_ip_last_red_l4};
	my $first_ip_last_red_l5=$daten{first_ip_last_red_l5};
	my $BM_l2_anz=$daten{BM_l2_anz};
	my $BM_l3_anz=$daten{BM_l3_anz};
	my $BM_l4_anz=$daten{BM_l4_anz};
	my $BM_l5_anz=$daten{BM_l5_anz};
	my $first_ip_last_red=ip_compress_address ($first_ip_last_red_l2, 6) if $ip_version eq "v6";
	$first_ip_last_red_l3=ip_compress_address ($first_ip_last_red_l3, 6) if $ip_version eq "v6";
	$first_ip_last_red_l4=ip_compress_address ($first_ip_last_red_l4, 6) if $ip_version eq "v6";
	$first_ip_last_red_l5=ip_compress_address ($first_ip_last_red_l5, 6) if $ip_version eq "v6";

	my $redob_in_l6 = $red . "/" . $BM_l6;
	my $ipob_red_in_l6 = new Net::IP ($redob_in_l6) or die "Can not create IP object: $!\n";
	my $last_ip_int_l6 = ($ipob_red_in_l6->last_int());
	$last_ip_int_l6 = Math::BigInt->new("$last_ip_int_l6");
	my $redint_l6=($ipob_red_in_l6->intip()) || 0;
	$redint_l6 = Math::BigInt->new("$redint_l6");
	$redint_l6--;
	my $BM_l6_anz=$daten{BM_l6_anz};
	my $BM_l6_value=$last_ip_int_l6-$redint_l6;
	$BM_l6_value = Math::BigInt->new("$BM_l6_value");
	my $first_ip_last_red_int_l6=$last_ip_int - $BM_l6_value + 2;
	my $first_ip_last_red_l6 = $gip->int_to_ip("$client_id","$first_ip_last_red_int_l6","$ip_version");
	$first_ip_last_red_l6=ip_compress_address ($first_ip_last_red_l6, 6) if $ip_version eq "v6";

	print "<tr><td>$$lang_vars{subnet_level_message} I</td><td><b>$BM_l2_anz networks /${BM_l2}</b><br>($red/${BM_l2} - $first_ip_last_red/${BM_l2})</td></tr>\n";
	print "<tr><td>$$lang_vars{subnet_level_message} II</td><td>&nbsp;&nbsp;&nbsp;&nbsp;<b>$BM_l3_anz networks /${BM_l3}</b><br>&nbsp;&nbsp;&nbsp;&nbsp;($red/${BM_l3} - $first_ip_last_red_l3/${BM_l3})</td></tr>\n";
	print "<tr><td>$$lang_vars{subnet_level_message} III</td><td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<b>$BM_l4_anz networks /${BM_l4}</b><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;($red/${BM_l4} - $first_ip_last_red_l4/${BM_l4})</td></tr>\n";
	print "<tr><td>$$lang_vars{subnet_level_message} IV</td><td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<b>$BM_l5_anz networks /${BM_l5}</b><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;($red/${BM_l5} - $first_ip_last_red_l5/${BM_l5})</td></tr>\n";
	print "<tr><td>$$lang_vars{subnet_level_message} V</td><td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<b>$BM_l6_anz networks /${BM_l6}</b><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;($red/${BM_l6} - $first_ip_last_red_l6/${BM_l6}) <FORM style=\"display:inline\"><INPUT TYPE=\"BUTTON\" VALUE=\"back\" ONCLICK=\"history.go(-1)\" class=\"error_back_link\"></FORM></td></tr>\n";
	my $start = $BM_l6+1;
	my $net_host_message="";
	$possible_subnets_message .= " VI";
	for (my $i=$start; $i<=$last; $i++) {
		last if ! defined($bm{$test});
		$bm{$i}-=2 if $ip_version eq "v4";
		$net_host_message = "($bm{$i} $$lang_vars{direcciones_message})";
		$net_host_message = "($bm{$i} $$lang_vars{entradas_redes_message})" if $i < 64 && $ip_version eq "v6";
		$net_host_message = "" if $ip_version eq "v4" && ( $i == 31 || $i == 32 );
		print "<tr><td>$possible_subnets_message</td><td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<b><form name=\"calculate_form_more\" id=\"calculate_form_more\" method=\"POST\" action=\"$server_proto://$base_uri/ip_calculatered.cgi\" style=\"display:inline\"><input type=\"hidden\" name=\"red\" value=\"$red_orig\"><input type=\"hidden\" name=\"BM\" value=\"$daten{BM}\"><input type=\"hidden\" name=\"ip_version\" value=\"$ip_version\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"hidden\" name=\"more_possible_subnets\" value=\"yes\"><input type=\"hidden\" name=\"BM_l2\" value=\"${BM_l2}\"><input type=\"hidden\" name=\"BM_l2_anz\" value=\"$BM_l2_anz\"><input type=\"hidden\" name=\"BM_l3\" value=\"${BM_l3}\"><input type=\"hidden\" name=\"BM_l3_anz\" value=\"$BM_l3_anz\"><input type=\"hidden\" name=\"BM_l4\" value=\"${BM_l4}\"><input type=\"hidden\" name=\"BM_l4_anz\" value=\"$BM_l4_anz\"><input type=\"hidden\" name=\"BM_l5\" value=\"${BM_l5}\"><input type=\"hidden\" name=\"BM_l5_anz\" value=\"$BM_l5_anz\"><input type=\"hidden\" name=\"BM_l6\" value=\"${BM_l6}\"><input type=\"hidden\" name=\"BM_l6_anz\" value=\"$BM_l6_anz\"><input type=\"hidden\" name=\"BM_l7\" value=\"${i}\"><input type=\"hidden\" name=\"BM_l7_anz\" value=\"$bm{$test}\"><input type=\"hidden\" name=\"first_ip_last_red_l2\" value=\"$first_ip_last_red_l2\"><input type=\"hidden\" name=\"first_ip_last_red_l3\" value=\"$first_ip_last_red_l3\"><input type=\"hidden\" name=\"first_ip_last_red_l4\" value=\"$first_ip_last_red_l4\"><input type=\"hidden\" name=\"first_ip_last_red_l5\" value=\"$first_ip_last_red_l5\"><input type=\"hidden\" name=\"first_ip_last_red_l6\" value=\"$first_ip_last_red_l6\"><span id=\"selected_index${k}\"></span><input type=\"submit\" value=\"$bm{$test} networks /${i}\" name=\"B2\" class=\"input_link_w_net\" onclick=\"create_hidden_selected_index();saveScrollCoordinates();\"></form></b> $net_host_message</td></tr>\n";
		$possible_subnets_message="";
		$test--;
		$k++;
		last if $k == "63";
	}
} elsif ( $BM_l7 && ! $BM_l8 ) {

	my $first_ip_last_red_l2=$daten{first_ip_last_red_l2};
	my $first_ip_last_red_l3=$daten{first_ip_last_red_l3};
	my $first_ip_last_red_l4=$daten{first_ip_last_red_l4};
	my $first_ip_last_red_l5=$daten{first_ip_last_red_l5};
	my $first_ip_last_red_l6=$daten{first_ip_last_red_l6};
	my $BM_l2_anz=$daten{BM_l2_anz};
	my $BM_l3_anz=$daten{BM_l3_anz};
	my $BM_l4_anz=$daten{BM_l4_anz};
	my $BM_l5_anz=$daten{BM_l5_anz};
	my $BM_l6_anz=$daten{BM_l6_anz};
	my $first_ip_last_red=ip_compress_address ($first_ip_last_red_l2, 6) if $ip_version eq "v6";
	$first_ip_last_red_l3=ip_compress_address ($first_ip_last_red_l3, 6) if $ip_version eq "v6";
	$first_ip_last_red_l4=ip_compress_address ($first_ip_last_red_l4, 6) if $ip_version eq "v6";
	$first_ip_last_red_l5=ip_compress_address ($first_ip_last_red_l5, 6) if $ip_version eq "v6";
	$first_ip_last_red_l6=ip_compress_address ($first_ip_last_red_l6, 6) if $ip_version eq "v6";

	my $redob_in_l7 = $red . "/" . $BM_l7;
	my $ipob_red_in_l7 = new Net::IP ($redob_in_l7) or die "Can not create IP object: $!\n";
	my $last_ip_int_l7 = ($ipob_red_in_l7->last_int());
	$last_ip_int_l7 = Math::BigInt->new("$last_ip_int_l7");
	my $redint_l7=($ipob_red_in_l7->intip()) || 0;
	$redint_l7 = Math::BigInt->new("$redint_l7");
	$redint_l7--;
	my $BM_l7_anz=$daten{BM_l7_anz};
	my $BM_l7_value=$last_ip_int_l7-$redint_l7;
	$BM_l7_value = Math::BigInt->new("$BM_l7_value");
	my $first_ip_last_red_int_l7=$last_ip_int - $BM_l7_value + 2;
	my $first_ip_last_red_l7 = $gip->int_to_ip("$client_id","$first_ip_last_red_int_l7","$ip_version");
	$first_ip_last_red_l7=ip_compress_address ($first_ip_last_red_l7, 6) if $ip_version eq "v6";

	print "<tr><td>$$lang_vars{subnet_level_message} I</td><td><b>$BM_l2_anz networks /${BM_l2}</b><br>($red/${BM_l2} - $first_ip_last_red/${BM_l2})</td></tr>\n";
	print "<tr><td>$$lang_vars{subnet_level_message} II</td><td>&nbsp;&nbsp;&nbsp;&nbsp;<b>$BM_l3_anz networks /${BM_l3}</b><br>&nbsp;&nbsp;&nbsp;&nbsp;($red/${BM_l3} - $first_ip_last_red_l3/${BM_l3})</td></tr>\n";
	print "<tr><td>$$lang_vars{subnet_level_message} III</td><td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<b>$BM_l4_anz networks /${BM_l4}</b><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;($red/${BM_l4} - $first_ip_last_red_l4/${BM_l4})</td></tr>\n";
	print "<tr><td>$$lang_vars{subnet_level_message} IV</td><td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<b>$BM_l4_anz networks /${BM_l5}</b><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;($red/${BM_l5} - $first_ip_last_red_l5/${BM_l5})</td></tr>\n";
	print "<tr><td>$$lang_vars{subnet_level_message} V</td><td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<b>$BM_l6_anz networks /${BM_l6}</b><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;($red/${BM_l6} - $first_ip_last_red_l6/${BM_l6})</td></tr>\n";
	print "<tr><td>$$lang_vars{subnet_level_message} VI</td><td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<b>$BM_l7_anz networks /${BM_l7}</b><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;($red/${BM_l7} - $first_ip_last_red_l7/${BM_l7}) <FORM style=\"display:inline\"><INPUT TYPE=\"BUTTON\" VALUE=\"back\" ONCLICK=\"history.go(-1)\" class=\"error_back_link\"></FORM></td></tr>\n";
	my $start = $BM_l7+1;
	my $net_host_message="";
	$possible_subnets_message .= " VII";
	for (my $i=$start; $i<=$last; $i++) {
		last if ! defined($bm{$test});
		$bm{$i}-=2 if $ip_version eq "v4";
		$net_host_message = "($bm{$i} $$lang_vars{direcciones_message})";
		$net_host_message = "($bm{$i} $$lang_vars{entradas_redes_message})" if $i < 64 && $ip_version eq "v6";
		$net_host_message = "" if $ip_version eq "v4" && ( $i == 31 || $i == 32 );
		print "<tr><td>$possible_subnets_message</td><td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<b><form name=\"calculate_form_more\" id=\"calculate_form_more\" method=\"POST\" action=\"$server_proto://$base_uri/ip_calculatered.cgi\" style=\"display:inline\"><input type=\"hidden\" name=\"red\" value=\"$red_orig\"><input type=\"hidden\" name=\"BM\" value=\"$daten{BM}\"><input type=\"hidden\" name=\"ip_version\" value=\"$ip_version\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"hidden\" name=\"more_possible_subnets\" value=\"yes\"><input type=\"hidden\" name=\"BM_l2\" value=\"${BM_l2}\"><input type=\"hidden\" name=\"BM_l2_anz\" value=\"$BM_l2_anz\"><input type=\"hidden\" name=\"BM_l3\" value=\"${BM_l3}\"><input type=\"hidden\" name=\"BM_l3_anz\" value=\"$BM_l3_anz\"><input type=\"hidden\" name=\"BM_l4\" value=\"${BM_l4}\"><input type=\"hidden\" name=\"BM_l4_anz\" value=\"$BM_l4_anz\"><input type=\"hidden\" name=\"BM_l5\" value=\"${BM_l5}\"><input type=\"hidden\" name=\"BM_l5_anz\" value=\"$BM_l5_anz\"><input type=\"hidden\" name=\"BM_l6\" value=\"${BM_l6}\"><input type=\"hidden\" name=\"BM_l6_anz\" value=\"$BM_l6_anz\"><input type=\"hidden\" name=\"BM_l7\" value=\"${BM_l7}\"><input type=\"hidden\" name=\"BM_l7_anz\" value=\"$BM_l7_anz\"><input type=\"hidden\" name=\"BM_l8\" value=\"${i}\"><input type=\"hidden\" name=\"BM_l8_anz\" value=\"$bm{$test}\"><input type=\"hidden\" name=\"first_ip_last_red_l2\" value=\"$first_ip_last_red_l2\"><input type=\"hidden\" name=\"first_ip_last_red_l3\" value=\"$first_ip_last_red_l3\"><input type=\"hidden\" name=\"first_ip_last_red_l4\" value=\"$first_ip_last_red_l4\"><input type=\"hidden\" name=\"first_ip_last_red_l5\" value=\"$first_ip_last_red_l5\"><input type=\"hidden\" name=\"first_ip_last_red_l6\" value=\"$first_ip_last_red_l6\"><input type=\"hidden\" name=\"first_ip_last_red_l7\" value=\"$first_ip_last_red_l7\"><span id=\"selected_index${k}\"></span><input type=\"submit\" value=\"$bm{$test} networks /${i}\" name=\"B2\" class=\"input_link_w_net\" onclick=\"create_hidden_selected_index();saveScrollCoordinates();\"></form></b> $net_host_message</td></tr>\n";
		$possible_subnets_message="";
		$test--;
		$k++;
#		last if $k == "63";
	}
} elsif ( $BM_l8 ) {

	my $first_ip_last_red_l2=$daten{first_ip_last_red_l2};
	my $first_ip_last_red_l3=$daten{first_ip_last_red_l3};
	my $first_ip_last_red_l4=$daten{first_ip_last_red_l4};
	my $first_ip_last_red_l5=$daten{first_ip_last_red_l5};
	my $first_ip_last_red_l6=$daten{first_ip_last_red_l6};
	my $first_ip_last_red_l7=$daten{first_ip_last_red_l7};
	my $BM_l2_anz=$daten{BM_l2_anz};
	my $BM_l3_anz=$daten{BM_l3_anz};
	my $BM_l4_anz=$daten{BM_l4_anz};
	my $BM_l5_anz=$daten{BM_l5_anz};
	my $BM_l6_anz=$daten{BM_l6_anz};
	my $BM_l7_anz=$daten{BM_l7_anz};
	my $first_ip_last_red=ip_compress_address ($first_ip_last_red_l2, 6) if $ip_version eq "v6";
	$first_ip_last_red_l3=ip_compress_address ($first_ip_last_red_l3, 6) if $ip_version eq "v6";
	$first_ip_last_red_l4=ip_compress_address ($first_ip_last_red_l4, 6) if $ip_version eq "v6";
	$first_ip_last_red_l5=ip_compress_address ($first_ip_last_red_l5, 6) if $ip_version eq "v6";
	$first_ip_last_red_l6=ip_compress_address ($first_ip_last_red_l6, 6) if $ip_version eq "v6";
	$first_ip_last_red_l7=ip_compress_address ($first_ip_last_red_l7, 6) if $ip_version eq "v6";

	my $redob_in_l8 = $red . "/" . $BM_l8;
	my $ipob_red_in_l8 = new Net::IP ($redob_in_l8) or die "Can not create IP object: $!\n";
	my $last_ip_int_l8 = ($ipob_red_in_l8->last_int());
	$last_ip_int_l8 = Math::BigInt->new("$last_ip_int_l8");
	my $redint_l8=($ipob_red_in_l8->intip()) || 0;
	$redint_l8 = Math::BigInt->new("$redint_l8");
	$redint_l8--;
	my $BM_l8_anz=$daten{BM_l8_anz};
	my $BM_l8_value=$last_ip_int_l8-$redint_l8;
	$BM_l8_value = Math::BigInt->new("$BM_l8_value");
	my $first_ip_last_red_int_l8=$last_ip_int - $BM_l8_value + 2;
	my $first_ip_last_red_l8 = $gip->int_to_ip("$client_id","$first_ip_last_red_int_l8","$ip_version");
	$first_ip_last_red_l8=ip_compress_address ($first_ip_last_red_l8, 6) if $ip_version eq "v6";

	print "<tr><td>$$lang_vars{subnet_level_message} I</td><td><b>$BM_l2_anz networks /${BM_l2}</b><br>($red/${BM_l2} - $first_ip_last_red/${BM_l2})</td></tr>\n";
	print "<tr><td>$$lang_vars{subnet_level_message} II</td><td>&nbsp;&nbsp;&nbsp;&nbsp;<b>$BM_l3_anz networks /${BM_l3}</b><br>&nbsp;&nbsp;&nbsp;&nbsp;($red/${BM_l3} - $first_ip_last_red_l3/${BM_l3})</td></tr>\n";
	print "<tr><td>$$lang_vars{subnet_level_message} III</td><td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<b>$BM_l4_anz networks /${BM_l4}</b><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;($red/${BM_l4} - $first_ip_last_red_l4/${BM_l4})</td></tr>\n";
	print "<tr><td>$$lang_vars{subnet_level_message} IV</td><td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<b>$BM_l4_anz networks /${BM_l5}</b><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;($red/${BM_l5} - $first_ip_last_red_l5/${BM_l5})</td></tr>\n";
	print "<tr><td>$$lang_vars{subnet_level_message} V</td><td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<b>$BM_l6_anz networks /${BM_l6}</b><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;($red/${BM_l6} - $first_ip_last_red_l6/${BM_l6})</td></tr>\n";
	print "<tr><td>$$lang_vars{subnet_level_message} VI</td><td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<b>$BM_l7_anz networks /${BM_l7}</b><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;($red/${BM_l7} - $first_ip_last_red_l7/${BM_l7})</td></tr>\n";
	print "<tr><td>$$lang_vars{subnet_level_message} VII</td><td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<b>$BM_l8_anz networks /${BM_l8}</b><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;($red/${BM_l8} - $first_ip_last_red_l8/${BM_l8}) <FORM style=\"display:inline\"><INPUT TYPE=\"BUTTON\" VALUE=\"back\" ONCLICK=\"history.go(-1)\" class=\"error_back_link\"></FORM></td></tr>\n";
	my $start = $BM_l8+1;
	my $net_host_message="";
	$possible_subnets_message .= " VIII";
	for (my $i=$start; $i<=$last; $i++) {
		last if ! defined($bm{$test});
		$bm{$i}-=2 if $ip_version eq "v4";
		$net_host_message = "($bm{$i}  $$lang_vars{direcciones_message})";
		$net_host_message = "($bm{$i} $$lang_vars{entradas_redes_message})" if $i < 64 && $ip_version eq "v6";
		$net_host_message = "" if $ip_version eq "v4" && ( $i == 31 || $i == 32 );
		print "<tr><td>$possible_subnets_message</td><td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<b>$bm{$test} networks /${i}</b></td></tr>\n";
		$possible_subnets_message="";
		$test--;
		$k++;
	}
}
print "</table><p>\n";


print "<span class=\"close_window\" onClick=\"window.close()\" style=\"cursor:pointer;\"> $$lang_vars{close_message} </span>\n";

print <<EOF;

<SCRIPT LANGUAGE="Javascript" TYPE="text/javascript">
<!--
scrollToCoordinates();
//-->
</SCRIPT>

EOF


print "</div>\n";
print "</div>\n";
print "</body>\n";
print "</html>\n";
exit 0;


### subroutines

sub dec2bin {
    my $str = unpack("B32", pack("N", shift));
    $str =~ s/^0+(?=\d)//;   # otherwise you'll get leading zeros
    return $str;
}
sub bin2dec {
    return unpack("N", pack("B32", substr("0" x 32 . shift, -32)));
}
