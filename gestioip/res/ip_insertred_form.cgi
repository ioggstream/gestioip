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
use lib '../modules';
use GestioIP;
use Math::BigInt;

my $daten=<STDIN>;
my $gip = GestioIP -> new();
my %daten=$gip->preparer($daten);

my $server_proto=$gip->get_server_proto();

my $lang = $daten{'lang'} || "";
my ($lang_vars,$vars_file)=$gip->get_lang("","$lang");

my $base_uri = $gip->get_base_uri();

my $client_id = $daten{'client_id'} || $gip->get_first_client_id();
if ( $client_id !~ /^\d{1,4}$/ ) {
        $client_id = 1;
        $gip->CheckInput("$client_id",\%daten,"$$lang_vars{mal_signo_error_message}","$$lang_vars{crear_red_message}","$vars_file");
        $gip->print_error("$client_id","$$lang_vars{formato_malo_message} (1)");
}


my @values_locations=$gip->get_loc("$client_id");
my @values_cat_red=$gip->get_cat_net("$client_id");

my $ip_version_ele=$gip->get_ip_version_ele() || "v4";

my $ip_version="";
if ( $ip_version_ele eq "v4" && ! $ip_version ) {
	$ip_version = "v4";
} elsif ( $ip_version_ele eq "v6" && ! $ip_version ) {
	$ip_version = "v6";
} elsif ( ! $ip_version ) {
	$ip_version = "v4";
}
	

my @global_config = $gip->get_global_config("$client_id");
my $ipv4_only_mode=$global_config[0]->[5] || "yes";

my $rootnet_BM=$daten{rootnet_BM} || "";
my $red_dat=$daten{ip} || "";
my $BM_freerange = "8";
my $ip_freerange;
my $ip_int_freerange="";
my $anz_possible_nets="";
my $anz_hosts_freerange="";

if ( $red_dat ) {
        if ( $ip_version eq "v4" ) {
                $red_dat =~ /^(\d{6,15})\/(\d{1,20})$/;
                $ip_int_freerange = $1;
                $anz_hosts_freerange = $2;
        } else {
		$red_dat =~ /^(\d{6,40})\/(\d{1,40})$/;
                $ip_int_freerange = $1;
                $anz_hosts_freerange = $2;
		$ip_int_freerange = Math::BigInt->new("$ip_int_freerange");
		$anz_hosts_freerange = Math::BigInt->new("$anz_hosts_freerange");
        }
	$ip_freerange = $gip->int_to_ip("$client_id","$ip_int_freerange","$ip_version");
	$BM_freerange = $gip->find_smallest_valid_BM("$client_id","$ip_freerange","$ip_version");
	if ( $rootnet_BM ) {
		$BM_freerange = $rootnet_BM if $BM_freerange < $rootnet_BM;
	}
}


$gip->print_init("$$lang_vars{crear_red_message}","$$lang_vars{crear_red_message}","$$lang_vars{crear_red_message}","$vars_file","$client_id","$ip_version","$BM_freerange");


$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (2)") if $ip_version_ele !~ /^(v4|v6|46)$/;
if ( scalar(@values_locations) <= 1 ) {
	$gip->print_error("$client_id","$$lang_vars{no_loc_message}<p><form name=\"admin\" method=\"POST\" action=\"$server_proto://$base_uri/res/ip_admin.cgi\" style=\"display:inline\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"submit\" class=\"input_link_w\" value=\"$$lang_vars{define_site_message}\" name=\"B1\"></form>");
}

if ( $red_dat ) {
	if ( $ip_version eq "v4" ) {
		$gip->print_error("$client_id","$$lang_vars{formato_malo_message}: $red_dat (3)") if $red_dat !~ /^\d{6,15}\/\d{1,20}$/;
	} else {
		$gip->print_error("$client_id","$$lang_vars{formato_malo_message}: $red_dat (4)") if $red_dat !~ /^\d{6,40}\/\d{1,40}$/;
	}
}

$gip->print_error("$client_id","$$lang_vars{formato_malo_message} (5)") if $ip_version !~ /(v4|v6)/ && $red_dat;

if ( ! $values_locations[0] ) {
	my $client_name=$gip->get_client_from_id("$client_id");
        $gip->print_error("$client_id","$$lang_vars{no_location_defined_message} <i>$client_name</i> <br><p><form name=\"search_red\" method=\"POST\" action=\"$server_proto://$base_uri/res/ip_admin.cgi\" style=\"display:inline\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><input type=\"submit\" class=\"input_link_w_net\" value=\"$$lang_vars{loc_cat_message}\" name=\"B1\"></form>");
}


my %anz_hosts_bm = $gip->get_anz_hosts_bm_hash("$client_id","$ip_version");

my %possible_nets;


if ( $red_dat && $ip_version eq "v6" ) {
	my $anz_host_freerange_part = "";
	foreach my $key (sort {$a <=> $b} keys %anz_hosts_bm ) {
		my $anz_host_freerange_key="";
		$anz_host_freerange_key = $anz_hosts_bm{$key};
		$anz_host_freerange_key =~ s/,//g;
		$anz_host_freerange_key *= 18446744073709551616 if $key < 64;
		$anz_host_freerange_key = Math::BigInt->new("$anz_host_freerange_key");	

		if ( $anz_hosts_freerange < $anz_host_freerange_key ) {
			$anz_host_freerange_part = $anz_host_freerange_key;
			$anz_host_freerange_part = Math::BigInt->new("$anz_host_freerange_part");
			if ( $BM_freerange < $key ) {
				$BM_freerange = $key;
				$BM_freerange++;
			}
			$anz_possible_nets=$anz_hosts_freerange / $anz_host_freerange_part;
			$anz_possible_nets = Math::BigInt->new("$anz_possible_nets");
			$anz_possible_nets++;
		}
		$possible_nets{$key} = $anz_hosts_freerange / $anz_host_freerange_key;
		$possible_nets{$key}=int($possible_nets{$key} + 0.5);
	}
} elsif ( $red_dat ) {
        my $anz_host_freerange_part;
        foreach my $key (sort {$a <=> $b} keys %anz_hosts_bm ) {
                my $anz_host_freerange_key = $anz_hosts_bm{$key};
                if ( $anz_hosts_freerange <= $anz_host_freerange_key ) {
                        $anz_host_freerange_part = $anz_host_freerange_key;
                        $BM_freerange = $key if $BM_freerange < $key;
                        $anz_possible_nets=$anz_hosts_freerange / $anz_host_freerange_part;
                        $anz_possible_nets++;
                }
                $possible_nets{$key} = $anz_hosts_freerange / $anz_host_freerange_key;
		$possible_nets{$key} = 0 if $possible_nets{$key} =~ /e-/;
                $possible_nets{$key} =~ s/\..*//;
        }
}


print <<EOF;

<script type="text/javascript">
<!--
function checkRefresh(version,BM_freerange) {
 if (version == 'v4') {
  var bm_index=document.insertred_form.BM.options[1].value
  document.forms.insertred_form.ip_version[0].checked=true
  document.forms.insertred_form.red.size='15';
  document.forms.insertred_same_bm_form.ip_version[0].checked=true
  document.forms.insertred_same_bm_form.red.size='15';
  document.forms.insertred_different_bm_form.ip_version[0].checked=true
  document.forms.insertred_different_bm_form.red.size='15';
  document.getElementById('example_network_message').innerHTML = '<i>$$lang_vars{example_network_message}</i>';
  document.getElementById('example_network_message_same_bm').innerHTML = '<i>$$lang_vars{example_network_message}</i>';
  document.getElementById('example_network_message_different_bm').innerHTML = '<i>$$lang_vars{example_network_message}</i>';
  document.getElementById('bitmasks_format_message').innerHTML = '<i>$$lang_vars{bitmasks_format_message}</i>';
  if ( BM_freerange ) {
  } else if ( bm_index == "8" ) {
     document.forms.insertred_form.BM.options[19].selected=true
     document.forms.insertred_same_bm_form.BM.options[19].selected=true
  } else {
     document.forms.insertred_form.BM.options[2].selected=true
     document.forms.insertred_same_bm_form.BM.options[1].selected=true
  }
 } else {
  var bm_index=document.insertred_form.BM.options[1].value
  document.forms.insertred_form.ip_version[1].checked=true
  document.forms.insertred_form.red.size='40';
  document.forms.insertred_same_bm_form.ip_version[1].checked=true
  document.forms.insertred_same_bm_form.red.size='40';
  document.forms.insertred_different_bm_form.ip_version[1].checked=true
  document.forms.insertred_different_bm_form.red.size='40';
  document.getElementById('example_network_message').innerHTML = '<i>$$lang_vars{example_network_v6_message}</i>';
  document.getElementById('example_network_message_same_bm').innerHTML = '<i>$$lang_vars{example_network_v6_message}</i>';
  document.getElementById('example_network_message_different_bm').innerHTML = '<i>$$lang_vars{example_network_v6_message}</i>';
  document.getElementById('bitmasks_format_message').innerHTML = '<i>$$lang_vars{bitmasks_ipv6_format_message}</i>';
  if ( BM_freerange ) {
  } elsif ( bm_index == "64" ) {
     document.forms.insertred_form.BM.options[0].selected=true
     document.forms.insertred_same_bm_form.BM.options[0].selected=true
  } else {
     document.forms.insertred_form.BM.options[56].selected=true
     document.forms.insertred_same_bm_form.BM.options[56].selected=true
  }
 }
}
-->
</script>

<script language="JavaScript" type="text/javascript" charset="utf-8">
<!--
function calculate_red()
{
var IP=document.insertred_form.red.value;
var BM=document.insertred_form.BM.value;
var IP_VERSION="$ip_version";
var opciones="toolbar=no,scrollbars=1,right=100,top=100,width=475,height=550,resizable", i=0;
var URL="$server_proto://$base_uri/ip_calculatered.cgi?ip=" + IP + "&BM=" + BM + "&ip_version=" + IP_VERSION; 
host_info=window.open(URL,"",opciones);
}
-->
</script>

EOF


if ( $ipv4_only_mode eq "no" ) {

print <<EOF;

<script language="JavaScript" type="text/javascript" charset="utf-8">
<!--
function change_BM_select(version,network_message){
   var values_v4=new Array("CLASS A","255.0.0.0 - 16.777.214 hosts","255.128.0.0 - 8.388.606 hosts","255.192.0.0 - 4.194.302 hosts","255.224.0.0 - 2.097.150 hosts","255.240.0.0 - 1.048.574 hosts","255.248.0.0 - 524.286 hosts","255.252.0.0 - 262.142 hosts","255.254.0.0 - 131.070 hosts","CLASS B","255.255.0.0 - 65.534 hosts","255.255.128.0 - 32766 hosts","255.255.192.0 - 16.382 hosts","255.255.224.0 - 8.190 hosts","255.255.240.0 - 4.094 hosts","255.255.248.0 - 2.046 hosts","255.255.252.0 - 1.022 hosts","255.255.254.0 - 510 hosts","CLASS C","255.255.255.0 - 254 hosts","255.255.255.128 - 126 hosts","255.255.255.192 - 62 hosts","255.255.255.224 - 30 hosts","255.255.255.240 - 14 hosts","255.255.255.248 - 6 hosts","255.255.255.252 - 2 hosts","255.255.255.254 - 0 hosts","255.255.255.255 - 0 hosts")
    if (version == 'v4') {
       document.insertred_form.red.size='15'
       document.insertred_form.red.maxLength='40'
       document.insertred_form.ip_version[0].checked=true
       document.insertred_same_bm_form.red.size='15'
       document.insertred_same_bm_form.red.maxLength='40';
       document.insertred_same_bm_form.ip_version[0].checked=true
       document.insertred_different_bm_form.red.size='15'
       document.insertred_different_bm_form.red.maxLength='40';
       document.insertred_different_bm_form.ip_version[0].checked=true
       num_values = 28
       document.insertred_form.BM.length = num_values
       document.insertred_same_bm_form.BM.length = num_values
       j=8
       for(i=0;i<28;i++){
          if ( i == '0' )
          {
             document.insertred_form.BM.options[i].text=values_v4[i]
             document.insertred_form.BM.options[i].disabled=true
             document.insertred_same_bm_form.BM.options[i].text=values_v4[i]
             document.insertred_same_bm_form.BM.options[i].disabled=true


          }
          else if ( i == '9' )
                   { 
             document.insertred_form.BM.options[i].text=values_v4[i]
             document.insertred_form.BM.options[i].disabled=true
             document.insertred_same_bm_form.BM.options[i].text=values_v4[i]
             document.insertred_same_bm_form.BM.options[i].disabled=true
                   } 
          else if ( i == '18' )
                   {
             document.insertred_form.BM.options[i].text=values_v4[i]
             document.insertred_form.BM.options[i].disabled=true
             document.insertred_same_bm_form.BM.options[i].text=values_v4[i]
             document.insertred_same_bm_form.BM.options[i].disabled=true
                   } 
          else {
            document.insertred_form.BM.options[i].text=j + ' (' + values_v4[i] + ')'
            document.insertred_form.BM.options[i].value=j
            document.insertred_form.BM.options[i].disabled=false
            document.insertred_same_bm_form.BM.options[i].text=j + ' (' + values_v4[i] + ')'
            document.insertred_same_bm_form.BM.options[i].value=j
            document.insertred_same_bm_form.BM.options[i].disabled=false
	    j++
          }
          if ( i == '19' ) { 
             document.insertred_form.BM.options[i].selected = true
             document.insertred_same_bm_form.BM.options[i].selected = true
          }
       }
	document.getElementById('example_network_message').innerHTML = '<i>$$lang_vars{example_network_message}</i>';
	document.getElementById('example_network_message_same_bm').innerHTML = '<i>$$lang_vars{example_network_message}</i>';
	document.getElementById('example_network_message_different_bm').innerHTML = '<i>$$lang_vars{example_network_message}</i>';
        document.getElementById('bitmasks_format_message').innerHTML = '<i>$$lang_vars{bitmasks_format_message}</i>';
        document.getElementById('calculate_one_link').innerHTML = '';
        document.getElementById('calculate_multi_link').innerHTML = '';
        document.getElementById('calculate_dif_link').innerHTML = '';
    }else{
       document.insertred_form.red.size='40'
       document.insertred_form.red.maxLength='40'
       document.insertred_form.ip_version[1].checked=true
       document.insertred_same_bm_form.red.size='40'
       document.insertred_same_bm_form.red.maxLength='40';
       document.insertred_same_bm_form.ip_version[1].checked=true
       document.insertred_different_bm_form.red.size='40'
       document.insertred_different_bm_form.red.maxLength='40';
       document.insertred_different_bm_form.ip_version[1].checked=true
       var values_v6=new Array("1 (9,223,372,036,854,775,808 " + network_message + ")","2 (4,611,686,018,427,387,904 " + network_message + ")","3 (2,305,843,009,213,693,952 " + network_message + ")","4 (1,152,921,504,606,846,976 " + network_message + ")","5 (576,460,752,303,423,488 " + network_message + ")","6 (288,230,376,151,711,744 " + network_message + ")","7 (144,115,188,075,855,872 " + network_message + ")","8 (72,057,594,037,927,936 " + network_message + ")","9 (36,028,797,018,963,968 " + network_message + ")","10 (18,014,398,509,481,984 " + network_message + ")","11 (9,007,199,254,740,992 " + network_message + ")","12 (4,503,599,627,370,496 " + network_message + ")","13 (2,251,799,813,685,248 " + network_message + ")","14 (1,125,899,906,842,624 " + network_message + ")","15 (562,949,953,421,312 " + network_message + ")","16 (281,474,976,710,656 " + network_message + ")","17 (140,737,488,355,328 " + network_message + ")","18 (70,368,744,177,664 " + network_message + ")","19 (35,184,372,088,832 " + network_message + ")","20 (17,592,186,044,416 " + network_message + ")","21 (8,796,093,022,208 " + network_message + ")","22 (4,398,046,511,104 " + network_message + ")","23 (2,199,023,255,552 " + network_message + ")","24 (1,099,511,627,776 " + network_message + ")","25 (549,755,813,888 " + network_message + ")","26 (274,877,906,944 " + network_message + ")","27 (137,438,953,472 " + network_message + ")","28 (68,719,476,736 " + network_message + ")","29 (34,359,738,36 " + network_message + ")","30 (17,179,869,184 " + network_message + ")","31 (8,589,934,592 " + network_message + ")","32 (4,294,967,296 " + network_message + ")","33 (2,147,483,648 " + network_message + ")","34 (1,073,741,824 " + network_message + ")","35 (536,870,912 " + network_message + ")","36 (268,435,456 " + network_message + ")","37 (134,217,728 " + network_message + ")","38 (67,108,864 " + network_message + ")","39 (33,554,432 " + network_message + ")","40 (16,777,216 " + network_message + ")","41 (8,388,608 " + network_message + ")","42 (4,194,304 " + network_message + ")","43 (2,097,152 " + network_message + ")","44 (1,048,576 " + network_message + ")","45 (524,288 " + network_message + ")","46 (262,144 " + network_message + ")","47 (131,072 " + network_message + ")","48 (65,536 " + network_message + ")","49 (32,768 " + network_message + ")","50 (16,384 " + network_message + ")","51 (8,192 " + network_message + ")","52 (4,096 " + network_message + ")","53 (2,048 " + network_message + ")","54 (1,024 " + network_message + ")","55 (512 " + network_message + ")","56 (256 " + network_message + ")","57 (128 " + network_message + ")","58 (64 " + network_message + ")","59 (32 " + network_message + ")","60 (16 " + network_message + ")","61 (8 " + network_message + ")","62 (4 " + network_message + ")","63 (2 " + network_message + ")","64 (18,446,744,073,709,551,616 hosts)","65 (9,223,372,036,854,775,808 hosts)","66 (4,611,686,018,427,387,904 hosts)","67 (2,305,843,009,213,693,952 hosts)","68 (1,152,921,504,606,846,976 hosts)","69 (576,460,752,303,423,488 hosts)","70 (288,230,376,151,711,744 hosts)","71 (144,115,188,075,855,872 hosts)","72 (72,057,594,037,927,936 hosts)","73 (36,028,797,018,963,968 hosts)","74 (18,014,398,509,481,984 hosts)","75 (9,007,199,254,740,992 hosts)","76 (4,503,599,627,370,496 hosts)","77 (2,251,799,813,685,248 hosts)","78 (1,125,899,906,842,624 hosts)","79 (562,949,953,421,312 hosts)","80 (281,474,976,710,656 hosts)","81 (140,737,488,355,328 hosts)","82 (70,368,744,177,664 hosts)","83 (35,184,372,088,832 hosts)","84 (17,592,186,044,416 hosts)","85 (8,796,093,022,208 hosts)","86 (4,398,046,511,104 hosts)","87 (2,199,023,255,552 hosts)","88 (1,099,511,627,776 hosts)","89 (549,755,813,888 hosts)","90 (274,877,906,944 hosts)","91 (137,438,953,472 hosts)","92 (68,719,476,736 hosts)","93 (34,359,738,36 hosts)","94 (17,179,869,184 hosts)","95 (8,589,934,592 hosts)","96 (4,294,967,296 hosts)","97 (2,147,483,648 hosts)","98 (1,073,741,824 hosts)","99 (536,870,912 hosts)","100 (268,435,456 hosts)","101 (134,217,728 hosts)","102 (67,108,864 hosts)","103 (33,554,432 hosts)","104 (16,777,216 hosts)","105 (8,388,608 hosts)","106 (4,194,304 hosts)","107 (2,097,152 hosts)","108 (1,048,576 hosts)","109 (524,288 hosts)","110 (262,144 hosts)","111 (131,072 hosts)","112 (65,536 hosts)","113 (32,768 hosts)","114 (16,384 hosts)","115 (8,192 hosts)","116 (4,096 hosts)","117 (2,048 hosts)","118 (1,024 hosts)","119 (512 hosts)","120 (256 hosts)","121 (128 hosts)","122 (64 hosts)","123 (32 hosts)","124 (16 hosts)","125 (8 hosts)","126 (4 hosts)","127 (2 hosts)", "128 (1 host)")
       num_values = '130'
       document.insertred_form.BM.length = num_values
       document.forms.insertred_same_bm_form.BM.length = num_values
       j=1
       for(i=0;i<128;i++){
          document.insertred_form.BM.options[i].value=j
          document.insertred_form.BM.options[i].text=values_v6[i]
          document.insertred_form.BM.options[63].selected = true
          document.insertred_form.BM.options[i].disabled=false
          document.insertred_same_bm_form.BM.options[i].value=j
          document.insertred_same_bm_form.BM.options[i].text=values_v6[i]
          document.insertred_same_bm_form.BM.options[63].selected = true
          document.insertred_same_bm_form.BM.options[i].disabled=false
          j++
       }
	document.getElementById('example_network_message').innerHTML = '<i>$$lang_vars{example_network_v6_message}</i>';
	document.getElementById('example_network_message_same_bm').innerHTML = '<i>$$lang_vars{example_network_v6_message}</i>';
	document.getElementById('example_network_message_different_bm').innerHTML = '<i>$$lang_vars{example_network_v6_message}</i>';
        document.getElementById('bitmasks_format_message').innerHTML = '<i>$$lang_vars{bitmasks_ipv6_format_message}</i>';
        document.getElementById('calculate_one_link').innerHTML = '';
        document.getElementById('calculate_multi_link').innerHTML = '';
        document.getElementById('calculate_dif_link').innerHTML = '';
    }
}
-->
</script>

EOF

}


print <<EOF;

<script type="text/javascript">
<!--
function check_vigi_checkbox() {
	if ( document.insertred_form.rootnet.checked == true ) {
		document.insertred_form.vigilada.checked=false;
		document.insertred_form.vigilada.disabled=true;
		document.getElementById('mark_sync').innerHTML='<font color="gray">$$lang_vars{mark_sync_message}<font>';
	}else{
		document.insertred_form.vigilada.disabled=false;
		document.getElementById('mark_sync').innerHTML='$$lang_vars{mark_sync_message}';
	}
}
-->
</script>

EOF

my $align="align=\"right\"";
my $align1="";
my $ori="left";
if ( $vars_file =~ /vars_he$/ ) {
	$align="align=\"left\"";
	$align1="align=\"right\"";
	$ori="right";
}

print "<p>\n";
print "<b style=\"float: $ori\">$$lang_vars{create_one_network_message}</b>\n";
print "<form name=\"insertred_form\" method=\"POST\" action=\"$server_proto://$base_uri/res/ip_insertred.cgi\"><br>\n";
print "<table border=\"0\" cellpadding=\"5\" cellspacing=\"2\">\n";

if ( $ipv4_only_mode eq "no" ) {
	if ( $red_dat ) {
		if ( $ip_version eq "v4" ) {
print <<EOF;
			<tr><td></td><td $align1>IPv4<input type="radio" name="ip_version" value="v4" onchange="change_BM_select('v4','$$lang_vars{entradas_redes_message}');" checked> IPv6<input type="radio" name="ip_version" value="v6" onchange="change_BM_select('v6',$$lang_vars{entradas_redes_message});" disabled><font color=\"white\">x</font></td></tr>\n
EOF
		} else {
print <<EOF;
			<tr><td></td><td $align1>IPv4<input type="radio" name="ip_version" value="v4" onchange="change_BM_select('v4','$$lang_vars{entradas_redes_message}');" disabled> IPv6<input type="radio" name="ip_version" value="v6" onchange="change_BM_select('v6',$$lang_vars{entradas_redes_message});" checked><font color=\"white\">x</font></td></tr>\n
EOF
			}
	} else {
		if ( $ip_version eq "v4" ) {
print <<EOF;
			<tr><td></td><td $align1>IPv4<input type="radio" name="ip_version" value="v4" onchange="change_BM_select('v4','$$lang_vars{entradas_redes_message}');" checked> IPv6<input type="radio" name="ip_version" value="v6" onchange="change_BM_select('v6','$$lang_vars{entradas_redes_message}');"><font color=\"white\">x</font></td></tr>\n
EOF
		} else {
print <<EOF;
			<tr><td></td><td $align1>IPv4<input type="radio" name="ip_version" value="v4" onchange="change_BM_select('v4','$$lang_vars{entradas_redes_message}');"> IPv6<input type="radio" name="ip_version" value="v6" onchange="change_BM_select('v6','$$lang_vars{entradas_redes_message}');" checked><font color=\"white\">x</font></td></tr>\n
EOF
		}
	}
}

if ( $red_dat ) {
	if ( $ip_version eq "v4" ) {
		print "<tr><td $align>$$lang_vars{redes_message}</td><td $align1><input name=\"red\" id=\"red\" type=\"text\" size=\"15\" maxlength=\"40\" value=\"$ip_freerange\"> <span id=\"example_network_message\"><i>$$lang_vars{example_network_message}</i></span></td></tr>\n";
	} else {
		print "<tr><td $align>$$lang_vars{redes_message}</td><td $align1><input name=\"red\" id=\"red\" type=\"text\" size=\"40\" maxlength=\"40\" value=\"$ip_freerange\"> <span id=\"example_network_message\"><i>$$lang_vars{example_network_v6_message}</i></span></td></tr>\n";
	}
} else {
	if ( $ip_version eq "v4" ) {
		print "<tr><td $align>$$lang_vars{redes_message}</td><td $align1><input name=\"red\" id=\"red\" type=\"text\" size=\"15\" maxlength=\"40\"> <span id=\"example_network_message\"> <span id=\"example_network_message\"><i>$$lang_vars{example_network_message}</i></span></td></tr>\n";
	} else {
		print "<tr><td $align>$$lang_vars{redes_message}</td><td $align1><input name=\"red\" id=\"red\" type=\"text\" size=\"40\" maxlength=\"40\"> <span id=\"example_network_message\"> <span id=\"example_network_message\"><i>$$lang_vars{example_network_v6_message}</i></span></td></tr>\n";
	}
}

print "<tr><td $align>$$lang_vars{BM_message}</td><td $align1><select name=\"BM\" id=\"BM\" size=\"1\">\n";
my $bm_i_message;
if ( $ip_version eq "v4" ) {
	for (my $i = 8; $i <= 32; $i++) {
#		next if $i == 31;
		print "<option disabled>CLASS A</option>" if $i == "8" && $i >= $BM_freerange;
		print "<option disabled>CLASS B</option>" if $i == "16" && $i >= $BM_freerange;
		print "<option disabled>CLASS C</option>" if $i == "24";

		if ( $i =~ /^\d$/ ) {
			$bm_i_message = "bm_0" . $i . "_message";
		} else {
			$bm_i_message = "bm_" . $i . "_message";
		}
		if ( ! $red_dat ) {
			if ( $i eq "24") {
				print "<option value=\"$i\" selected><b>$i</b> ($$lang_vars{$bm_i_message})</option>";
			} else {
				print "<option value=\"$i\">$i ($$lang_vars{$bm_i_message})</option>";
			}
		} else {
			if ( $i == $BM_freerange ) {
				print "<option selected><b>$i</b> ($$lang_vars{$bm_i_message})</option>";
			} elsif ( $i == "$BM_freerange" && $BM_freerange > "24") {
				print "<option selected><b>$i</b> ($$lang_vars{$bm_i_message})</option>";
			} else {
				print "<option>$i ($$lang_vars{$bm_i_message})</option>";
			}
		}
	}
} else {
	for (my $i = 1; $i <= 128; $i++) {
		next if $i < 8;
		my $host_red_noti = "hosts";
		$host_red_noti = "$$lang_vars{'entradas_redes_message'}" if $i < 64;
		my $anz_host_loop_message="";
		$anz_host_loop_message="($anz_hosts_bm{$i} $host_red_noti)";
		if ( ! $red_dat ) {
			if ( $i eq "64") {
				print "<option value=\"$i\" selected><b>$i</b> $anz_host_loop_message</option>";
			} else {
				print "<option value=\"$i\">$i $anz_host_loop_message</option>";
			}
		} else {
			if ( $i == $BM_freerange ) {
				print "<option selected><b>$i</b> $anz_host_loop_message</option>";
			} elsif ( $i eq "$BM_freerange" && $BM_freerange > "120") {
				print "<option selected><b>$i</b> $anz_host_loop_message</option>";
			} else {
				print "<option>$i $anz_host_loop_message</option>";
			}
		}
	}
}
print "</select></td></tr>\n";
print "<tr><td $align>$$lang_vars{description_message}</td><td $align1><input name=\"descr\" type=\"text\"  size=\"30\" maxlength=\"100\"></td></tr>\n";
print "<tr><td $align>$$lang_vars{comentario_message}</td><td $align1><input name=\"comentario\" type=\"text\"  size=\"30\" maxlength=\"500\"></td></tr>\n";
my $j=0;
print "<tr><td $align>$$lang_vars{loc_message}</td><td $align1><select name=\"loc\" size=\"1\">";
print "<option></option>";
foreach (@values_locations) {
	print "<option>$values_locations[$j]->[0]</option>" if ( $values_locations[$j]->[0] ne "NULL" );
	$j++;
}
print "</select></td></tr>\n";


print "<tr><td $align>$$lang_vars{cat_message}</td><td $align1><select name=\"cat_red\" size=\"1\">";
print "<option></option>";
$j=0;
foreach (@values_cat_red) {
        print "<option>$values_cat_red[$j]->[0]</option>" if ( $values_cat_red[$j]->[0] ne "NULL" );
        $j++;
}
print "</select><p></td></tr>\n";

print "<tr><td $align>$$lang_vars{rootnet_message}</td><td $align1><input type=\"checkbox\" name=\"rootnet\" id=\"rootnet\" value=\"y\" onClick=\"check_vigi_checkbox();\"><br></td></tr>\n ";
print "<tr><td $align><span id=\"mark_sync\">$$lang_vars{mark_sync_message}</span></td><td $align1><input type=\"checkbox\" name=\"vigilada\" id=\"vigilada\" value=\"y\"><input type=\"hidden\" name=\"add_type\" value=\"single\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><br></td></tr>\n ";

print "</table>\n";

print "<table border=\"0\" cellpadding=\"1\">\n";

$gip->print_custom_net_colums_form("$client_id","$vars_file","");


print "<tr><td $align><p><br><input type=\"submit\" value=\"$$lang_vars{create_message}\" name=\"B2\" class=\"input_link_w\"></td>\n";
print "<td valign=\"middle\" $align1><span id=\"calculate_one_link\"><span class=\"mostrar_link\" onClick=\"calculate_red()\" style=\"cursor:pointer;\" title=\"$$lang_vars{what_would_happen_message}\"><br>&nbsp;&nbsp;$$lang_vars{calcular_message}</span></span></td></tr>\n";
print "</table></form>\n";




print <<EOF;
<script language="JavaScript" type="text/javascript" charset="utf-8">
<!--
function calculate_same_BM(IP_VERSION)
{
var IP=document.insertred_same_bm_form.red.value;
var BM=document.insertred_same_bm_form.BM.value;
var ANZ=document.insertred_same_bm_form.anz_BM.value;
var CLIENT_ID=$client_id;
var opciones="toolbar=no,scrollbars=1,right=100,top=100,width=500,height=300", i=0;
var URL="$server_proto://$base_uri/res/ip_insertred_calculate.cgi?ip=" + IP + "&BM=" + BM + "&anz_BM=" + ANZ + "&client_id=" + CLIENT_ID + "&ip_version=" + IP_VERSION
host_info=window.open(URL,"",opciones);
}
-->
</script>

<script type="text/javascript">
<!--
function check_vigi_checkbox_same_bm() {
	if ( document.insertred_same_bm_form.rootnet.checked == true ) {
		document.insertred_same_bm_form.vigilada.checked=false;
		document.insertred_same_bm_form.vigilada.disabled=true;
		document.getElementById('mark_sync_same_bm').innerHTML='<font color="gray">$$lang_vars{mark_sync_message}<font>';
	}else{
		document.insertred_same_bm_form.vigilada.disabled=false;
		document.getElementById('mark_sync_same_bm').innerHTML='$$lang_vars{mark_sync_message}';
	}
}
-->
</script>

EOF



print "<p><br>\n";
print "<b style=\"float: $ori\">$$lang_vars{create_multiple_network_same_BM_message}</b>\n";
print "<form name=\"insertred_same_bm_form\" method=\"POST\" action=\"$server_proto://$base_uri/res/ip_insertred_check.cgi\"><br>\n";
print "<table border=\"0\" cellpadding=\"5\" cellspacing=\"2\">\n";

if ( $ipv4_only_mode eq "no" ) {
	if ( $red_dat ) {
		if ( $ip_version eq "v4" ) {
print <<EOF;
			<tr><td></td><td $align1>IPv4<input type="radio" name="ip_version" value="v4" onchange="change_BM_select('v4','$$lang_vars{entradas_redes_message}');" checked> IPv6<input type="radio" name="ip_version" value="v6" onchange="change_BM_select('v6','$$lang_vars{entradas_redes_message}');" disabled><font color=\"white\">x</font></td></tr>\n
EOF
		} else {
print <<EOF;
			<tr><td></td><td $align1>IPv4<input type="radio" name="ip_version" value="v4" onchange="change_BM_select('v4','$$lang_vars{entradas_redes_message}');">IPv6<input type="radio" name="ip_version" value="v6" onchange="change_BM_select('v6','$$lang_vars{entradas_redes_message}');" checked><font color=\"white\">x</font></td></tr>\n
EOF
		}
	} else {
		if ( $ip_version eq "v4" ) {
print <<EOF;
			<tr><td></td><td $align1>IPv4<input type="radio" name="ip_version" value="v4" onchange="change_BM_select('v4','$$lang_vars{entradas_redes_message}');" checked> IPv6<input type="radio" name="ip_version" value="v6" onchange="change_BM_select('v6','$$lang_vars{entradas_redes_message}');"><font color=\"white\">x</font></td></tr>\n
EOF
		} else {
print <<EOF;
			<tr><td></td><td $align1>IPv4<input type="radio" name="ip_version" value="v4" onchange="change_BM_select('v4','$$lang_vars{entradas_redes_message}');"> IPv6<input type="radio" name="ip_version" value="v6" onchange="change_BM_select('v6','$$lang_vars{entradas_redes_message}');" checked><font color=\"white\">x</font></td></tr>\n
EOF
		}
	}
}


if ( $red_dat ) {
	if ( $ip_version eq "v4" ) {
		print "<tr><td $align>$$lang_vars{redes_primero_message}</td><td $align1><input name=\"red\" id=\"red\" type=\"text\" size=\"15\" maxlength=\"40\" value=\"$ip_freerange\">  <span id=\"example_network_message_same_bm\"><i>$$lang_vars{example_network_message}</i></span></td></tr>\n";
	} else {
		print "<tr><td $align>$$lang_vars{redes_primero_message}</td><td $align1><input name=\"red\" id=\"red\" type=\"text\" size=\"40\" maxlength=\"40\" value=\"$ip_freerange\"> <span id=\"example_network_message_same_bm\"><i>$$lang_vars{example_network_v6_message}</i></span></td></tr>\n";
	}
} else {
	if ( $ip_version eq "v4" ) {
		print "<tr><td $align>$$lang_vars{redes_message}</td><td $align1><input name=\"red\" id=\"red\" type=\"text\" size=\"15\" maxlength=\"40\"> <span id=\"example_network_message_same_bm\"> <span id=\"example_network_message_same_bm\"><i>$$lang_vars{example_network_message}</i></span></td></tr>\n";
	} else {
		print "<tr><td $align>$$lang_vars{redes_message}</td><td $align1><input name=\"red\" id=\"red\" type=\"text\" size=\"40\" maxlength=\"40\"> <span id=\"example_network_message_same_bm\"> <span id=\"example_network_message_same_bm\"><i>$$lang_vars{example_network_v6_message}</i></span></td></tr>\n";
	}
}


print "<tr><td $align>$$lang_vars{BM_message}</td><td $align1><select name=\"BM\" size=\"1\">\n";
my $max_redes = 50;
if ( $ip_version eq "v4" ) {
	for (my $i = 8; $i < 33; $i++) {
#		next if $i == 31;
		print "<option disabled>CLASS A</option>" if $i == "8" && $i >= $BM_freerange;
		print "<option disabled>CLASS B</option>" if $i == "16" && $i > $BM_freerange;
		print "<option disabled>CLASS C</option>" if $i == "24";
		if ( $i =~ /^\d$/ ) {
			$bm_i_message = "bm_0" . $i . "_message";
		} else {
			$bm_i_message = "bm_" . $i . "_message";
		}
		if ( ! $red_dat ) {
			if ( $i eq "24") {
				print "<option value=\"$i\" selected><b>$i</b> ($$lang_vars{$bm_i_message})</option>";
			} else {
				print "<option value=\"$i\">$i ($$lang_vars{$bm_i_message})</option>";
			}
		} else {
			$max_redes = $possible_nets{$i};
			
			if ( $max_redes < "50" ) {

				if ( $i == $BM_freerange ) {
					if ( $max_redes == "1" ) {
						print "<option value=\"$i\" selected><b>$i</b> ($$lang_vars{$bm_i_message}) - $max_redes $$lang_vars{max_red_message}</option>";
					} else {
						print "<option value=\"$i\" selected><b>$i</b> ($$lang_vars{$bm_i_message}) - $max_redes $$lang_vars{max_redes_message}</option>";
					}
				} elsif ( $i eq "$BM_freerange" && $BM_freerange > "24") {
					if ( $max_redes == "1" ) {
						print "<option value=\"$i\" selected><b>$i</b> ($$lang_vars{$bm_i_message}) - $max_redes $$lang_vars{max_red_message}</option>";
					} else {
						print "<option value=\"$i\" selected><b>$i</b> ($$lang_vars{$bm_i_message}) - $max_redes $$lang_vars{max_redes_message}</option>";
					}
				} else {
					if ( $max_redes == "1" ) {
						print "<option value=\"$i\">$i ($$lang_vars{$bm_i_message}) - $max_redes $$lang_vars{max_red_message}</option>";
					} else {
						print "<option value=\"$i\">$i ($$lang_vars{$bm_i_message}) - $max_redes $$lang_vars{max_redes_message}</option>";
					}
				}
			} else {
				if ( $i == $BM_freerange ) {
					print "<option value=\"$i\" selected><b>$i</b> ($$lang_vars{$bm_i_message})</option>";
				} elsif ( $i eq "$BM_freerange" && $BM_freerange > "24") {
					print "<option value=\"$i\" selected><b>$i</b> ($$lang_vars{$bm_i_message})</option>";
				} else {
					print "<option value=\"$i\">$i ($$lang_vars{$bm_i_message})</option>";
				}
			}
		}
	}
} else {
	for (my $i = 1; $i <= 128; $i++) {
		next if $i < 8;
		if ( ! $red_dat ) {
			if ( $i eq "64") {
				print "<option value=\"$i\" selected><b>$i</b></option>";
			} else {
				print "<option value=\"$i\"><b>$i</b></option>";
			}
		} else {
#			next if $i < 8;
			$max_redes = $possible_nets{$i};
			my $max_redes_loop_message="";
			if ( $max_redes >= 1 ) {
				if ( $max_redes == "1" ) {
					$max_redes_loop_message=" - $max_redes $$lang_vars{max_red_message}";
				} else {
					$max_redes_loop_message=" - $max_redes $$lang_vars{max_redes_message}";
				}
			}
			
			if ( $max_redes < "50" ) {
				if ( $i == $BM_freerange ) {
					print "<option value=\"$i\" selected><b>$i</b> $max_redes_loop_message</option>";
				} elsif ( $i eq "$BM_freerange" && $BM_freerange > "120") {
					print "<option value=\"$i\" selected><b>$i</b> $max_redes_loop_message</option>";
				} else {
					print "<option value=\"$i\">$i $max_redes_loop_message</option>";
				}
			} else {
				if ( $i == $BM_freerange ) {
					print "<option value=\"$i\" selected><b>$i</b> $max_redes_loop_message</option>";
				} elsif ( $i eq "$BM_freerange" && $BM_freerange > "120") {
					print "<option value=\"$i\" selected><b>$i</b> $max_redes_loop_message</option>";
				} else {
					print "<option value=\"$i\">$i $max_redes_loop_message</option>";
				}
			}
		}
	}
}

print "</select></td></tr>\n";
print "<tr><td $align>$$lang_vars{anz_new_networks_message}</td><td $align1><select name=\"anz_BM\" size=\"1\">";
$max_redes = 50 if $max_redes >= 50;
for (my $i = 1; $i <= $max_redes; $i++) {
        print "<option>$i</option>";
}
print "</select></td></tr>\n";
print "<tr><td $align>$$lang_vars{loc_message}</td><td $align1><select name=\"loc\" size=\"1\">";
print "<option></option>";
$j=0;
foreach (@values_locations) {
        print "<option>$values_locations[$j]->[0]</option>" if ( $values_locations[$j]->[0] ne "NULL" );
        $j++;
}
print "</select></td></tr>\n";

print "<tr><td $align>$$lang_vars{cat_message}</td><td $align1><select name=\"cat_red\" size=\"1\">";
print "<option></option>";
$j=0;
foreach (@values_cat_red) {
        print "<option>$values_cat_red[$j]->[0]</option>" if ( $values_cat_red[$j]->[0] ne "NULL" );
        $j++;
}
print "</select><p></td></tr>\n";

print "<tr><td $align>$$lang_vars{rootnets_message}</td><td $align1><input type=\"checkbox\" name=\"rootnet\" value=\"y\" onClick=\"check_vigi_checkbox_same_bm();\"><br></td></tr>\n ";

print "<tr><td $align><span id=\"mark_sync_same_bm\">$$lang_vars{mark_sync_message}</span></td><td $align1><input type=\"checkbox\" name=\"vigilada\" id=\"vigilada\" value=\"y\"><input type=\"hidden\" name=\"add_type\" value=\"multiple_same_bm\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><br></td></tr>\n ";
print "<tr><td $align valign=\"middle\"><p><br><input type=\"submit\" value=\"$$lang_vars{create_message}\" name=\"B2\" class=\"input_link_w\"></td>";
print <<EOF;
<td valign="middle" $align1><span id=\"calculate_multi_link\"><span class="mostrar_link" onClick="calculate_same_BM('$ip_version')" style="cursor:pointer;" title="$$lang_vars{what_would_happen_message}"><br>&nbsp;&nbsp;$$lang_vars{calcular_message}</span></span></td></tr>\n
EOF
print "</table></form>\n";




print <<EOF;
<script language="JavaScript" type="text/javascript" charset="utf-8">
<!--
function calculate_different_BM()
{
var IP=document.insertred_different_bm_form.red.value;
var bitmasks=document.insertred_different_bm_form.bitmasks.value;
var BM_freerange=$BM_freerange;
var CLIENT_ID=$client_id;
var IP_VERSION="$ip_version";
var opciones="toolbar=no,scrollbars=1,right=100,top=100,width=500,height=300", i=0;
var URL="$server_proto://$base_uri/res/ip_insertred_calculate.cgi?ip=" + IP + "&bitmasks=" + bitmasks + "&BM_freerange=" + BM_freerange  + "&client_id=" + CLIENT_ID + "&ip_version=" + IP_VERSION;
host_info=window.open(URL,"",opciones);
}
-->
</script>

<script type="text/javascript">
<!--
function check_vigi_checkbox_different_bm() {
	if ( document.insertred_different_bm_form.rootnet.checked == true ) {
		document.insertred_different_bm_form.vigilada.checked=false;
		document.insertred_different_bm_form.vigilada.disabled=true;
		document.getElementById('mark_sync_different_bm').innerHTML='<font color="gray">$$lang_vars{mark_sync_message}<font>';
	}else{
		document.insertred_different_bm_form.vigilada.disabled=false;
		document.getElementById('mark_sync_different_bm').innerHTML='$$lang_vars{mark_sync_message}';
	}
}
-->
</script>

EOF


print "<p><br>\n";
print "<b style=\"float: $ori\">$$lang_vars{create_multiple_network_differen_BM_message}";
print "</b>\n";
print "<form name=\"insertred_different_bm_form\" method=\"POST\" action=\"$server_proto://$base_uri/res/ip_insertred_check.cgi\"><br>\n";
print "<table border=\"0\" cellpadding=\"5\" cellspacing=\"2\">\n";


if ( $ipv4_only_mode eq "no" ) {
	if ( $red_dat ) {
		if ( $ip_version eq "v4" ) {
print <<EOF;
			<tr><td></td><td $align1>IPv4<input type="radio" name="ip_version" value="v4" onchange="change_BM_select('v4','$$lang_vars{entradas_redes_message}');" checked> IPv6<input type="radio" name="ip_version" value="v6" onchange="change_BM_select('v6','$$lang_vars{entradas_redes_message}');" disabled><font color=\"white\">x</font></td></tr>\n
EOF
		} else {
print <<EOF;
			<tr><td></td><td $align1>IPv4<input type="radio" name="ip_version" value="v4" onchange="change_BM_select('v4','$$lang_vars{entradas_redes_message}');"> IPv6<input type="radio" name="ip_version" value="v6" onchange="change_BM_select('v6','$$lang_vars{entradas_redes_message}');" checked><font color=\"white\">x</font></td></tr>\n
EOF
		}
	} else {
		if ( $ip_version eq "v4" ) {
print <<EOF;
			<tr><td></td><td $align1>IPv4<input type="radio" name="ip_version" value="v4" onchange="change_BM_select('v4','$$lang_vars{entradas_redes_message}');" checked> IPv6<input type="radio" name="ip_version" value="v6" onchange="change_BM_select('v6','$$lang_vars{entradas_redes_message}');"><font color=\"white\">x</font></td></tr>\n
EOF
		} else {
print <<EOF;
			<tr><td></td><td $align1>IPv4<input type="radio" name="ip_version" value="v4" onchange="change_BM_select('v4','$$lang_vars{entradas_redes_message}');"> IPv6<input type="radio" name="ip_version" value="v6" onchange="change_BM_select('v6','$$lang_vars{entradas_redes_message}');" checked><font color=\"white\">x</font></td></tr>\n
EOF
		}
	}
}


if ( $red_dat ) {
	if ( $ip_version eq "v4" ) {
		print "<tr><td $align>$$lang_vars{redes_primero_message}</td><td $align1><input name=\"red\" id=\"red\" type=\"text\" size=\"15\" maxlength=\"40\" value=\"$ip_freerange\">  <span id=\"example_network_message_different_bm\"><i>$$lang_vars{example_network_message}</i></span></td></tr>\n";
	} else {
		print "<tr><td $align>$$lang_vars{redes_primero_message}</td><td $align1><input name=\"red\" id=\"red\" type=\"text\" size=\"40\" maxlength=\"40\" value=\"$ip_freerange\"> <span id=\"example_network_message_different_bm\"><i>$$lang_vars{example_network_v6_message}</i></span></td></tr>\n";
	}
} else {


	if ( $ip_version eq "v4" ) {
		print "<tr><td $align>$$lang_vars{redes_message}</td><td $align1><input name=\"red\" id=\"red\" type=\"text\" size=\"15\" maxlength=\"40\"> <span id=\"example_network_message_different_bm\"> <span id=\"example_network_message_same_bm\"><i>$$lang_vars{example_network_message}</i></span></td></tr>\n";
	} else {
		print "<tr><td $align>$$lang_vars{redes_message}</td><td $align1><input name=\"red\" id=\"red\" type=\"text\" size=\"40\" maxlength=\"40\"> <span id=\"example_network_message_different_bm\"> <span id=\"example_network_message_same_bm\"><i>$$lang_vars{example_network_v6_message}</i></span></td></tr>\n";
	}
}


print "<tr><td $align>$$lang_vars{bitmasks_message}</td><td $align1><input name=\"bitmasks\" type=\"text\" size=\"15\" maxlength=\"200\"> <span id=\"bitmasks_format_message\"> $$lang_vars{bitmasks_format_message}</span></td></tr>\n";
print "<tr><td $align>$$lang_vars{loc_message}</td><td $align1><select name=\"loc\" size=\"1\">";
print "<option></option>";
$j=0;
foreach (@values_locations) {
        print "<option>$values_locations[$j]->[0]</option>" if ( $values_locations[$j]->[0] ne "NULL" );
        $j++;
}
print "</select></td></tr>\n";

print "<tr><td $align>$$lang_vars{cat_message}</td><td $align1><select name=\"cat_red\" size=\"1\">";
print "<option></option>";
$j=0;
foreach (@values_cat_red) {
        print "<option>$values_cat_red[$j]->[0]</option>" if ( $values_cat_red[$j]->[0] ne "NULL" );
        $j++;
}
print "</select><p></td></tr>\n";

print "<tr><td $align>$$lang_vars{rootnets_message}</td><td $align1><input type=\"checkbox\" name=\"rootnet\" value=\"y\" onClick=\"check_vigi_checkbox_different_bm();\"><br></td></tr>\n ";

print "<tr><td $align><span id=\"mark_sync_different_bm\">$$lang_vars{mark_sync_message}</span></td><td $align1><input type=\"checkbox\" name=\"vigilada\" id=\"vigilada\" value=\"y\"><input type=\"hidden\" name=\"add_type\" value=\"multiple_different_bm\"><input type=\"hidden\" name=\"client_id\" value=\"$client_id\"><br></td></tr>\n ";
print "<tr><td $align><p><br><input type=\"submit\" value=\"$$lang_vars{create_message}\" name=\"B2\" class=\"input_link_w\"></form></td>";
print "<td valign=\"middle\" $align1><span id=\"calculate_dif_link\"><span class=\"mostrar_link\" onClick=\"calculate_different_BM()\" style=\"cursor:pointer;\" title=\"$$lang_vars{what_would_happen_message}\"><br>&nbsp;&nbsp;$$lang_vars{calcular_message}</span></span></td></tr>\n";
print "</table>\n";


print "<script type=\"text/javascript\">\n";
 print "document.insertred_form.red.focus();\n";
print "</script>\n";

$gip->print_end("$client_id","$vars_file");
