#this script updates the database of GestioIP 2.2.x to 2.2.5
CREATE TABLE IF NOT EXISTS audit (
  `id` smallint(6) not NULL,
  `event` varchar(500) not NULL,
  `user` varchar(50) default NULL,
  `event_class` smallint(3) default NULL,
  `event_type` smallint(4) default NULL,
  `update_type_audit` smallint(3) default NULL,
  `date` bigint(20) not NULL,
  PRIMARY KEY  (`id`)
);

CREATE TABLE IF NOT EXISTS event_classes (
  `id` smallint(5) NOT NULL,
  `event_class` varchar(25) default NULL,
  PRIMARY KEY  (`id`)
);

CREATE TABLE IF NOT EXISTS event_types (
  `id` smallint(5) NOT NULL,
  `event_type` varchar(25) default NULL,
  PRIMARY KEY  (`id`)
);

CREATE TABLE IF NOT EXISTS update_types_audit (
  `id` smallint(5) NOT NULL,
  `update_types_audit` varchar(25) default NULL,
  PRIMARY KEY  (`id`)
);

INSERT IGNORE event_types VALUES (1,'host edited'),(2,'net edited'),(3,'range changed'),(4,'man synch'),(5,'red split'),(6,'red joined'),(7,'red cleared'),(8,'cat host added'),(9,'cat net added'),(10,'loc added'),(11,'cat host deleted'),(12,'cat net deleted'),(13,'loc deleted'),(14,'host deleted'),(15,'host added'),(16,'net deleted'),(17,'net added'),(18,'range deleted'),(19,'range added');

INSERT IGNORE event_classes VALUES (1,'host'),(2,'net'),(3,'security'),(4,'dns'),(5,'admin');

INSERT IGNORE update_types_audit VALUES (1,'man'),(2,'sh'),(3,'SNMP'),(4,'auto');

