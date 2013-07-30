create table check_permissions ( id smallint (4) );
insert into check_permissions (id) values ('1');
update check_permissions set id='2' where id='1';
alter table check_permissions change id id bigint (4);
drop table check_permissions;
