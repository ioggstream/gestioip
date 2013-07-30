# this script updates the database of GestioIP v2.2.7 to v2.2.8


#create table clients

CREATE TABLE IF NOT EXISTS clients (
  `id` smallint(4) NOT NULL default '0',
  `client` varchar(50) NOT NULL,
  PRIMARY KEY  (`id`)
);

INSERT IGNORE clients (id,client) VALUES ("1","DEFAULT");


#create table client_entries

CREATE TABLE IF NOT EXISTS client_entries (
  `client_id` smallint(4) NOT NULL,
  `phone` varchar(30),
  `fax` varchar(30),
  `address` varchar(500),
  `comment` varchar(500),
  `contact_name_1` varchar(200),
  `contact_phone_1` varchar(25),
  `contact_cell_1` varchar(25),
  `contact_email_1` varchar(50),
  `contact_comment_1` varchar(500),
  `contact_name_2` varchar(200),
  `contact_phone_2` varchar(25),
  `contact_cell_2` varchar(25),
  `contact_email_2` varchar(50),
  `contact_comment_2` varchar(500),
  `contact_name_3` varchar(200),
  `contact_phone_3` varchar(25),
  `contact_cell_3` varchar(25),
  `contact_email_3` varchar(50),
  `contact_comment_3` varchar(500),
  `default_resolver` varchar(3) default 'yes',
  `dns_server_1` varchar(50) not null,
  `dns_server_2` varchar(50) not null,
  `dns_server_3` varchar(50) not null
);

INSERT IGNORE client_entries (client_id) VALUES ('1');


#create table custom_net_columns

CREATE TABLE IF NOT EXISTS custom_net_columns (
  `id` smallint(4) NOT NULL default '0',
  `name` varchar(40) NOT NULL,
  `column_type_id` tinyint(3) default '-1',
  `client_id` smallint(4) NOT NULL,
  PRIMARY KEY  (`id`)
);


#create table custom_net_column_entries

CREATE TABLE IF NOT EXISTS custom_net_column_entries (
  `cc_id` smallint(4) NOT NULL default '0',
  `net_id` varchar(20) NOT NULL,
  `entry` varchar(150) NOT NULL,
  `client_id` smallint(4) NOT NULL
);


#create table predef_net_columns

CREATE TABLE IF NOT EXISTS predef_net_columns ( `id` smallint(4) NOT NULL default '0', `name` varchar(40) NOT NULL, PRIMARY KEY  (`id`));

INSERT IGNORE predef_net_columns VALUES ("-1","NOTYPE"),("1","vlan");



#create table custom_host_columns

CREATE TABLE IF NOT EXISTS custom_host_columns (
  `id` smallint(4) NOT NULL default '0',
  `name` varchar(40) NOT NULL,
  `column_type_id` tinyint(3) default '-1',
  `client_id` smallint(4) NOT NULL,
  PRIMARY KEY  (`id`)
);


#create table custom_host_column_entries

CREATE TABLE IF NOT EXISTS custom_host_column_entries (
  `cc_id` smallint(4) NOT NULL default '0',
  `pc_id` smallint(4) NOT NULL,
  `host_id` bigint(10) NOT NULL,
  `entry` varchar(150) NOT NULL,
  `client_id` smallint(4) NOT NULL
);


#create table predef_host_columns

CREATE TABLE IF NOT EXISTS predef_host_columns ( `id` smallint(4) NOT NULL default '0', `name` varchar(40) NOT NULL, PRIMARY KEY  (`id`));

INSERT IGNORE predef_host_columns VALUES ("-1","NOTYPE"),("1","vendor"),("2","model"),("3","contact"),("4","serial"),("5","MAC"),("6","OS"),("7","dev_descr"),('8','dev_name'),('9','dev_loc');


#alter table config

ALTER TABLE config ADD confirmation varchar(3) default 'no';

UPDATE config set confirmation="yes" WHERE confirmation="no";


# create table global_config

CREATE TABLE IF NOT EXISTS global_config (
  `version` varchar(10) NOT NULL,
  `default_client_id` varchar(150) NOT NULL,
  `confirmation` varchar(4) NOT NULL,
  `mib_dir` varchar(100),
  `vendor_mib_dirs` varchar(500)
);

INSERT IGNORE global_config VALUES ('2.2.8','1','yes','/usr/share/gestioip/mibs','allied,arista,aruba,asante,cabletron,cisco,cyclades,dell,enterasys,extreme,foundry,hp,juniper,netscreen,net-snmp,nortel,rfc');


# update tables with client_id

ALTER TABLE audit ADD client_id smallint(4);
UPDATE IGNORE audit set client_id = '1';

ALTER TABLE audit_auto ADD client_id smallint(4);
UPDATE IGNORE audit_auto set client_id = '1';

ALTER TABLE config ADD client_id smallint(4);
UPDATE IGNORE config set client_id = '1';

ALTER TABLE host ADD client_id smallint(4);
UPDATE IGNORE host set client_id = '1';

ALTER TABLE locations ADD client_id smallint(4);
UPDATE IGNORE locations set client_id = '1';
UPDATE IGNORE locations set client_id = '9999' WHERE loc='NULL';

ALTER TABLE net ADD client_id smallint(4);
UPDATE IGNORE net set client_id = '1';

ALTER TABLE ranges ADD client_id smallint(4);
UPDATE IGNORE ranges set client_id = '1';


#add new event types

INSERT IGNORE event_types VALUES (31,'net column added'),(32,'net column deleted'),(33,'client added'),(34,'client deleted'),(35,'client edited'),(36,'vlan added'),(37,'vlan deleted'),(38,'vlan edited'),(39,'vlan prov added'),(40,'vlan prov deleted'),(41,'vlan prov edited'),(42,'host column added'),(43,'host column deleted'),(44,'auto synch snmp'),(45,'man ini'),(46,'auto auto ini');

#add new event classes

INSERT IGNORE event_classes VALUES (7,'vlan_man'),(8,'vlan_auto'),(9,'ini_man'),(10,'ini_auto');


#alter table audit

ALTER TABLE audit CHANGE id id int(10);


#alter table audit_auto

ALTER TABLE audit_auto CHANGE id id int(10) AUTO_INCREMENT;


# alter table locations

ALTER TABLE locations DROP index loc;


# create table vlans

CREATE TABLE IF NOT EXISTS vlans (id smallint(5) AUTO_INCREMENT, vlan_num varchar(10), vlan_name varchar(250) default NULL, comment varchar(500) default NULL, provider_id smallint(5), bg_color varchar(20), font_color varchar(20), switches varchar(10000), asso_vlan smallint(5), client_id smallint(4), PRIMARY KEY (id));


# create table vlan_providors

CREATE TABLE IF NOT EXISTS vlan_providers (id smallint (4), name varchar(100) default NULL, comment varchar(500), client_id smallint(4));


INSERT INTO vlan_providers (id,name,comment,client_id) VALUES ("-1","","","9999");


# alter table host

ALTER TABLE host change ip ip bigint(12) NULL;
ALTER TABLE host DROP primary key;
ALTER TABLE host ADD id int(10) PRIMARY KEY AUTO_INCREMENT NOT NULL FIRST;


# alter table net

ALTER TABLE net change red_num red_num smallint(5);


# alter table ranges

ALTER TABLE ranges CHANGE id id smallint(5);
