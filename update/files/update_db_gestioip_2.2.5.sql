#this script updates the database of GestioIP 2.2.5 to 2.2.6

# Delete reserved ranges (ranges of v2.2.5 are incompatible with v2.2.6)

delete from host where host_descr = 'reserved';
delete from host where hostname = '';
delete from host where hostname = 'NULL';
update net set comentario = '' where comentario REGEXP '[[.[.]][0-9}{1,3}\.[0-9}{1,3}\.[0-9}{1,3}\.[0-9}{1,3} (.+)[[.].]]';


# cambiar table "host"

alter table host add alive tinyint(1) default '-1';
alter table host add last_response bigint(20);
alter table host add lastupdate bigint(20) after last_update;
update host set lastupdate=UNIX_TIMESTAMP(last_update);
alter table host drop last_update;
alter table host change lastupdate last_update bigint(20);
alter table host add range_id smallint(3) default '-1';
alter table host change hostname hostname varchar(50) default 'NULL';


#create table for auto audit events

CREATE TABLE IF NOT EXISTS audit_auto (
  `id` smallint(6) not NULL,
  `event` varchar(500) not NULL,
  `user` varchar(50) default NULL,
  `event_class` smallint(3) default NULL,
  `event_type` smallint(4) default NULL,
  `update_type_audit` smallint(3) default NULL,
  `date` bigint(20) not NULL,
  PRIMARY KEY  (`id`)
);


#add new event types

INSERT IGNORE event_types VALUES (20,'loc renamed'),(21,'cat host renamed'),(22,'cat net renamed'),(23,'auto synch dns'),(24,'auto synch ocs'),(25,'config edited'),(26,'auto audit deleted'),(27,'man audit deleted');


#add new audit update types
update update_types_audit set update_types_audit = "auto" where update_types_audit = "sh";
update update_types_audit set update_types_audit='auto dns' where update_types_audit='auto' AND id='4';
update update_types_audit set update_types_audit="auto snmp" where update_types_audit='SNMP';
insert ignore update_types_audit (id,update_types_audit) values (5,'auto ocs');
insert ignore update_types_audit (id,update_types_audit) values (6,'man dns');
insert ignore update_types_audit (id,update_types_audit) values (7,'man snmp');
insert ignore update_types_audit (id,update_types_audit) values (8,'man sheet');
insert ignore update_types_audit (id,update_types_audit) values (9,'man range');

## add new event classes

INSERT IGNORE event_classes VALUES (6,'conf');

#create table ranges (ranges are now managed with an own table)

CREATE TABLE ranges (
  `id` smallint(4) NOT NULL default '0',
  `start_ip` varchar(15) NOT NULL default '0',
  `end_ip` varchar(15) NOT NULL default '0',
  `comentario` varchar(45) default NULL,
  `range_type` varchar(2) default '-1',
  `red_num` varchar(45) default NULL,
  PRIMARY KEY  (`id`)
);


#create table range_type

CREATE TABLE range_type (
  `id` smallint(4) NOT NULL default '0',
  `range_type` varchar(15) NOT NULL default '0',
  PRIMARY KEY  (`id`)
);

INSERT IGNORE range_type (id,range_type) VALUES ('1','workst (DHCP)'),('2','wifi (DHCP)'),('3','VoIP (DHCP)'),('4','other (DHCP)'),('5','other');


#create table config

CREATE TABLE IF NOT EXISTS config (
   `smallest_bm` smallint(2),
   `max_sinc_procs` smallint(3),
   `ignorar` varchar(250) default NULL,
   `ignore_generic_auto` varchar(3),
   `generic_dyn_host_name` varchar(250) default NULL,
   `set_sync_flag` varchar(3)
);

INSERT IGNORE config (smallest_bm,max_sinc_procs,ignore_generic_auto,set_sync_flag) VALUES ('22','254','yes','no');


# update table "categorias" with new categories

update categorias set cat='server' where cat='Server';
update categorias set cat='L2 device' where cat='switch' or cat='Switch' or cat='conmutador' or cat='Conmutador';
update categorias set cat='L3 device' where cat='router' or cat='Router';
update categorias set cat='FW' where cat='Firewall' or cat='firewall';
update categorias set cat='printer' where cat='Drucker' or cat='impres' or cat='Printer';
update categorias set cat='workst' where cat='workst' or cat='Workst';
update categorias set cat='other' where cat='Other' or cat='Andere' or cat='otros';

create table categorias_tmp select * from categorias;
insert into categorias_tmp (id) SELECT id + 1 FROM categorias ORDER BY (id+0) DESC LIMIT 1;
insert into categorias (id) SELECT id FROM categorias_tmp ORDER BY (id+0) DESC LIMIT 1;
update ignore categorias set cat = 'VoIP' where id = (SELECT id FROM categorias_tmp ORDER BY (id+0) DESC LIMIT 1);
insert into categorias_tmp (id) SELECT id + 1 FROM categorias ORDER BY (id+0) DESC LIMIT 1;
insert into categorias (id) SELECT id FROM categorias_tmp ORDER BY (id+0) DESC LIMIT 1;
update ignore categorias set cat = 'wifi' where id = (SELECT id FROM categorias_tmp ORDER BY (id+0) DESC LIMIT 1);
insert into categorias_tmp (id) SELECT id + 1 FROM categorias ORDER BY (id+0) DESC LIMIT 1;
insert into categorias (id) SELECT id FROM categorias_tmp ORDER BY (id+0) DESC LIMIT 1;
update ignore categorias set cat = 'DB' where id = (SELECT id FROM categorias_tmp ORDER BY (id+0) DESC LIMIT 1);

insert into categorias_tmp (id) SELECT id + 1 FROM categorias ORDER BY (id+0) DESC LIMIT 1;
insert into categorias (id) SELECT id FROM categorias_tmp ORDER BY (id+0) DESC LIMIT 1;
update ignore categorias_tmp set cat = 'server' where id = (SELECT id FROM categorias ORDER BY (id+0) DESC LIMIT 1);
update ignore categorias set cat = 'server' where id = (SELECT id FROM categorias_tmp ORDER BY (id+0) DESC LIMIT 1);
delete from categorias where cat is NULL;
delete from categorias_tmp where cat is NULL;
insert into categorias_tmp (id) SELECT id + 1 FROM categorias ORDER BY (id+0) DESC LIMIT 1;
insert into categorias (id) SELECT id FROM categorias_tmp ORDER BY (id+0) DESC LIMIT 1;
update ignore categorias_tmp set cat = 'L2 device' where id = (SELECT id FROM categorias ORDER BY (id+0) DESC LIMIT 1);
update ignore categorias set cat = 'L2 device' where id = (SELECT id FROM categorias_tmp ORDER BY (id+0) DESC LIMIT 1);
delete from categorias where cat is NULL;
delete from categorias_tmp where cat is NULL;
insert into categorias_tmp (id) SELECT id + 1 FROM categorias ORDER BY (id+0) DESC LIMIT 1;
insert into categorias (id) SELECT id FROM categorias_tmp ORDER BY (id+0) DESC LIMIT 1;
update ignore categorias_tmp set cat = 'L3 device' where id = (SELECT id FROM categorias ORDER BY (id+0) DESC LIMIT 1);
update ignore categorias set cat = 'L3 device' where id = (SELECT id FROM categorias_tmp ORDER BY (id+0) DESC LIMIT 1);
delete from categorias where cat is NULL;
delete from categorias_tmp where cat is NULL;
insert into categorias_tmp (id) SELECT id + 1 FROM categorias ORDER BY (id+0) DESC LIMIT 1;
insert into categorias (id) SELECT id FROM categorias_tmp ORDER BY (id+0) DESC LIMIT 1;
update ignore categorias_tmp set cat = 'FW' where id = (SELECT id FROM categorias ORDER BY (id+0) DESC LIMIT 1);
update ignore categorias set cat = 'FW' where id = (SELECT id FROM categorias_tmp ORDER BY (id+0) DESC LIMIT 1);
delete from categorias where cat is NULL;
delete from categorias_tmp where cat is NULL;
insert into categorias_tmp (id) SELECT id + 1 FROM categorias ORDER BY (id+0) DESC LIMIT 1;
insert into categorias (id) SELECT id FROM categorias_tmp ORDER BY (id+0) DESC LIMIT 1;
update ignore categorias_tmp set cat = 'workst' where id = (SELECT id FROM categorias ORDER BY (id+0) DESC LIMIT 1);
update ignore categorias set cat = 'workst' where id = (SELECT id FROM categorias_tmp ORDER BY (id+0) DESC LIMIT 1);
delete from categorias where cat is NULL;
delete from categorias_tmp where cat is NULL;
insert into categorias_tmp (id) SELECT id + 1 FROM categorias ORDER BY (id+0) DESC LIMIT 1;
insert into categorias (id) SELECT id FROM categorias_tmp ORDER BY (id+0) DESC LIMIT 1;
update ignore categorias_tmp set cat = 'printer' where id = (SELECT id FROM categorias ORDER BY (id+0) DESC LIMIT 1);
update ignore categorias set cat = 'printer' where id = (SELECT id FROM categorias_tmp ORDER BY (id+0) DESC LIMIT 1);
delete from categorias where cat is NULL;
delete from categorias_tmp where cat is NULL;
insert into categorias_tmp (id) SELECT id + 1 FROM categorias ORDER BY (id+0) DESC LIMIT 1;
insert into categorias (id) SELECT id FROM categorias_tmp ORDER BY (id+0) DESC LIMIT 1;
update ignore categorias_tmp set cat = 'other' where id = (SELECT id FROM categorias ORDER BY (id+0) DESC LIMIT 1);
update ignore categorias set cat = 'other' where id = (SELECT id FROM categorias_tmp ORDER BY (id+0) DESC LIMIT 1);
delete from categorias where cat is NULL;
delete from categorias_tmp where cat is NULL;
insert into categorias_tmp (id) SELECT id + 1 FROM categorias ORDER BY (id+0) DESC LIMIT 1;
insert into categorias (id) SELECT id FROM categorias_tmp ORDER BY (id+0) DESC LIMIT 1;
update ignore categorias_tmp set cat = 'VoIP' where id = (SELECT id FROM categorias ORDER BY (id+0) DESC LIMIT 1);
update ignore categorias set cat = 'VoIP' where id = (SELECT id FROM categorias_tmp ORDER BY (id+0) DESC LIMIT 1);
delete from categorias where cat is NULL;
delete from categorias_tmp where cat is NULL;
insert into categorias_tmp (id) SELECT id + 1 FROM categorias ORDER BY (id+0) DESC LIMIT 1;
insert into categorias (id) SELECT id FROM categorias_tmp ORDER BY (id+0) DESC LIMIT 1;
update ignore categorias_tmp set cat = 'wifi' where id = (SELECT id FROM categorias ORDER BY (id+0) DESC LIMIT 1);
update ignore categorias set cat = 'wifi' where id = (SELECT id FROM categorias_tmp ORDER BY (id+0) DESC LIMIT 1);
delete from categorias where cat is NULL;
delete from categorias_tmp where cat is NULL;
insert into categorias_tmp (id) SELECT id + 1 FROM categorias ORDER BY (id+0) DESC LIMIT 1;
insert into categorias (id) SELECT id FROM categorias_tmp ORDER BY (id+0) DESC LIMIT 1;
update ignore categorias_tmp set cat = 'DB' where id = (SELECT id FROM categorias ORDER BY (id+0) DESC LIMIT 1);
update ignore categorias set cat = 'DB' where id = (SELECT id FROM categorias_tmp ORDER BY (id+0) DESC LIMIT 1);
delete from categorias where cat is NULL;
delete from categorias_tmp where cat is NULL;

drop table categorias_tmp;

