# this script updates the database of GestioIP 2.2.6 to 2.2.7

# update table config

ALTER TABLE config ADD dyn_ranges_only varchar(1) default 'n';
ALTER TABLE config ADD ping_timeout tinyint(2) default '2';


# update table locations

ALTER TABLE locations CHANGE loc loc varchar(60);


# update table categorias

ALTER TABLE categorias CHANGE cat cat varchar(60);


# update table categorias_net

ALTER TABLE categorias_net CHANGE cat cat varchar(60);


#add new event types

INSERT IGNORE event_types VALUES (28,'host reserved'),(29,'net list exported'),(30,'host list exported');


# update table update_types_audit

UPDATE IGNORE update_types_audit SET update_types_audit = 'man net sheet' WHERE update_types_audit = 'man sheet';
INSERT IGNORE update_types_audit VALUES (10,'man host sheet');
INSERT IGNORE update_types_audit VALUES (11,'red cleared');

