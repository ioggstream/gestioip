
# alter table "net"
ALTER TABLE net ADD ip_version varchar(2) AFTER categoria;
ALTER TABLE net ADD rootnet smallint(1) DEFAULT '0' AFTER ip_version;
ALTER TABLE net CHANGE red red varchar(40);
ALTER TABLE net CHANGE BM BM varchar(3);

# update table net
UPDATE net SET ip_version='v4';


# alter table "host"
ALTER TABLE host ADD ip_version varchar(2) AFTER range_id;
ALTER TABLE host CHANGE ip ip varchar(40);
ALTER TABLE host ADD INDEX ip (ip);
ALTER TABLE host CHANGE hostname hostname varchar(100);

# update table "host"
UPDATE host SET ip_version='v4';


# alter table "global_config"
ALTER TABLE global_config ADD ipv4_only varchar(3);
ALTER TABLE global_config ADD as_enabled varchar(3);
ALTER TABLE global_config ADD leased_line_enabled varchar(3);

#update table "global_config"
UPDATE global_config set version='3.0';
UPDATE global_config set ipv4_only='yes';
UPDATE global_config set as_enabled='no';
UPDATE global_config set leased_line_enabled='no';


# alter table "config"
ALTER TABLE config ADD smallest_bm6 varchar(3);
ALTER TABLE config ADD ocs_enabled varchar(3) DEFAULT 'no';
ALTER TABLE config ADD ocs_database_user varchar(30);
ALTER TABLE config ADD ocs_database_name varchar(30);
ALTER TABLE config ADD ocs_database_pass varchar(30);
ALTER TABLE config ADD ocs_database_ip varchar(42);
ALTER TABLE config ADD ocs_database_port varchar(30);

#update table "config"
UPDATE config set smallest_bm6='64';
UPDATE config set ocs_enabled='no';
UPDATE config set ocs_database_user='ocs';
UPDATE config set ocs_database_name='ocsweb';
UPDATE config set ocs_database_port='3306';


# alter table "ranges"
ALTER TABLE ranges CHANGE start_ip start_ip varchar(40);
ALTER TABLE ranges CHANGE end_ip end_ip varchar(40);


# update table "event_types"
INSERT INTO event_types (id,event_type) VALUES ('47','all networks deleted');
INSERT INTO event_types (id,event_type) VALUES ('48','AS added');
INSERT INTO event_types (id,event_type) VALUES ('49','AS edited');
INSERT INTO event_types (id,event_type) VALUES ('50','AS deleted');
INSERT INTO event_types (id,event_type) VALUES ('51','AS client added');
INSERT INTO event_types (id,event_type) VALUES ('52','AS client edited');
INSERT INTO event_types (id,event_type) VALUES ('53','AS client deleted');
INSERT INTO event_types (id,event_type) VALUES ('54','line added');
INSERT INTO event_types (id,event_type) VALUES ('55','line edited');
INSERT INTO event_types (id,event_type) VALUES ('56','line deleted');
INSERT INTO event_types (id,event_type) VALUES ('57','line client added');
INSERT INTO event_types (id,event_type) VALUES ('58','line client edited');
INSERT INTO event_types (id,event_type) VALUES ('59','line client deleted');

# update table "update_types_audit"
INSERT INTO update_types_audit (id,update_types_audit) VALUES ('12','vlan sheet');

# update table "event_classes"
INSERT INTO event_classes (id,event_class) VALUES ('11','AS');
INSERT INTO event_classes (id,event_class) VALUES ('12','AS client');
INSERT INTO event_classes (id,event_class) VALUES ('13','line');
INSERT INTO event_classes (id,event_class) VALUES ('14','line client');

# alter table "custom_host_column_entries"
ALTER TABLE custom_host_column_entries CHANGE entry entry varchar(750);

#insert new predefind host columns into "predef_host_columns"
INSERT INTO predef_host_columns (id,name) VALUES ('10','URL');
INSERT INTO predef_host_columns (id,name) VALUES ('11','rack');
INSERT INTO predef_host_columns (id,name) VALUES ('12','RU');
INSERT INTO predef_host_columns (id,name) VALUES ('13','switch');
INSERT INTO predef_host_columns (id,name) VALUES ('14','port');
INSERT INTO predef_host_columns (id,name) VALUES ('15','port');


# alter table "client_entries"
ALTER TABLE client_entries ADD dns_server_1_key_name varchar(50);
ALTER TABLE client_entries ADD dns_server_2_key_name varchar(50);
ALTER TABLE client_entries ADD dns_server_3_key_name varchar(50);
ALTER TABLE client_entries ADD dns_server_1_key varchar(100);
ALTER TABLE client_entries ADD dns_server_2_key varchar(100);
ALTER TABLE client_entries ADD dns_server_3_key varchar(100);


# create table autonomous_systems
CREATE TABLE IF NOT EXISTS autonomous_systems (
   id int(10) AUTO_INCREMENT,
   as_number int(12),
   description varchar(500),
   comment varchar(500),
   as_client_id smallint(4) DEFAULT '-1',
   client_id smallint(4) NOT NULL,
   PRIMARY KEY (id)
);

# create table autonomous_systems_clients
CREATE TABLE IF NOT EXISTS autonomous_systems_clients (
   id int(10) AUTO_INCREMENT,
   client_name varchar(100),
   type varchar(100),
   description varchar(500),
   comment varchar(500),
   phone varchar(30),
   fax varchar(30),
   address varchar(500),
   contact varchar(500),
   contact_email varchar(100),
   contact_phone varchar(30),
   contact_cell varchar(30),
   client_id smallint(4) NOT NULL,
   PRIMARY KEY (id)
);

INSERT INTO autonomous_systems_clients (id,client_name,client_id) VALUES ('-1',"_DEFAULT_","9999");

# create table llines
CREATE TABLE IF NOT EXISTS llines (
   id int(10) AUTO_INCREMENT,
   phone_number varchar(50),
   description varchar(500),
   comment varchar(500),
   loc smallint(3) DEFAULT '-1',
   ll_client_id smallint(4) DEFAULT '-1',
   type varchar(100),
   service varchar(100),
   device varchar(500),
   room varchar(500),
   ad_number varchar(100),
   client_id smallint(4) NOT NULL,
   PRIMARY KEY (id)
);

# create table llines_clients
CREATE TABLE IF NOT EXISTS llines_clients (
   id int(10) AUTO_INCREMENT,
   client_name varchar(100),
   type varchar(100),
   description varchar(500),
   comment varchar(500),
   phone varchar(30),
   fax varchar(30),
   address varchar(500),
   contact varchar(500),
   contact_email varchar(100),
   contact_phone varchar(30),
   contact_cell varchar(30),
   client_id smallint(4) NOT NULL,
   PRIMARY KEY (id)
);

INSERT INTO llines_clients (id,client_name,client_id) VALUES ('-1',"_DEFAULT_","9999");
